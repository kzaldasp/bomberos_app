import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Rastrea el trayecto del bombero hacia la emergencia.
///
/// Diseñado para el plan gratuito de Firebase (Spark):
/// - El GPS emite puntos localmente (cada ~20 m de movimiento), pero a
///   Firestore se escribe COMO MÁXIMO una vez cada 30 segundos, agrupando
///   todos los puntos acumulados en un solo `arrayUnion` (1 escritura).
/// - Todo el recorrido de un bombero vive en UN solo documento:
///   `emergencias/{id}/trayectos/{uid}` → máx. ~120 escrituras/hora por
///   bombero activo, muy por debajo de las 20.000 escrituras diarias gratis.
/// - En Android se levanta un servicio en primer plano (notificación fija),
///   así el rastreo sigue aunque el bombero minimice la app para ir a
///   Google Maps.
/// - Se apaga solo cuando el admin finaliza la emergencia.
///
/// Limpieza de datos viejos (para no acumular basura en Firestore):
/// - Al llegar al destino (< [_radioLlegadaMetros] del punto de la emergencia)
///   el GPS se apaga solo y el documento se compacta: se borra el array de
///   puntos y queda solo `estado: 'llegado'` + la última posición.
/// - Si el bombero deja de compartir manualmente, su trayecto se borra.
/// - Al finalizar el operativo, el admin borra todos los trayectos
///   (ver `_finalizarEmergencia` en pantalla_detalle_alerta.dart).
class ServicioRastreo {
  static final ServicioRastreo _instancia = ServicioRastreo._interna();
  factory ServicioRastreo() => _instancia;
  ServicioRastreo._interna();

  static const Duration _intervaloEscritura = Duration(seconds: 30);
  static const int _distanciaMinimaMetros = 20;
  static const int _radioLlegadaMetros = 60;

  // Claves de shared_preferences: si Android mata la app a mitad del
  // trayecto, al reabrirla se reanuda el rastreo automáticamente.
  static const String _prefEmergencia = 'rastreo_emergencia';
  static const String _prefUid = 'rastreo_uid';
  static const String _prefNombre = 'rastreo_nombre';
  static const String _prefDestinoLat = 'rastreo_destino_lat';
  static const String _prefDestinoLng = 'rastreo_destino_lng';

  StreamSubscription<Position>? _subGps;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subEmergencia;
  Timer? _temporizador;

  final List<Map<String, dynamic>> _puntosPendientes = [];
  DocumentReference<Map<String, dynamic>>? _docTrayecto;
  String? _emergenciaActiva;
  String _nombreBombero = 'Bombero';
  GeoPoint? _destino;
  bool _marcandoLlegada = false;

  bool get activo => _emergenciaActiva != null;
  String? get emergenciaActiva => _emergenciaActiva;

  /// Empieza a compartir el trayecto hacia [emergenciaId].
  ///
  /// Si se pasa [destino] (la ubicación de la emergencia), el rastreo se
  /// apaga solo al llegar y compacta el documento del trayecto.
  Future<void> iniciar({
    required String emergenciaId,
    required String bomberoUid,
    required String nombreBombero,
    Position? posicionInicial,
    GeoPoint? destino,
  }) async {
    if (_emergenciaActiva == emergenciaId) return; // Ya estamos rastreando esta.
    await detener();

    _emergenciaActiva = emergenciaId;
    _nombreBombero = nombreBombero;
    _destino = destino;
    _marcandoLlegada = false;
    await _guardarSesion(emergenciaId, bomberoUid, nombreBombero, destino);
    _docTrayecto = FirebaseFirestore.instance
        .collection('emergencias')
        .doc(emergenciaId)
        .collection('trayectos')
        .doc(bomberoUid);

    if (posicionInicial != null) {
      _acumularPunto(posicionInicial);
      await _volcarPendientes(); // Punto de partida visible de inmediato.
    }

    _subGps = Geolocator.getPositionStream(locationSettings: _ajustesGps())
        .listen(_acumularPunto, onError: (e) => debugPrint('Error de GPS: $e'));

    _temporizador = Timer.periodic(_intervaloEscritura, (_) => _volcarPendientes());

    // Apagado automático cuando la central cierra el operativo.
    // Descartamos los puntos pendientes: el admin borra los trayectos al
    // finalizar, así que volcarlos solo recrearía el documento recién borrado.
    _subEmergencia = FirebaseFirestore.instance
        .collection('emergencias')
        .doc(emergenciaId)
        .snapshots()
        .listen((snap) {
      if (!snap.exists || snap.data()?['estado'] == 'finalizada') {
        detener(descartarPendientes: true);
      }
    });
  }

  /// Detiene el rastreo.
  ///
  /// Por defecto sube los últimos puntos que quedaron en memoria.
  /// - [descartarPendientes]: los desecha en vez de subirlos (operativo cerrado).
  /// - [borrarTrayecto]: además borra el documento del trayecto en Firestore
  ///   (el bombero canceló, su ruta ya no representa nada útil).
  Future<void> detener({
    bool descartarPendientes = false,
    bool borrarTrayecto = false,
  }) async {
    _temporizador?.cancel();
    _temporizador = null;
    await _subGps?.cancel();
    _subGps = null;
    await _subEmergencia?.cancel();
    _subEmergencia = null;

    final doc = _docTrayecto;
    if (descartarPendientes || borrarTrayecto) {
      _puntosPendientes.clear();
    } else {
      await _volcarPendientes();
    }
    if (borrarTrayecto && doc != null) {
      try {
        await doc.delete();
      } catch (e) {
        debugPrint('No se pudo borrar el trayecto: $e');
      }
    }

    _emergenciaActiva = null;
    _docTrayecto = null;
    _destino = null;
    await _borrarSesion();
  }

  /// Reanuda el rastreo si la app se cerró (o Android la mató) a mitad de un
  /// trayecto. Llamar al arrancar la app. Cuesta 1 lectura solo cuando hay
  /// una sesión de rastreo pendiente.
  Future<void> reanudarSiQuedoPendiente() async {
    if (activo) return;

    final prefs = await SharedPreferences.getInstance();
    final emergenciaId = prefs.getString(_prefEmergencia);
    final uid = prefs.getString(_prefUid);
    if (emergenciaId == null || uid == null) return;

    // La sesión guardada es de otro usuario: se descarta.
    if (FirebaseAuth.instance.currentUser?.uid != uid) {
      await _borrarSesion();
      return;
    }

    try {
      // ¿El operativo sigue abierto?
      final doc = await FirebaseFirestore.instance
          .collection('emergencias')
          .doc(emergenciaId)
          .get();
      if (!doc.exists || doc.data()?['estado'] == 'finalizada') {
        await _borrarSesion();
        return;
      }

      final permiso = await Geolocator.checkPermission();
      if (permiso != LocationPermission.always &&
          permiso != LocationPermission.whileInUse) {
        return; // Sin permiso no se puede reanudar; se reintentará al reabrir.
      }

      final lat = prefs.getDouble(_prefDestinoLat);
      final lng = prefs.getDouble(_prefDestinoLng);
      await iniciar(
        emergenciaId: emergenciaId,
        bomberoUid: uid,
        nombreBombero: prefs.getString(_prefNombre) ?? 'Bombero',
        destino: (lat != null && lng != null) ? GeoPoint(lat, lng) : null,
      );
      debugPrint('Rastreo GPS reanudado tras reinicio de la app');
    } catch (e) {
      debugPrint('No se pudo reanudar el rastreo: $e');
    }
  }

  Future<void> _guardarSesion(
    String emergenciaId,
    String uid,
    String nombre,
    GeoPoint? destino,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefEmergencia, emergenciaId);
      await prefs.setString(_prefUid, uid);
      await prefs.setString(_prefNombre, nombre);
      if (destino != null) {
        await prefs.setDouble(_prefDestinoLat, destino.latitude);
        await prefs.setDouble(_prefDestinoLng, destino.longitude);
      }
    } catch (e) {
      debugPrint('No se pudo persistir la sesión de rastreo: $e');
    }
  }

  Future<void> _borrarSesion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefEmergencia);
      await prefs.remove(_prefUid);
      await prefs.remove(_prefNombre);
      await prefs.remove(_prefDestinoLat);
      await prefs.remove(_prefDestinoLng);
    } catch (e) {
      debugPrint('No se pudo limpiar la sesión de rastreo: $e');
    }
  }

  void _acumularPunto(Position posicion) {
    _puntosPendientes.add({
      'lat': posicion.latitude,
      'lng': posicion.longitude,
      't': Timestamp.now(),
    });

    // ¿Ya llegó a la emergencia? Apagamos el GPS y limpiamos el trayecto.
    final destino = _destino;
    if (destino != null && !_marcandoLlegada) {
      final metros = Geolocator.distanceBetween(
        posicion.latitude,
        posicion.longitude,
        destino.latitude,
        destino.longitude,
      );
      if (metros <= _radioLlegadaMetros) {
        _marcarLlegada(posicion);
      }
    }
  }

  /// Llegó al destino: apaga el rastreo y compacta el documento — borra el
  /// array de puntos (la ruta ya cumplió su función) y deja solo la marca
  /// de llegada con la última posición.
  Future<void> _marcarLlegada(Position posicion) async {
    _marcandoLlegada = true;
    final doc = _docTrayecto;
    final nombre = _nombreBombero;
    await detener(descartarPendientes: true);
    if (doc == null) return;

    try {
      await doc.set({
        'nombre': nombre,
        'estado': 'llegado',
        'llegada': FieldValue.serverTimestamp(),
        'actualizado': FieldValue.serverTimestamp(),
        'ultimo': {'lat': posicion.latitude, 'lng': posicion.longitude},
        'puntos': FieldValue.delete(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('No se pudo registrar la llegada: $e');
    }
  }

  /// Una sola escritura con todos los puntos acumulados desde el último volcado.
  Future<void> _volcarPendientes() async {
    final doc = _docTrayecto;
    if (doc == null || _puntosPendientes.isEmpty) return;

    final lote = List<Map<String, dynamic>>.from(_puntosPendientes);
    _puntosPendientes.clear();

    try {
      await doc.set({
        'nombre': _nombreBombero,
        'actualizado': FieldValue.serverTimestamp(),
        'puntos': FieldValue.arrayUnion(lote),
      }, SetOptions(merge: true));
    } catch (e) {
      // Sin conexión: devolvemos los puntos a la cola para el próximo intento.
      _puntosPendientes.insertAll(0, lote);
      debugPrint('No se pudo subir el trayecto (se reintentará): $e');
    }
  }

  LocationSettings _ajustesGps() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: _distanciaMinimaMetros,
        // Servicio en primer plano: el rastreo sigue con la app minimizada.
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Trayecto en curso',
          notificationText: 'Compartiendo tu ubicación con la central de bomberos',
          notificationIcon: AndroidResource(name: 'ic_launcher', defType: 'mipmap'),
          enableWakeLock: true,
        ),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: _distanciaMinimaMetros,
        showBackgroundLocationIndicator: true,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: _distanciaMinimaMetros,
    );
  }
}
