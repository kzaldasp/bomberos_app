import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
      // Convertidores especiales (Helper functions)
      color: _hexToColor(data['color'] ?? '#808080'), 
      icono: _stringToIcon(data['icono'] ?? 'alerta'),
    );
  }

  // --- AYUDANTE 1: Convierte texto Hex (#FF0000) a Color Flutter ---
  static Color _hexToColor(String hexCode) {
    try {
      // Quita el '#' si lo tiene y agrega 'FF' para la opacidad
      String cleanHex = hexCode.replaceAll('#', '');
      return Color(int.parse('FF$cleanHex', radix: 16));
    } catch (e) {
      return Colors.grey; // Si falla, devuelve gris
    }
  }

  // --- AYUDANTE 2: Convierte palabra clave a Icono ---
  static IconData _stringToIcon(String nombreIcono) {
    switch (nombreIcono) {
      case 'fuego': return Icons.local_fire_department;
      case 'carro': return Icons.car_crash;
      case 'salvavidas': return Icons.health_and_safety;
      case 'medico': return Icons.medical_services;
      case 'agua': return Icons.water_drop;
      case 'gas': return Icons.propane_tank;
      default: return Icons.warning_amber_rounded;
    }
  }
}