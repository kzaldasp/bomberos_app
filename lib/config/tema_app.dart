import 'package:flutter/material.dart';

class TemaApp {
  // Colores (Mantenemos tu identidad, pero ajustamos tonos)
  static const Color azulInstitucional = Color(0xFF151B54); // Un azul más profundo (Navy)
  static const Color rojoBombero = Color(0xFFD32F2F);
  
  // Colores de fondo modernos
  static const Color fondoClaro = Color(0xFFF8F9FA); // Casi blanco, muy limpio
  static const Color grisInput = Color(0xFFF1F3F4);  // Para las cajas de texto
  
  // Colores de Estado (Más pastel/suaves para no agredir la vista)
  static const Color estadoActivo = Color(0xFFE53935);
  static const Color estadoFinalizado = Color(0xFF43A047);

  static ThemeData obtenerTema() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: fondoClaro,
      
      // Esquema de color base
      colorScheme: ColorScheme.fromSeed(
        seedColor: azulInstitucional,
        primary: azulInstitucional,
        secondary: rojoBombero,
        surface: Colors.white,
        background: fondoClaro,
      ),

      // 1. APPBAR LIMPIO (Sin sombra, estilo plano)
      appBarTheme: const AppBarTheme(
        backgroundColor: azulInstitucional,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: 0.5),
      ),

      // 2. INPUTS MODERNOS (Estilo "burbuja" gris sin bordes duros)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: grisInput,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none, // Sin borde visible por defecto
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: azulInstitucional, width: 1.5),
        ),
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIconColor: Colors.grey,
      ),

      // 3. TARJETAS (Cards) FLOTANTES
      cardTheme: CardTheme(
        color: Colors.white,
        elevation: 0, // Quitamos la sombra por defecto de Material
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20), // Bordes muy redondos
          side: BorderSide(color: Colors.grey.shade200, width: 1), // Borde sutil
        ),
      ),

      // 4. BOTONES GRANDES Y REDONDOS
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: rojoBombero,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: rojoBombero.withOpacity(0.4), // Sombra del mismo color (efecto glow)
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
      ),
    );
  }
}