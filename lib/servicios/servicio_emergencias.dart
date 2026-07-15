import 'package:cloud_firestore/cloud_firestore.dart';
import '../modelos/emergencia_modelo.dart';

class ServicioEmergencias {
  /// Tamaño de página del historial: acota las lecturas de Firestore
  /// aunque el archivo de casos crezca durante años.
  static const int tamanoPaginaHistorial = 25;

  final CollectionReference _coleccion =
      FirebaseFirestore.instance.collection('emergencias');

  /// Alertas activas para el dashboard, en tiempo real.
  /// (Las activas son pocas por naturaleza; aquí sí conviene el stream.)
  Stream<List<EmergenciaModelo>> obtenerAlertasActivas() {
    return _coleccion
        .where('estado', isEqualTo: 'activa')
        .orderBy('fecha_hora', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(EmergenciaModelo.desdeFirestore).toList());
  }

  /// Una página del historial de casos finalizados.
  ///
  /// Un caso cerrado ya no cambia, así que se lee con un get() puntual
  /// (sin listener) y por páginas: abrir el historial cuesta como máximo
  /// [tamanoPaginaHistorial] lecturas, sin importar cuántos años de casos
  /// se acumulen. [despuesDe] es el cursor de la página anterior.
  Future<({List<EmergenciaModelo> alertas, DocumentSnapshot? cursor, bool hayMas})>
      obtenerPaginaHistorial({DocumentSnapshot? despuesDe}) async {
    Query consulta = _coleccion
        .where('estado', isEqualTo: 'finalizada')
        .orderBy('fecha_hora', descending: true)
        .limit(tamanoPaginaHistorial);
    if (despuesDe != null) {
      consulta = consulta.startAfterDocument(despuesDe);
    }

    final snapshot = await consulta.get();
    return (
      alertas: snapshot.docs.map(EmergenciaModelo.desdeFirestore).toList(),
      cursor: snapshot.docs.isEmpty ? null : snapshot.docs.last,
      hayMas: snapshot.docs.length == tamanoPaginaHistorial,
    );
  }

  /// Borra los casos finalizados con más de [dias] días de antigüedad,
  /// incluyendo sus trayectos residuales. Devuelve cuántos se eliminaron.
  ///
  /// Solo un admin puede ejecutarlo (lo exigen las reglas de Firestore).
  /// Mantiene acotados el almacenamiento (1 GiB gratis) y el historial.
  Future<int> depurarHistorialAntiguo({int dias = 365}) async {
    final Timestamp limite =
        Timestamp.fromDate(DateTime.now().subtract(Duration(days: dias)));

    final snapshot = await _coleccion
        .where('estado', isEqualTo: 'finalizada')
        .where('fecha_hora', isLessThan: limite)
        .get();

    for (final doc in snapshot.docs) {
      final trayectos = await doc.reference.collection('trayectos').get();
      final batch = FirebaseFirestore.instance.batch();
      for (final trayecto in trayectos.docs) {
        batch.delete(trayecto.reference);
      }
      batch.delete(doc.reference);
      await batch.commit();
    }
    return snapshot.docs.length;
  }
}
