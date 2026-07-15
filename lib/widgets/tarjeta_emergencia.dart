import 'package:flutter/material.dart';
import '../config/tema_app.dart';
import '../config/utilidad_formato.dart';
import '../modelos/emergencia_modelo.dart';

class TarjetaEmergencia extends StatelessWidget {
  final EmergenciaModelo alerta;
  final VoidCallback onTap;

  const TarjetaEmergencia({
    super.key,
    required this.alerta,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool esFinalizada = alerta.estado == 'finalizada';

    // Color maestro: el de la categoría si está activa, gris si ya cerró.
    final Color colorCategoria = esFinalizada ? TemaApp.textoTerciario : alerta.colorCategoria;

    return Container(
      decoration: TemaApp.decoracionTarjeta(),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Franja lateral con el color de la categoría
                Container(width: 4, color: colorCategoria),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ---- Cabecera: categoría + hora ----
                        Row(
                          children: [
                            Icon(alerta.iconoCategoria, size: 15, color: colorCategoria),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                alerta.tipoId.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colorCategoria,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10.5,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ),
                            Text(
                              UtilidadFormato.horaInteligente(alerta.fechaHora.toDate()),
                              style: const TextStyle(
                                color: TemaApp.textoTerciario,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // ---- Título ----
                        Text(
                          alerta.titulo,
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: esFinalizada ? TemaApp.textoSecundario : TemaApp.negro,
                          ),
                        ),

                        const SizedBox(height: 4),

                        // ---- Descripción ----
                        Text(
                          alerta.descripcion,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: TemaApp.textoSecundario,
                            fontSize: 13.5,
                            height: 1.45,
                          ),
                        ),

                        const SizedBox(height: 12),

                        // ---- Pie: estado operativo ----
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: esFinalizada
                                    ? TemaApp.relleno
                                    : colorCategoria.withValues(alpha: 0.09),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    esFinalizada ? Icons.check_rounded : Icons.sensors_rounded,
                                    size: 13,
                                    color: colorCategoria,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    esFinalizada
                                        ? "CASO CERRADO"
                                        : "${alerta.respuestas.length} EN CAMINO",
                                    style: TextStyle(
                                      color: colorCategoria,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 10.5,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: TemaApp.textoTerciario,
                              size: 20,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
