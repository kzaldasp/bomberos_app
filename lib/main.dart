import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'config/tema_app.dart';
import 'firebase_options.dart';
import 'pantallas/pantalla_cambiar_clave.dart';
import 'pantallas/pantalla_dashboard.dart';
import 'pantallas/pantalla_login.dart';
import 'servicios/servicio_auth.dart';
import 'servicios/servicio_notificaciones.dart';
import 'servicios/servicio_rastreo.dart';

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
      title: 'Bomberos Cotacachi',
      theme: TemaApp.obtenerTema(),
      home: const PuertaEntrada(),
    );
  }
}

/// Decide la pantalla inicial: si hay una sesión guardada va directo al
/// dashboard (con su rol), si no, al login.
class PuertaEntrada extends StatelessWidget {
  const PuertaEntrada({super.key});

  Future<({String? rol, bool debeCambiarClave})?> _sesionActiva() async {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) return null;
    try {
      final perfil = await ServicioAuth().obtenerPerfil(usuario.uid);
      if (perfil.rol != null) {
        // Reafirmamos la suscripción push (idempotente): cubre el caso de
        // que el token FCM haya cambiado mientras la app estuvo cerrada.
        await ServicioNotificaciones().registrarDispositivo(usuario.uid);

        // Si Android mató la app a mitad de un trayecto, retomamos el
        // rastreo GPS sin que el bombero tenga que acordarse de reactivarlo.
        // Sin await: no debe retrasar la entrada al dashboard.
        ServicioRastreo().reanudarSiQuedoPendiente();
      }
      return perfil;
    } catch (_) {
      return null; // Sin conexión o sin perfil: que entre por el login.
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({String? rol, bool debeCambiarClave})?>(
      future: _sesionActiva(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final perfil = snapshot.data;
        final rol = perfil?.rol;
        if (rol == Roles.admin || rol == Roles.bombero) {
          // Contraseña temporal pendiente: el cambio no se puede evadir
          // cerrando y reabriendo la app.
          if (perfil!.debeCambiarClave) {
            return PantallaCambiarClave(rolUsuario: rol!);
          }
          return PantallaDashboard(rolUsuario: rol!);
        }
        return const PantallaLogin();
      },
    );
  }
}
