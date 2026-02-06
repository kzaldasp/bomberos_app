import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/utilidad_iconos.dart'; // <--- 1. IMPORTAR ESTO

class CategoriaModelo {
  final String id;
  final String nombre;
  final String importancia;
  final Color color;
  final IconData icono;

  CategoriaModelo({
    required this.id,
    required this.nombre,
    required this.importancia,
    required this.color,
    required this.icono,
  });

  // Fábrica: Convierte el documento de Firebase en un objeto útil
  factory CategoriaModelo.desdeFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return CategoriaModelo(
      id: doc.id,
      nombre: data['nombre'] ?? 'Sin Nombre',
      importancia: data['importancia'] ?? 'MEDIA',
      
      // Ayudante de Color (Hex a Color)
      color: _hexToColor(data['color'] ?? '#808080'), 
      
      // 2. CAMBIO AQUÍ: Usamos nuestro nuevo Diccionario
      icono: UtilidadIconos.obtenerIcono(data['icono']), 
    );
  }

  // --- AYUDANTE: Convierte texto Hex (#FF0000) a Color Flutter ---
  static Color _hexToColor(String hexCode) {
    try {
      String cleanHex = hexCode.replaceAll('#', '');
      return Color(int.parse('FF$cleanHex', radix: 16));
    } catch (e) {
      return Colors.grey; 
    }
  }
}