import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'config/tema_app.dart';
import 'firebase_options.dart';
import 'pantallas/pantalla_dashboard.dart';
import 'pantallas/pantalla_login.dart';
import 'servicios/servicio_auth.dart';
import 'servicios/servicio_notificaciones.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MiApp());
}

class MiApp extends StatelessWidget {
  const MiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bomberos Otavalo',
      theme: TemaApp.obtenerTema(),
      home: const PuertaEntrada(),
    );
  }
}

/// Decide la pantalla inicial: si hay una sesión guardada va directo al
/// dashboard (con su rol), si no, al login.
class PuertaEntrada extends StatelessWidget {
  const PuertaEntrada({super.key});

  Future<String?> _rolSesionActiva() async {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) return null;
    try {
      final rol = await ServicioAuth().obtenerRol(usuario.uid);
      if (rol != null) {
        // Reafirmamos la suscripción push (idempotente): cubre el caso de
        // que el token FCM haya cambiado mientras la app estuvo cerrada.
        await ServicioNotificaciones().registrarDispositivo(usuario.uid);
      }
      return rol;
    } catch (_) {
      return null; // Sin conexión o sin perfil: que entre por el login.
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _rolSesionActiva(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final rol = snapshot.data;
        if (rol == Roles.admin || rol == Roles.bombero) {
          return PantallaDashboard(rolUsuario: rol!);
        }
        return const PantallaLogin();
      },
    );
  }
}
