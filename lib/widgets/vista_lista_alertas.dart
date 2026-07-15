import 'package:flutter/material.dart';
import '../modelos/emergencia_modelo.dart';
import '../servicios/servicio_emergencias.dart';
import 'tarjeta_emergencia.dart';
import '../pantallas/pantalla_detalle_alerta.dart';
import 'vista_sin_alertas.dart';

class VistaListaAlertas extends StatelessWidget {
  final ServicioEmergencias servicioEmergencias;
  final String rolUsuario;

  const VistaListaAlertas({
    super.key,
    required this.servicioEmergencias,
    required this.rolUsuario,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<EmergenciaModelo>>(
      // Solo alertas con estado == 'activa'
      stream: servicioEmergencias.obtenerAlertasActivas(),

      builder: (context, snapshot) {
        // 1. Estado de Error
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        // 2. Estado de Carga
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // 3. Estado Vacío (Sin novedades)
        final listaAlertas = snapshot.data ?? [];
        if (listaAlertas.isEmpty) {
          return const VistaSinAlertas();
        }
        
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
          itemCount: listaAlertas.length,
          itemBuilder: (context, index) {
            final alerta = listaAlertas[index];

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: TarjetaEmergencia(
                alerta: alerta,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PantallaDetalleAlerta(
                        alerta: alerta, 
                        rolUsuario: rolUsuario
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}