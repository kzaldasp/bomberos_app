import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/utilidad_iconos.dart';

class EmergenciaModelo {
  final String id;
  final String titulo;
  final String descripcion;
  final String tipoId;
  final Timestamp fechaHora;
  final GeoPoint? ubicacion;
  final String estado;
  final List<Map<String, dynamic>> respuestas;

  // PROPIEDADES VISUALES DIRECTAS
  final Color colorCategoria;
  final IconData iconoCategoria;

  EmergenciaModelo({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.tipoId,
    required this.fechaHora,
    this.ubicacion,
    required this.estado,
    required this.respuestas,
    required this.colorCategoria,
    required this.iconoCategoria,
  });

  // --- 1. LECTURA INTELIGENTE DESDE FIREBASE ---
  factory EmergenciaModelo.desdeFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final String tId = data['tipo_id'] ?? 'general';

    // A. RECUPERAR COLOR (Prioridad: Lo que viene guardado en la BD)
    Color colorFinal;
    if (data['color_hex'] != null) {
      // Si existe el campo 'color_hex', lo convertimos a Color
      colorFinal = _hexToColor(data['color_hex']);
    } else {
      // BACKUP: Solo para emergencias viejas que no tengan color guardado
      colorFinal = _colorPorDefecto(tId);
    }

    // B. RECUPERAR ICONO (Usamos el ID para obtenerlo del catálogo de iconos)
    IconData iconoFinal = UtilidadIconos.obtenerIcono(tId);

    return EmergenciaModelo(
      id: doc.id,
      titulo: data['titulo'] ?? 'Sin título',
      descripcion: data['descripcion'] ?? 'Sin detalles',
      tipoId: tId,
      fechaHora: data['fecha_hora'] ?? Timestamp.now(),
      // Soporte para ambos nombres de campo por seguridad
      ubicacion: data['ubicacion'] ?? data['ubicacion_emergencia'], 
      estado: data['estado'] ?? 'activa',
      respuestas: List<Map<String, dynamic>>.from(data['respuestas'] ?? []),
      colorCategoria: colorFinal,
      iconoCategoria: iconoFinal,
    );
  }

  // --- 2. GUARDAR DATOS (No guardamos visuales aquí, eso se hace al crear) ---
  Map<String, dynamic> toMap() {
    return {
      'titulo': titulo,
      'descripcion': descripcion,
      'tipo_id': tipoId,
      'fecha_hora': fechaHora,
      'ubicacion': ubicacion,
      'estado': estado,
      'respuestas': respuestas,
    };
  }

  // --- 3. UTILIDADES INTERNAS ---

  // Convierte "#D32F2F" -> Color(0xFFD32F2F)
  static Color _hexToColor(String hexCode) {
    try {
      String cleanHex = hexCode.replaceAll('#', '');
      if (cleanHex.length == 6) cleanHex = 'FF$cleanHex'; // Agregar opacidad si falta
      return Color(int.parse(cleanHex, radix: 16));
    } catch (e) {
      return Colors.grey; // Si falla, devolvemos gris
    }
  }

  // Solo se usa si la base de datos NO tiene el color guardado (Datos antiguos)
  static Color _colorPorDefecto(String tipoId) {
    switch (tipoId) {
      case 'incendio': return const Color(0xFFD32F2F);
      case 'medico': return const Color(0xFF2E7D32);
      case 'accidente': return const Color(0xFFF57C00);
      default: return Colors.blueGrey;
    }
  }
}