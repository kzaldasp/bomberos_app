import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/utilidad_iconos.dart';

class CategoriaModelo {
  final String id;
  final String nombre;
  final String importancia;
  final Color color;
  final IconData icono;
  final String nombreIcono; // <--- NUEVO: Guardamos el string original (ej: "car_crash")

  CategoriaModelo({
    required this.id,
    required this.nombre,
    required this.importancia,
    required this.color,
    required this.icono,
    required this.nombreIcono, // Requerido
  });

  factory CategoriaModelo.desdeFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return CategoriaModelo(
      id: doc.id,
      nombre: data['nombre'] ?? 'Sin Nombre',
      importancia: data['importancia'] ?? 'MEDIA',
      
      // Convertimos el Hex a Color
      color: _hexToColor(data['color'] ?? '#808080'), 
      
      // Convertimos el String a IconData (Visual)
      icono: UtilidadIconos.obtenerIcono(data['icono']), 
      
      // GUARDAMOS EL STRING ORIGINAL (Para poder reenviarlo luego)
      nombreIcono: data['icono'] ?? 'notifications', 
    );
  }

  static Color _hexToColor(String hexCode) {
    try {
      String cleanHex = hexCode.replaceAll('#', '');
      return Color(int.parse('FF$cleanHex', radix: 16));
    } catch (e) {
      return Colors.grey; 
    }
  }
}