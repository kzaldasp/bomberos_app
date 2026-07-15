import 'package:flutter/material.dart';
import '../config/tema_app.dart';

class VistaSinAlertas extends StatelessWidget {
  const VistaSinAlertas({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icono sobrio dentro de un anillo sutil
          Container(
            width: 110,
            height: 110,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: TemaApp.superficie,
              shape: BoxShape.circle,
              border: Border.all(color: TemaApp.borde, width: 1.5),
            ),
            child: const Icon(
              Icons.shield_outlined,
              size: 46,
              color: TemaApp.textoTerciario,
            ),
          ),
          const SizedBox(height: 28),

          const Text(
            "Sin novedades",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: TemaApp.negro,
            ),
          ),
          const SizedBox(height: 8),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              "No hay emergencias activas en este momento. Mantente atento a las notificaciones.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: TemaApp.textoSecundario,
                height: 1.55,
              ),
            ),
          ),

          const SizedBox(height: 36),

          // Pista de uso: la lista se actualiza sola y con pull-to-refresh
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.swipe_down_alt_rounded, size: 16, color: TemaApp.textoTerciario),
              SizedBox(width: 8),
              Text(
                "Desliza hacia abajo para actualizar",
                style: TextStyle(color: TemaApp.textoTerciario, fontSize: 12.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
