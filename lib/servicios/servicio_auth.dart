import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'servicio_notificaciones.dart';

/// Roles válidos en toda la app. Usar SIEMPRE estas constantes para evitar
/// inconsistencias ('operativo' vs 'bombero') que dejaban usuarios sin acceso.
class Roles {
  static const String admin = 'admin';
  static const String bombero = 'bombero';
}

class ServicioAuth {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Crea un nuevo usuario en Auth y guarda su perfil en Firestore
  /// SIN cerrar la sesión del administrador actual (usa una instancia
  /// secundaria de Firebase). Retorna null si todo salió bien.
  Future<String?> registrarNuevoPersonal({
    required String email,
    required String password,
    required String nombre,
    required String rol,
    required String rango,
  }) async {
    FirebaseApp? appSecundaria;
    try {
      appSecundaria = await Firebase.initializeApp(
        name: 'RegistroAdmin',
        options: Firebase.app().options,
      );

      final credencial = await FirebaseAuth.instanceFor(app: appSecundaria)
          .createUserWithEmailAndPassword(email: email, password: password);

      await _db.collection('usuarios').doc(credencial.user!.uid).set({
        'nombre': nombre,
        'email': email,
        'rol': rol,
        'rango': rango,
        'fecha_creacion': FieldValue.serverTimestamp(),
      });

      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') return 'La contraseña es muy débil (mínimo 6 caracteres).';
      if (e.code == 'email-already-in-use') return 'El correo ya está registrado.';
      if (e.code == 'invalid-email') return 'El formato del correo no es válido.';
      return 'Error de autenticación: ${e.message}';
    } catch (e) {
      return 'Error general: $e';
    } finally {
      // Siempre destruimos la instancia temporal; si quedara viva, el
      // siguiente registro fallaría con "app already exists".
      await appSecundaria?.delete();
    }
  }

  /// Inicia sesión. Retorna el rol ('admin' o 'bombero') si fue exitoso,
  /// o un mensaje de error que empieza con 'Error' para mostrar al usuario.
  Future<String?> iniciarSesion(String correo, String clave) async {
    try {
      final credencial = await _auth.signInWithEmailAndPassword(
        email: correo,
        password: clave,
      );

      final uid = credencial.user?.uid;
      if (uid == null) return 'Error: no se pudo iniciar sesión.';

      final rol = await obtenerRol(uid);
      if (rol == null) {
        await _auth.signOut();
        return 'Error: tu cuenta no tiene un perfil asignado. Contacta al administrador.';
      }

      // Suscribimos este dispositivo a las notificaciones push del usuario.
      await ServicioNotificaciones().registrarDispositivo(uid);
      return rol;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') return 'Error: el correo no está registrado.';
      if (e.code == 'wrong-password') return 'Error: la contraseña es incorrecta.';
      if (e.code == 'invalid-credential') return 'Error: correo o contraseña incorrectos.';
      if (e.code == 'invalid-email') return 'Error: el formato del correo no es válido.';
      if (e.code == 'too-many-requests') return 'Error: demasiados intentos. Espera unos minutos.';
      return 'Error de acceso: ${e.message}';
    } catch (e) {
      return 'Error inesperado: $e';
    }
  }

  /// Lee el rol del usuario desde Firestore ('admin' | 'bombero' | null).
  Future<String?> obtenerRol(String uid) async {
    final doc = await _db.collection('usuarios').doc(uid).get();
    if (!doc.exists) return null;
    final rol = doc.data()?['rol'] as String?;
    // Datos antiguos guardaban 'operativo'; lo tratamos como bombero.
    if (rol == 'operativo') return Roles.bombero;
    return rol;
  }

  /// Cierra la sesión y desuscribe el dispositivo de las notificaciones.
  Future<void> cerrarSesion() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await ServicioNotificaciones().liberarDispositivo(uid);
    }
    await _auth.signOut();
  }

  User? get usuarioActual => _auth.currentUser;
}
