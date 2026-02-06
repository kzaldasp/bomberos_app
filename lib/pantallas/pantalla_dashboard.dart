import 'package:bomberos_app/pantallas/pantalla_seleccion_tipo.dart';
import 'package:flutter/material.dart';
import '../config/tema_app.dart';
import '../servicios/servicio_auth.dart';
import '../servicios/servicio_emergencias.dart'; // Import nuevo
import '../modelos/emergencia_modelo.dart';      // Import nuevo
import 'pantalla_login.dart';
import 'pantalla_detalle_alerta.dart';
import '../widgets/tarjeta_emergencia.dart';
class PantallaDashboard extends StatelessWidget {
  final String rolUsuario;

  const PantallaDashboard({super.key, required this.rolUsuario});

  @override
  Widget build(BuildContext context) {
    final servicioEmergencias = ServicioEmergencias();

    return Scaffold(
      appBar: AppBar(
        title: Text(rolUsuario == 'admin' ? "Panel de Mando" : "Central de Alertas"),
        backgroundColor: TemaApp.azulInstitucional,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () async {
              await ServicioAuth().cerrarSesion();
              if (context.mounted) {
                Navigator.pushReplacement(
                  context, 
                  MaterialPageRoute(builder: (_) => const PantallaLogin())
                );
              }
            },
          )
        ],
      ),
      
      // SOLO EL ADMIN ve el botón de agregar
floatingActionButton: rolUsuario == 'admin' 
  ? FloatingActionButton(
      backgroundColor: TemaApp.rojoBombero,
      onPressed: () {
        // AHORA REDIRIGE A LA SELECCIÓN DE CATEGORÍA
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PantallaSeleccionTipo()),
        );
      },
      child: const Icon(Icons.add, color: Colors.white, size: 30),
    )
  : null,
      // AQUÍ ESTÁ LA LISTA EN TIEMPO REAL
      body: StreamBuilder<List<EmergenciaModelo>>(
        stream: servicioEmergencias.obtenerAlertasEnTiempoReal(),
        builder: (context, snapshot) {
          
          // 1. Cargando...
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. Error
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          // 3. Lista Vacía (Lo que verás ahora)
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 20),
                  const Text("Sin novedades", style: TextStyle(fontSize: 20, color: Colors.grey)),
                  const Text("No hay emergencias activas por ahora.", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          // 4. Hay datos: Pintamos la lista
          final listaAlertas = snapshot.data!;
          
       // ... dentro del StreamBuilder ...
return ListView.builder(
  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25), // Más margen a los lados
  itemCount: listaAlertas.length,
  itemBuilder: (context, index) {
    final alerta = listaAlertas[index];
    
    // USAMOS EL NUEVO DISEÑO AQUÍ
    return TarjetaEmergencia(
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
    );
  },
); },
      ),
    );
  }
}