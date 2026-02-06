import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ServicioAuth {
  // Instancias oficiales de Firebase
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Inicia sesión y retorna el ROL del usuario (admin o bombero)
  Future<String?> iniciarSesion(String correo, String clave) async {
    try {
      // 1. Intentar la autenticación en Firebase Auth
      UserCredential credencial = await _auth.signInWithEmailAndPassword(
        email: correo,
        password: clave,
      );

      // 2. Si entra, buscamos el ROL en la colección 'usuarios' de Firestore
      User? usuario = credencial.user;
      if (usuario != null) {
        DocumentSnapshot docUsuario = await _db.collection('usuarios').doc(usuario.uid).get();
        
        if (docUsuario.exists) {
          // Retornamos el campo 'rol' (ej: 'admin' o 'bombero')
          final datos = docUsuario.data() as Map<String, dynamic>;
          return datos['rol'] as String?;
        }
      }
      return null;
    } on FirebaseAuthException catch (e) {
      // Manejo de errores comunes en español
      if (e.code == 'user-not-found') return 'Error: El correo no está registrado.';
      if (e.code == 'wrong-password') return 'Error: La contraseña es incorrecta.';
      return 'Error de acceso: ${e.message}';
    } catch (e) {
      return 'Error inesperado: $e';
    }
  }

  /// Cerrar la sesión actual
  Future<void> cerrarSesion() async {
    await _auth.signOut();
  }

  /// Obtener el usuario que está logueado actualmente
  User? get usuarioActual => _auth.currentUser;
}