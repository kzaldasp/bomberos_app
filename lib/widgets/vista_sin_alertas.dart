import 'package:flutter/material.dart';

class VistaSinAlertas extends StatelessWidget {
  const VistaSinAlertas({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Círculo de fondo suave
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.verified_user_rounded, // Escudo de seguridad
              size: 80,
              color: Colors.green.shade400,
            ),
          ),
          const SizedBox(height: 25),
          
          Text(
            "Sin Novedades",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
              letterSpacing: 1
            ),
          ),
          const SizedBox(height: 10),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "Todo está tranquilo en la ciudad. Mantente alerta a nuevas notificaciones.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade500,
                height: 1.5
              ),
            ),
          ),
          
          const SizedBox(height: 40),
          
          // Pista de uso: la lista se actualiza sola y con pull-to-refresh
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.swipe_down_alt_rounded, size: 18, color: Colors.grey.shade400),
              const SizedBox(width: 8),
              Text(
                "Desliza hacia abajo para actualizar",
                style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              ),
            ],
          )
        ],
      ),
    );
  }
}
