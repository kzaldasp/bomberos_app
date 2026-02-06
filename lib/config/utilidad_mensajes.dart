import 'package:flutter/material.dart';

class UtilidadMensajes {
  
  // 1. MENSAJE DE ÉXITO (VERDE)
  static void mostrarExito(BuildContext context, String mensaje) {
    _mostrarSnackBar(
      context, 
      mensaje, 
      Colors.green.shade700, 
      Icons.check_circle_rounded
    );
  }

  // 2. MENSAJE DE ERROR (ROJO)
  static void mostrarError(BuildContext context, String mensaje) {
    _mostrarSnackBar(
      context, 
      mensaje, 
      Colors.red.shade700, 
      Icons.error_outline_rounded
    );
  }

  // 3. MENSAJE PERSONALIZADO (Cualquier color - Para categorías)
  static void mostrarPersonalizado(BuildContext context, String mensaje, Color color, IconData icono) {
    _mostrarSnackBar(context, mensaje, color, icono);
  }

  // --- LÓGICA DE DISEÑO PRIVADA ---
  static void _mostrarSnackBar(BuildContext context, String mensaje, Color colorFondo, IconData icono) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar(); // Ocultar anteriores si hay
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icono, color: Colors.white, size: 28), // Icono grande
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                mensaje,
                style: const TextStyle(
                  fontSize: 15, 
                  fontWeight: FontWeight.w600, 
                  color: Colors.white
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: colorFondo,
        behavior: SnackBarBehavior.floating, // FLOTANTE (No pegado al fondo)
        elevation: 6, // Sombra
        margin: const EdgeInsets.all(20), // Margen alrededor
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15) // Bordes curvos
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}