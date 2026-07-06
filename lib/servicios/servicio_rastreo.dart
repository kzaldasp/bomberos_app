import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

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
class ServicioRastreo {
  static final ServicioRastreo _instancia = ServicioRastreo._interna();
  factory ServicioRastreo() => _instancia;
  ServicioRastreo._interna();

  static const Duration _intervaloEscritura = Duration(seconds: 30);
  static const int _distanciaMinimaMetros = 20;

  StreamSubscription<Position>? _subGps;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subEmergencia;
  Timer? _temporizador;

  final List<Map<String, dynamic>> _puntosPendientes = [];
  DocumentReference<Map<String, dynamic>>? _docTrayecto;
  String? _emergenciaActiva;
  String _nombreBombero = 'Bombero';

  bool get activo => _emergenciaActiva != null;
  String? get emergenciaActiva => _emergenciaActiva;

  /// Empieza a compartir el trayecto hacia [emergenciaId].
  Future<void> iniciar({
    required String emergenciaId,
    required String bomberoUid,
    required String nombreBombero,
    Position? posicionInicial,
  }) async {
    if (_emergenciaActiva == emergenciaId) return; // Ya estamos rastreando esta.
    await detener();

    _emergenciaActiva = emergenciaId;
    _nombreBombero = nombreBombero;
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
    _subEmergencia = FirebaseFirestore.instance
        .collection('emergencias')
        .doc(emergenciaId)
        .snapshots()
        .listen((snap) {
      if (!snap.exists || snap.data()?['estado'] == 'finalizada') {
        detener();
      }
    });
  }

  /// Detiene el rastreo y sube los últimos puntos que quedaron en memoria.
  Future<void> detener() async {
    _temporizador?.cancel();
    _temporizador = null;
    await _subGps?.cancel();
    _subGps = null;
    await _subEmergencia?.cancel();
    _subEmergencia = null;

    await _volcarPendientes();
    _emergenciaActiva = null;
    _docTrayecto = null;
  }

  void _acumularPunto(Position posicion) {
    _puntosPendientes.add({
      'lat': posicion.latitude,
      'lng': posicion.longitude,
      't': Timestamp.now(),
    });
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
