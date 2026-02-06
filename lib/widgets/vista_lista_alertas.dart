import 'package:flutter/material.dart';
import '../modelos/emergencia_modelo.dart';
import '../servicios/servicio_emergencias.dart';
import 'tarjeta_emergencia.dart';
import '../pantallas/pantalla_detalle_alerta.dart';

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
      // --- CAMBIO CLAVE AQUÍ ---
      // Llamamos a la función que filtra: WHERE estado == 'activa'
      stream: servicioEmergencias.obtenerAlertasActivas(), 
      
      builder: (context, snapshot) {
        
        // 1. Estado de Carga
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // 2. Estado de Error
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        // 3. Estado Vacío (Sin novedades)
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _vistaSinAlertas();
        }

        // 4. Estado con Datos
        final listaAlertas = snapshot.data!;
        
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
          itemCount: listaAlertas.length,
          itemBuilder: (context, index) {
            final alerta = listaAlertas[index];
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 15.0),
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

  Widget _vistaSinAlertas() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 20),
          Text(
            "Sin novedades",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 5),
          const Text("El cuartel está tranquilo.", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}