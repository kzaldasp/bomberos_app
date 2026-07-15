import 'package:flutter/material.dart';

/// Sistema de diseño de la app.
///
/// Identidad tomada del escudo institucional: rojo bombero, negro y blanco.
/// Estilo: minimalista y plano — superficies blancas, bordes sutiles de 1px,
/// un solo radio de esquina y el rojo reservado para las acciones importantes.
class TemaApp {
  // ---- PALETA (colores del logo) ----
  static const Color rojo = Color(0xFFC8102E); // Rojo del escudo
  static const Color rojoOscuro = Color(0xFF9B0C23); // Para estados presionados
  static const Color rojoSuave = Color(0xFFFCE9EC); // Fondo de acentos rojos

  static const Color negro = Color(0xFF17181C); // Negro carbón (textos y énfasis)
  static const Color textoSecundario = Color(0xFF6E7278);
  static const Color textoTerciario = Color(0xFFA6AAB0);

  static const Color fondo = Color(0xFFF7F7F8); // Fondo general gris muy claro
  static const Color superficie = Colors.white; // Tarjetas y paneles
  static const Color borde = Color(0xFFE9EAEC); // Bordes de 1px
  static const Color relleno = Color(0xFFF2F3F4); // Fondo de inputs

  static const Color exito = Color(0xFF1E9E5A);
  static const Color advertencia = Color(0xFFE8930C);

  // ---- MÉTRICAS UNIFICADAS ----
  static const double radio = 14; // Inputs, botones, chips
  static const double radioTarjeta = 18; // Tarjetas y paneles

  /// Borde estándar de tarjetas/paneles blancos.
  static BoxDecoration decoracionTarjeta({double? radioPersonalizado}) {
    return BoxDecoration(
      color: superficie,
      borderRadius: BorderRadius.circular(radioPersonalizado ?? radioTarjeta),
      border: Border.all(color: borde),
    );
  }

  static ThemeData obtenerTema() {
    final base = ThemeData(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: fondo,

      colorScheme: ColorScheme.fromSeed(
        seedColor: rojo,
        primary: rojo,
        secondary: negro,
        surface: superficie,
        error: rojoOscuro,
      ),

      // APPBAR: blanco, plano, texto negro. El color lo pone el contenido.
      appBarTheme: const AppBarTheme(
        backgroundColor: superficie,
        foregroundColor: negro,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        shape: Border(bottom: BorderSide(color: borde)),
        titleTextStyle: TextStyle(
          color: negro,
          fontSize: 16,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
        iconTheme: IconThemeData(color: negro, size: 22),
      ),

      // INPUTS: relleno gris claro, sin borde hasta enfocar (rojo fino).
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: relleno,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radio),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radio),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radio),
          borderSide: const BorderSide(color: rojo, width: 1.4),
        ),
        labelStyle: const TextStyle(color: textoSecundario),
        hintStyle: const TextStyle(color: textoTerciario),
        prefixIconColor: textoTerciario,
        suffixIconColor: textoTerciario,
      ),

      // TARJETAS: planas, borde de 1px, sin sombra.
      cardTheme: CardThemeData(
        color: superficie,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radioTarjeta),
          side: const BorderSide(color: borde),
        ),
      ),

      // BOTÓN PRINCIPAL: rojo plano, sin brillos.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: rojo,
          foregroundColor: Colors.white,
          disabledBackgroundColor: rojo.withValues(alpha: 0.35),
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radio)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.6),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: negro,
          side: const BorderSide(color: borde),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radio)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: rojo,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: rojo,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      dividerTheme: const DividerThemeData(color: borde, thickness: 1, space: 1),

      dialogTheme: DialogThemeData(
        backgroundColor: superficie,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radioTarjeta)),
        titleTextStyle: const TextStyle(color: negro, fontSize: 17, fontWeight: FontWeight.w800),
        contentTextStyle: const TextStyle(color: textoSecundario, fontSize: 14, height: 1.5),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: superficie,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? Colors.white : Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? rojo : const Color(0xFFD8DADD),
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(color: rojo),
    );
  }
}
