import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart'; 

class ServicioAuth {
  // Instancias oficiales de Firebase
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;



/// Crea un nuevo usuario en Auth y guarda su perfil en Firestore 
  /// SIN cerrar la sesión del Administrador actual.
  Future<String?> registrarNuevoPersonal({
    required String email,
    required String password,
    required String nombre,
    required String rol,
    required String rango,
  }) async {
    try {
      // 1. Creamos una instancia "secundaria" temporal de Firebase
      FirebaseApp appSecundaria = await Firebase.initializeApp(
        name: 'RegistroAdmin',
        options: Firebase.app().options,
      );

      // 2. Usamos esa instancia secundaria para crear el Auth (No afecta la sesión principal)
      UserCredential credencial = await FirebaseAuth.instanceFor(app: appSecundaria)
          .createUserWithEmailAndPassword(email: email, password: password);

      String nuevoUid = credencial.user!.uid;

      // 3. Guardamos los datos completos del perfil en Firestore (Usando la instancia principal)
      await FirebaseFirestore.instance.collection('usuarios').doc(nuevoUid).set({
        'nombre': nombre,
        'email': email,
        'rol': rol,
        'rango': rango,
        'fecha_creacion': FieldValue.serverTimestamp(),
      });

      // 4. Destruimos la instancia temporal
      await appSecundaria.delete();

      return null; // Nulo significa que no hubo errores (Éxito)
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') return 'La contraseña es muy débil (Mínimo 6 caracteres).';
      if (e.code == 'email-already-in-use') return 'El correo ya está registrado.';
      return 'Error de autenticación: ${e.message}';
    } catch (e) {
      return 'Error general: $e';
    }
  }

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