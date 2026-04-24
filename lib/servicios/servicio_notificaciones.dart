import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class ServicioNotificaciones {
  // NOTA: Para producción sin servidor, se usa la API v1 de FCM.
  // Necesitarás obtener tu 'Server Key' o un Access Token. 
  final String _urlFCM = "https://fcm.googleapis.com/fcm/send"; 
  final String _serverKey = "TU_SERVER_KEY_DE_FIREBASE"; // Obtenla en la consola de Firebase

  /// Envía notificaciones a una lista específica de UIDs de usuarios
  Future<void> enviarNotificacionSelectiva({
    required List<String> uidsDestinatarios,
    required String titulo,
    required String cuerpo,
    String? urlImagen,
  }) async {
    try {
      List<String> tokens = [];

      if (uidsDestinatarios.isEmpty) {
        // 1. Si no hay seleccionados, buscamos los tokens de TODOS los usuarios
        var snapshot = await FirebaseFirestore.instance.collection('usuarios').get();
        for (var doc in snapshot.docs) {
          if (doc.data().containsKey('fcmToken')) {
            tokens.add(doc['fcmToken']);
          }
        }
      } else {
        // 2. Buscamos solo los tokens de los UIDs seleccionados
        for (String uid in uidsDestinatarios) {
          var doc = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
          if (doc.exists && doc.data()!.containsKey('fcmToken')) {
            tokens.add(doc['fcmToken']);
          }
        }
      }

      if (tokens.isEmpty) return;

      // 3. Construimos el paquete de la notificación
      final payload = {
        "registration_ids": tokens,
        "notification": {
          "title": titulo,
          "body": cuerpo,
          "sound": "default",
          "image": urlImagen // Cloudinary nos sirve aquí también
        },
        "data": {
          "click_action": "FLUTTER_NOTIFICATION_CLICK",
          "tipo": "emergencia"
        }
      };

      // 4. Enviamos la petición a Google
      await http.post(
        Uri.parse(_urlFCM),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$_serverKey',
        },
        body: jsonEncode(payload),
      );

      print("✅ Notificaciones enviadas a ${tokens.length} dispositivos.");
    } catch (e) {
      print("🚨 Error al enviar notificaciones: $e");
    }
  }
}