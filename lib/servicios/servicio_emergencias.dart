import 'package:cloud_firestore/cloud_firestore.dart';
import '../modelos/emergencia_modelo.dart';

class ServicioEmergencias {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Stream: Es como un río de datos. Si algo cambia en Firebase, 
  // la app se entera al instante.
  Stream<List<EmergenciaModelo>> obtenerAlertasEnTiempoReal() {
    return _db
        .collection('emergencias') // Escuchamos esta colección (aunque aún no exista)
        .orderBy('fecha_hora', descending: true) // Las más nuevas primero
        .snapshots()
        .map((snapshot) => 
            snapshot.docs.map((doc) => EmergenciaModelo.desdeFirestore(doc)).toList()
        );
  }
}