import 'package:flutter/material.dart';

class UtilidadIconos {
  
  // Este es el "Diccionario" que traduce: Texto Firebase -> Icono Flutter
  static final Map<String, IconData> _mapaIconos = {
    // --- EMERGENCIAS (Nombres que pusimos en Firebase) ---
    'local_fire_department': Icons.local_fire_department, // Incendio
    'car_crash': Icons.car_crash,                         // Accidente
    'flood': Icons.flood,                                 // Inundación
    'water_drop': Icons.water_drop,                       // Alternativa agua
    'medical_services': Icons.medical_services,           // Médico
    'propane_tank': Icons.propane_tank,                   // Gas
    'pets': Icons.pets,                                   // Animales
    
    // --- EXTRAS (Por si acaso agregas más luego) ---
    'thunderstorm': Icons.thunderstorm,                   // Tormenta
    'landslide': Icons.landslide,                         // Deslizamiento
    'warning': Icons.warning_amber_rounded,               // Generico
    'forest': Icons.forest,                               // Forestal
    'person': Icons.person,
    'group': Icons.group,
  };

  // Función mágica: Le das el texto y te devuelve el Icono
  static IconData obtenerIcono(String? nombre) {
    if (nombre == null) return Icons.help_outline;
    
    // Busca en el mapa, si no encuentra devuelve una interrogación
    return _mapaIconos[nombre] ?? Icons.help_outline;
  }
}