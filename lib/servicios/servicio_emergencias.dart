import 'package:cloud_firestore/cloud_firestore.dart';
import '../modelos/emergencia_modelo.dart';

class ServicioEmergencias {
  final CollectionReference _coleccion =
      FirebaseFirestore.instance.collection('emergencias');

  /// Alertas activas para el dashboard, en tiempo real.
  Stream<List<EmergenciaModelo>> obtenerAlertasActivas() {
    return _consultarPorEstado('activa');
  }

  /// Alertas finalizadas para el historial, en tiempo real.
  Stream<List<EmergenciaModelo>> obtenerHistorial() {
    return _consultarPorEstado('finalizada');
  }

  Stream<List<EmergenciaModelo>> _consultarPorEstado(String estado) {
    return _coleccion
        .where('estado', isEqualTo: estado)
        .orderBy('fecha_hora', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(EmergenciaModelo.desdeFirestore).toList());
  }
}
