import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:googleapis_auth/auth_io.dart' as gauth;

/// Envío y recepción de notificaciones push usando FCM HTTP v1.
///
/// En vez de guardar tokens por usuario, cada dispositivo se suscribe a
/// "topics": `todos` (todo el personal) y `u_<uid>` (canal personal). Así el
/// envío selectivo no necesita leer Firestore y funciona aunque el usuario
/// cambie de teléfono.
///
/// El envío requiere la credencial `assets/credenciales/fcm_service_account.json`
/// (ver LEEME.md en esa carpeta). Si no existe, el envío se omite en silencio
/// y el resto de la app funciona con normalidad.
class ServicioNotificaciones {
  static final ServicioNotificaciones _instancia = ServicioNotificaciones._interna();
  factory ServicioNotificaciones() => _instancia;
  ServicioNotificaciones._interna();

  static const String _proyectoId = 'bomberos-alerta-app';
  static const String _rutaCredencial = 'assets/credenciales/fcm_service_account.json';
  static const List<String> _alcances = ['https://www.googleapis.com/auth/firebase.messaging'];

  gauth.AutoRefreshingAuthClient? _clienteHttp;

  // ---------------------------------------------------------------------
  // LADO RECEPTOR: se llama al iniciar sesión / cerrar sesión
  // ---------------------------------------------------------------------

  /// Pide permiso de notificaciones y suscribe el dispositivo a sus topics.
  Future<void> registrarDispositivo(String uid) async {
    try {
      final fcm = FirebaseMessaging.instance;
      await fcm.requestPermission();
      await fcm.subscribeToTopic('todos');
      await fcm.subscribeToTopic('u_$uid');
    } catch (e) {
      debugPrint('No se pudo registrar el dispositivo para push: $e');
    }
  }

  /// Desuscribe el dispositivo (al cerrar sesión) para no recibir alertas ajenas.
  Future<void> liberarDispositivo(String uid) async {
    try {
      final fcm = FirebaseMessaging.instance;
      await fcm.unsubscribeFromTopic('todos');
      await fcm.unsubscribeFromTopic('u_$uid');
    } catch (e) {
      debugPrint('No se pudo desuscribir el dispositivo: $e');
    }
  }

  // ---------------------------------------------------------------------
  // LADO EMISOR: usado por el admin al crear alertas/eventos
  // ---------------------------------------------------------------------

  /// Envía la notificación a todos (`uidsDestinatarios` vacío) o solo al
  /// canal personal de cada UID indicado.
  ///
  /// Con [soloDeGuardia] activado, un envío "a todos" se limita al personal
  /// marcado de guardia esta semana (campo `de_guardia` en `usuarios`);
  /// se usa para las alertas de emergencia, no para los eventos.
  Future<void> enviarNotificacionSelectiva({
    required List<String> uidsDestinatarios,
    required String titulo,
    required String cuerpo,
    String? urlImagen,
    bool soloDeGuardia = false,
  }) async {
    List<String> topics;
    if (uidsDestinatarios.isNotEmpty) {
      topics = uidsDestinatarios.map((uid) => 'u_$uid').toList();
    } else {
      final uidsGuardia = soloDeGuardia ? await _uidsDeGuardia() : null;
      topics = uidsGuardia == null
          ? ['todos']
          : uidsGuardia.map((uid) => 'u_$uid').toList();
    }

    for (final topic in topics) {
      await _enviarATopic(topic: topic, titulo: titulo, cuerpo: cuerpo, urlImagen: urlImagen);
    }
  }

  /// UIDs del personal de guardia, o `null` si todos están de guardia
  /// (o no se pudo consultar): en ese caso basta el topic `todos`.
  Future<List<String>?> _uidsDeGuardia() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('usuarios').get();
      if (snapshot.docs.isEmpty) return null;

      // Sin el campo marcado se asume de guardia (compatibilidad con
      // usuarios creados antes de esta función).
      final deGuardia = snapshot.docs
          .where((d) => d.data()['de_guardia'] != false)
          .map((d) => d.id)
          .toList();

      if (deGuardia.length == snapshot.docs.length) return null;
      return deGuardia;
    } catch (e) {
      debugPrint('No se pudo leer el personal de guardia, se notifica a todos: $e');
      return null;
    }
  }

  Future<void> _enviarATopic({
    required String topic,
    required String titulo,
    required String cuerpo,
    String? urlImagen,
  }) async {
    final cliente = await _obtenerClienteHttp();
    if (cliente == null) return; // Sin credencial: push desactivado.

    final mensaje = {
      'message': {
        'topic': topic,
        'notification': {
          'title': titulo,
          'body': cuerpo,
          if (urlImagen != null && urlImagen.isNotEmpty) 'image': urlImagen,
        },
        'android': {
          'priority': 'HIGH',
          'notification': {'sound': 'default'},
        },
        'data': {'tipo': 'emergencia'},
      },
    };

    try {
      final respuesta = await cliente.post(
        Uri.parse('https://fcm.googleapis.com/v1/projects/$_proyectoId/messages:send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(mensaje),
      );

      if (respuesta.statusCode != 200) {
        debugPrint('FCM rechazó el envío a "$topic" (${respuesta.statusCode}): ${respuesta.body}');
      }
    } catch (e) {
      debugPrint('Error de red al enviar push a "$topic": $e');
    }
  }

  /// Crea (una sola vez) el cliente autenticado con la cuenta de servicio.
  /// El token OAuth se renueva solo mientras la app viva.
  Future<gauth.AutoRefreshingAuthClient?> _obtenerClienteHttp() async {
    if (_clienteHttp != null) return _clienteHttp;
    try {
      final contenido = await rootBundle.loadString(_rutaCredencial);
      final credencial = gauth.ServiceAccountCredentials.fromJson(jsonDecode(contenido));
      _clienteHttp = await gauth.clientViaServiceAccount(credencial, _alcances);
      return _clienteHttp;
    } catch (e) {
      debugPrint('Push desactivado: falta $_rutaCredencial (ver assets/credenciales/LEEME.md)');
      return null;
    }
  }
}
