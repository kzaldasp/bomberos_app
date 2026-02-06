import 'package:cloud_firestore/cloud_firestore.dart';
import '../modelos/emergencia_modelo.dart';

class ServicioEmergencias {
  final CollectionReference _coleccion = FirebaseFirestore.instance.collection('emergencias');

  // 1. OBTENER SOLO ACTIVAS (Para el Dashboard)
  Stream<List<EmergenciaModelo>> obtenerAlertasActivas() {
    return _coleccion
        .where('estado', isEqualTo: 'activa') // <--- EL FILTRO MÁGICO
        .orderBy('fecha_hora', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return EmergenciaModelo.desdeFirestore(doc);
          }).toList();
        });
  }

  // 2. OBTENER SOLO FINALIZADAS (Para el Historial)
  Stream<List<EmergenciaModelo>> obtenerHistorial() {
    return _coleccion
        .where('estado', isEqualTo: 'finalizada')
        .orderBy('fecha_hora', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return EmergenciaModelo.desdeFirestore(doc);
          }).toList();
        });
  }

  // 3. CREAR ALERTA
  Future<void> crearEmergencia(EmergenciaModelo emergencia) async {
    await _coleccion.doc(emergencia.id).set(emergencia.toMap());
  }
}