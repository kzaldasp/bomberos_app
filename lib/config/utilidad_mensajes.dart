import 'package:flutter/material.dart';
import 'tema_app.dart';

/// SnackBars del sistema: fondo negro carbón uniforme con el icono en el
/// color semántico (éxito, error o el de la categoría). Sobrio y legible.
class UtilidadMensajes {
  // 1. MENSAJE DE ÉXITO
  static void mostrarExito(BuildContext context, String mensaje) {
    _mostrarSnackBar(context, mensaje, TemaApp.exito, Icons.check_circle_rounded);
  }

  // 2. MENSAJE DE ERROR
  static void mostrarError(BuildContext context, String mensaje) {
    _mostrarSnackBar(context, mensaje, TemaApp.rojo, Icons.error_outline_rounded);
  }

  // 3. MENSAJE PERSONALIZADO (cualquier color — para categorías)
  static void mostrarPersonalizado(BuildContext context, String mensaje, Color color, IconData icono) {
    _mostrarSnackBar(context, mensaje, color, icono);
  }

  // --- LÓGICA DE DISEÑO PRIVADA ---
  static void _mostrarSnackBar(BuildContext context, String mensaje, Color colorAcento, IconData icono) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar(); // Ocultar anteriores si hay

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icono, color: colorAcento, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                mensaje,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  height: 1.35,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: TemaApp.negro,
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(TemaApp.radio)),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
