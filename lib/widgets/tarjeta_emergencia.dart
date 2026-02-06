import 'package:flutter/material.dart';
import '../modelos/emergencia_modelo.dart';
import '../config/tema_app.dart';

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
    // Definir color según estado
    final bool esActiva = alerta.estado == 'activa';
    final Color colorEstado = esActiva ? TemaApp.rojoBombero : Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          // Sombra suave estilo iOS
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
                // --- CABECERA: ETIQUETA Y HORA ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Chip de Categoría
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: colorEstado.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.local_fire_department, size: 14, color: colorEstado),
                          const SizedBox(width: 5),
                          Text(
                            alerta.tipoId.toUpperCase(),
                            style: TextStyle(
                              color: colorEstado,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Hora
                    Text(
                      _formatearHora(alerta.fechaHora),
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),

                // --- TÍTULO ---
                Text(
                  alerta.titulo,
                  style: const TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.w800, // Extra Bold
                    color: Color(0xFF2D3436), // Gris casi negro
                  ),
                ),

                const SizedBox(height: 6),

                // --- DESCRIPCIÓN CORTA ---
                Text(
                  alerta.descripcion,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.4),
                ),

                const SizedBox(height: 15),

                // --- FOOTER: RESPUESTAS ---
                Row(
                  children: [
                    // Iconos de avatares (simulados)
                    SizedBox(
                      height: 24,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        shrinkWrap: true,
                        itemCount: alerta.respuestas.length > 3 ? 3 : alerta.respuestas.length,
                        itemBuilder: (context, index) {
                          return Align(
                            widthFactor: 0.7, // Para que se superpongan un poco
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.white,
                              child: CircleAvatar(
                                radius: 10,
                                backgroundColor: TemaApp.azulInstitucional,
                                child: const Icon(Icons.person, size: 12, color: Colors.white),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      alerta.respuestas.isEmpty 
                        ? "Esperando personal..." 
                        : "${alerta.respuestas.length} respondiendo",
                      style: TextStyle(
                        color: alerta.respuestas.isEmpty ? Colors.grey : TemaApp.azulInstitucional,
                        fontWeight: FontWeight.w600,
                        fontSize: 12
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.arrow_forward_rounded, color: Colors.grey.shade300, size: 20)
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatearHora(DateTime fecha) {
    // Un helper simple para la hora
    return "${fecha.hour}:${fecha.minute.toString().padLeft(2, '0')}";
  }
}