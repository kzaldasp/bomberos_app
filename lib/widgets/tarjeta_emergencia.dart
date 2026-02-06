import 'package:flutter/material.dart';
import '../modelos/emergencia_modelo.dart';
// import '../config/tema_app.dart'; // Ya no lo necesitamos si usamos colores dinámicos

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
    // 1. Definir estado y color maestro
    final bool esFinalizada = alerta.estado == 'finalizada';
    
    // Si está activa, el color es el de la categoría (Rojo, Verde, etc.)
    // Si está finalizada, es Gris.
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
                // --- CABECERA ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: colorPrioritario.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(alerta.iconoCategoria, size: 14, color: colorPrioritario),
                          const SizedBox(width: 5),
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
                
                // --- FOOTER (CORREGIDO) ---
                Row(
                  children: [
                    // Icono de estado (Radar o Archivo)
                    Icon(
                      esFinalizada ? Icons.archive_outlined : Icons.sensors, 
                      size: 16, 
                      color: colorPrioritario // <--- Ahora usa el color correcto
                    ),
                    const SizedBox(width: 6),
                    
                    // Texto de estado
                    Text(
                      esFinalizada 
                        ? "CASO CERRADO" 
                        : "${alerta.respuestas.length} EN CAMINO",
                      style: TextStyle(
                        color: colorPrioritario, // <--- Ahora usa el color correcto (Rojo/Verde), NO Azul
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