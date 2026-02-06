import 'package:flutter/material.dart';
import '../modelos/emergencia_modelo.dart';

class TarjetaEmergencia extends StatelessWidget {
  final EmergenciaModelo alerta;
  final VoidCallback onTap;

  const TarjetaEmergencia({
    super.key, 
    required this.alerta, 
    required this.onTap
  });

  @override
  Widget build(BuildContext context) {
    // 1. Validar estado
    final bool esFinalizada = alerta.estado == 'finalizada';
    
    // 2. DEFINIR EL COLOR MAESTRO
    // Si la alerta está activa, usamos el color que viene en el modelo (leído de Firebase).
    // Si está finalizada, usamos gris para indicar "historial".
    final Color colorPrioritario = esFinalizada ? Colors.grey : alerta.colorCategoria;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- CABECERA (Chip de Categoría) ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        // Fondo suave del mismo color
                        color: colorPrioritario.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          // Icono del mismo color
                          Icon(alerta.iconoCategoria, size: 14, color: colorPrioritario),
                          const SizedBox(width: 5),
                          // Texto del mismo color
                          Text(
                            alerta.tipoId.toUpperCase(),
                            style: TextStyle(
                              color: colorPrioritario,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Hora
                    Text(
                      "${alerta.fechaHora.toDate().hour}:${alerta.fechaHora.toDate().minute.toString().padLeft(2, '0')}",
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // --- TÍTULO ---
                Text(
                  alerta.titulo,
                  style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.w800,
                    // Si está finalizada, el título se pone gris para no llamar la atención
                    color: esFinalizada ? Colors.grey : const Color(0xFF2D3436),
                  ),
                ),
                
                const SizedBox(height: 6),
                
                // --- DESCRIPCIÓN ---
                Text(
                  alerta.descripcion,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.4),
                ),
                
                const SizedBox(height: 15),
                
                // --- FOOTER (Estado Operativo) ---
                Row(
                  children: [
                    // Icono de estado
                    Icon(
                      esFinalizada ? Icons.archive_outlined : Icons.sensors_rounded, 
                      size: 16, 
                      color: colorPrioritario // <--- Usa el color correcto
                    ),
                    const SizedBox(width: 6),
                    
                    // Texto de estado
                    Text(
                      esFinalizada 
                        ? "CASO CERRADO" 
                        : "${alerta.respuestas.length} EN CAMINO",
                      style: TextStyle(
                        color: colorPrioritario, // <--- Usa el color correcto
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 0.5
                      ),
                    ),
                    
                    const Spacer(),
                    
                    Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey.shade300, size: 14)
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}