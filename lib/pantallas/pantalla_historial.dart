import 'package:flutter/material.dart';
import '../config/tema_app.dart';
import '../modelos/emergencia_modelo.dart';
import '../servicios/servicio_emergencias.dart';
import '../widgets/tarjeta_emergencia.dart';
import 'pantalla_detalle_alerta.dart';

class PantallaHistorial extends StatelessWidget {
  final String rolUsuario;

  const PantallaHistorial({super.key, required this.rolUsuario});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TemaApp.fondoClaro,
      appBar: AppBar(
        title: const Text("HISTORIAL OPERATIVO", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
        backgroundColor: Colors.grey.shade800, // Color gris para indicar "pasado"
        centerTitle: true,
        elevation: 0,
      ),
      body: StreamBuilder<List<EmergenciaModelo>>(
        // Solo las FINALIZADAS, ordenadas por fecha (ver ServicioEmergencias)
        stream: ServicioEmergencias().obtenerHistorial(),

        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final alertas = snapshot.data ?? [];
          if (alertas.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_toggle_off, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 20),
                  Text("Sin historial", style: TextStyle(fontSize: 18, color: Colors.grey.shade500)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: alertas.length,
            itemBuilder: (context, index) {
              final alerta = alertas[index];

              // Usamos la misma tarjeta, pero al hacer clic vamos al detalle bloqueado
              return Padding(
                padding: const EdgeInsets.only(bottom: 15),
                child: Opacity(
                  opacity: 0.8, // Un poco transparente para que parezca "viejo"
                  child: TarjetaEmergencia(
                    alerta: alerta,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PantallaDetalleAlerta(
                            alerta: alerta, 
                            rolUsuario: rolUsuario
                          )
                        )
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}