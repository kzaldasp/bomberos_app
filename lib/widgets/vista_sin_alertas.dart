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
          // Círculo de fondo suave
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
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
          
          // Botón decorativo o de "Actualizar"
          OutlinedButton.icon(
            onPressed: () {}, 
            // Este botón es solo visual o para forzar refresh manual si quisieras
            style: OutlinedButton.styleFrom(
              foregroundColor: TemaApp.azulInstitucional,
              side: const BorderSide(color: TemaApp.azulInstitucional),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
            ),
            icon: const Icon(Icons.refresh),
            label: const Text("Sincronizar"),
          )
        ],
      ),
    );
  }
}
