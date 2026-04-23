import 'package:cloud_firestore/cloud_firestore.dart';

class EventoModelo {
  final String id;
  final String tipoEvento; // "Operativo", "Entrenamiento", "Capacitación"
  final String descripcion;
  final Timestamp fechaProgramada;
  final String? urlAdjunto;
  final String creadoPorId; // Para saber qué administrador lo creó

  EventoModelo({
    required this.id,
    required this.tipoEvento,
    required this.descripcion,
    required this.fechaProgramada,
    this.urlAdjunto,
    required this.creadoPorId,
  });

  factory EventoModelo.desdeFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return EventoModelo(
      id: doc.id,
      tipoEvento: data['tipo_evento'] ?? 'Evento',
      descripcion: data['descripcion'] ?? '',
      fechaProgramada: data['fecha_programada'] ?? Timestamp.now(),
      urlAdjunto: data['url_adjunto'],
      creadoPorId: data['creado_por_id'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tipo_evento': tipoEvento,
      'descripcion': descripcion,
      'fecha_programada': fechaProgramada,
      'url_adjunto': urlAdjunto,
      'creado_por_id': creadoPorId,
    };
  }
}