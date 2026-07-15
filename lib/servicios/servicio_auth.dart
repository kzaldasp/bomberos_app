import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

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
        // La contraseña que puso el admin es temporal: en el primer
        // ingreso el sistema exige cambiarla (ver cambiarClave).
        'debe_cambiar_clave': true,
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

  /// Inicia sesión. Si fue exitoso retorna el rol y si la cuenta aún usa
  /// la contraseña temporal ([debeCambiarClave]); si falló, [error] trae
  /// el mensaje para mostrar al usuario.
  Future<({String? rol, bool debeCambiarClave, String? error})> iniciarSesion(
      String correo, String clave) async {
    try {
      final credencial = await _auth.signInWithEmailAndPassword(
        email: correo,
        password: clave,
      );

      final uid = credencial.user?.uid;
      if (uid == null) return _errorSesion('Error: no se pudo iniciar sesión.');

      final perfil = await obtenerPerfil(uid);
      if (perfil.rol == null) {
        await _auth.signOut();
        return _errorSesion(
            'Error: tu cuenta no tiene un perfil asignado. Contacta al administrador.');
      }

      // Suscribimos este dispositivo a las notificaciones push del usuario.
      await ServicioNotificaciones().registrarDispositivo(uid);
      return (rol: perfil.rol, debeCambiarClave: perfil.debeCambiarClave, error: null);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') return _errorSesion('Error: el correo no está registrado.');
      if (e.code == 'wrong-password') return _errorSesion('Error: la contraseña es incorrecta.');
      if (e.code == 'invalid-credential') return _errorSesion('Error: correo o contraseña incorrectos.');
      if (e.code == 'invalid-email') return _errorSesion('Error: el formato del correo no es válido.');
      if (e.code == 'too-many-requests') return _errorSesion('Error: demasiados intentos. Espera unos minutos.');
      return _errorSesion('Error de acceso: ${e.message}');
    } catch (e) {
      return _errorSesion('Error inesperado: $e');
    }
  }

  ({String? rol, bool debeCambiarClave, String? error}) _errorSesion(String mensaje) {
    return (rol: null, debeCambiarClave: false, error: mensaje);
  }

  /// Rol y marca de contraseña temporal, en UNA sola lectura del perfil.
  Future<({String? rol, bool debeCambiarClave})> obtenerPerfil(String uid) async {
    final doc = await _db.collection('usuarios').doc(uid).get();
    if (!doc.exists) return (rol: null, debeCambiarClave: false);
    final data = doc.data();
    String? rol = data?['rol'] as String?;
    // Datos antiguos guardaban 'operativo'; lo tratamos como bombero.
    if (rol == 'operativo') rol = Roles.bombero;
    // Usuarios creados antes de esta función no tienen el campo: no se
    // les fuerza ningún cambio.
    return (rol: rol, debeCambiarClave: data?['debe_cambiar_clave'] == true);
  }

  /// Lee el rol del usuario desde Firestore ('admin' | 'bombero' | null).
  Future<String?> obtenerRol(String uid) async => (await obtenerPerfil(uid)).rol;

  /// Cambia la contraseña del usuario actual y quita la marca de
  /// contraseña temporal. Reautentica primero con [actual]: sin eso,
  /// Firebase rechaza el cambio con 'requires-recent-login' cuando la
  /// sesión no es reciente (p. ej. la app se reabrió días después).
  /// Retorna null si todo salió bien, o un mensaje de error.
  Future<String?> cambiarClave({
    required String actual,
    required String nueva,
  }) async {
    final usuario = _auth.currentUser;
    final email = usuario?.email;
    if (usuario == null || email == null) {
      return 'Sesión no válida. Vuelve a iniciar sesión.';
    }

    try {
      final credencial = EmailAuthProvider.credential(email: email, password: actual);
      await usuario.reauthenticateWithCredential(credencial);
      await usuario.updatePassword(nueva);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        return 'La contraseña actual es incorrecta.';
      }
      if (e.code == 'weak-password') return 'La nueva contraseña es muy débil (mínimo 6 caracteres).';
      if (e.code == 'too-many-requests') return 'Demasiados intentos. Espera unos minutos.';
      return 'No se pudo cambiar la contraseña: ${e.message}';
    } catch (e) {
      return 'Error inesperado: $e';
    }

    // La clave ya cambió: quitar la marca es secundario. Si esto falla,
    // el próximo ingreso volverá a pedir el cambio (con la contraseña
    // nueva como "actual"), pero no se pierde el acceso.
    try {
      await _db.collection('usuarios').doc(usuario.uid).update({'debe_cambiar_clave': false});
    } catch (e) {
      debugPrint('No se pudo quitar la marca de contraseña temporal: $e');
    }
    return null;
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
