import 'package:cloud_firestore/cloud_firestore.dart';

class EmergenciaModelo {
  final String id;
  final String titulo;
  final String descripcion;
  final String estado;
  final DateTime fechaHora;
  final String tipoId;
  
  // NUEVOS CAMPOS:
  final GeoPoint? ubicacion; // Puede ser null si es una alerta vieja
  final List<dynamic> respuestas; // Lista de bomberos que van

  EmergenciaModelo({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.estado,
    required this.fechaHora,
    required this.tipoId,
    this.ubicacion,     // Nuevo
    this.respuestas = const [], // Nuevo, por defecto vacía
  });

  factory EmergenciaModelo.desdeFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return EmergenciaModelo(
      id: doc.id,
      titulo: data['titulo'] ?? 'Sin título',
      descripcion: data['descripcion'] ?? '',
      estado: data['estado'] ?? 'activa',
      tipoId: data['tipo_id'] ?? 'general',
      fechaHora: (data['fecha_hora'] as Timestamp).toDate(),
      
      // LEEMOS LOS NUEVOS DATOS
      ubicacion: data['ubicacion_emergencia'], // Firebase devuelve GeoPoint directo
      respuestas: data['respuestas'] ?? [],
    );
  }
}