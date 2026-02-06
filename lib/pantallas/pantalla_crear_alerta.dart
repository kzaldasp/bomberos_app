import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; 
import 'package:latlong2/latlong.dart';       
import 'package:cloud_firestore/cloud_firestore.dart';
import '../servicios/servicio_auth.dart';
import '../modelos/categoria_modelo.dart'; // <--- IMPORTANTE: Importar el modelo

class PantallaCrearAlerta extends StatefulWidget {
  // Ahora esta pantalla NECESITA saber qué categoría se eligió
  final CategoriaModelo categoria;

  const PantallaCrearAlerta({super.key, required this.categoria});

  @override
  State<PantallaCrearAlerta> createState() => _PantallaCrearAlertaState();
}

class _PantallaCrearAlertaState extends State<PantallaCrearAlerta> {
  // Coordenadas iniciales (Centro de Otavalo aprox)
  LatLng _ubicacionSeleccionada = const LatLng(0.2343, -78.2625);
  
  final _descController = TextEditingController();
  bool _guardando = false;

  // Función para subir la alerta a Firebase
  void _publicarAlerta() async {
    setState(() => _guardando = true);

    try {
      // 1. Preparamos los datos AUTOMÁTICOS basados en la categoría
      final alerta = {
        "titulo": widget.categoria.nombre,     // El título ya viene de la categoría
        "tipo_id": widget.categoria.id,        // ID real (ej: 'incendio')
        "tipo_nombre": widget.categoria.nombre,// Nombre legible
        "importancia": widget.categoria.importancia,
        
        "descripcion": _descController.text.trim().isEmpty 
            ? "Sin detalles adicionales" 
            : _descController.text.trim(),
            
        "estado": "activa",
        "fecha_hora": FieldValue.serverTimestamp(),
        "creado_por_uid": ServicioAuth().usuarioActual?.uid,
        
        // Ubicación del mapa
        "ubicacion_emergencia": GeoPoint(_ubicacionSeleccionada.latitude, _ubicacionSeleccionada.longitude),
        
        "respuestas": [] 
      };

      // 2. Guardamos en Firebase
      await FirebaseFirestore.instance.collection('emergencias').add(alerta);

      // 3. Volvemos atrás (Dos veces para cerrar mapa y selección)
      if (mounted) {
        Navigator.pop(context); // Cierra mapa
        Navigator.pop(context); // Cierra selección de tipo
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("🚨 ${widget.categoria.nombre} ENVIADO A LA CENTRAL"), 
            backgroundColor: widget.categoria.color
          )
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
        setState(() => _guardando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // La barra superior toma el color de la emergencia (Rojo, Azul, Naranja...)
      appBar: AppBar(
        title: Text("Ubicación: ${widget.categoria.nombre}"), 
        backgroundColor: widget.categoria.color, 
        foregroundColor: Colors.white
      ),
      body: Column(
        children: [
          // --- SOLO CAMPO DE DESCRIPCIÓN ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: "Detalles adicionales (Opcional)", 
                hintText: "Piso, referencia visual, número de heridos...",
                prefixIcon: Icon(Icons.note_add)
              ),
              maxLines: 2,
            ),
          ),

          // --- EL MAPA ---
          const Padding(
            padding: EdgeInsets.only(left: 16),
            child: Align(alignment: Alignment.centerLeft, child: Text("Mueve el mapa para ajustar la ubicación exacta:", style: TextStyle(fontWeight: FontWeight.bold))),
          ),
          
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Stack(
                  children: [
                    FlutterMap(
                      options: MapOptions(
                        initialCenter: _ubicacionSeleccionada, 
                        initialZoom: 15.0,
                        onTap: (tapPosition, point) {
                          setState(() {
                            _ubicacionSeleccionada = point;
                          });
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.bomberos_app',
                        ),
                        // El Pin del color de la categoría
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _ubicacionSeleccionada,
                              width: 80,
                              height: 80,
                              child: Icon(
                                widget.categoria.icono, // Icono dinámico (Fuego, Auto, etc)
                                color: widget.categoria.color, // Color dinámico
                                size: 50
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Etiqueta flotante de ayuda
                    Positioned(
                      top: 10, right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), borderRadius: BorderRadius.circular(20)),
                        child: const Text("📌 Toca donde es el evento", style: TextStyle(fontSize: 12)),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),

          // --- BOTÓN PUBLICAR ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _guardando ? null : _publicarAlerta,
                icon: const Icon(Icons.send_sharp),
                label: _guardando ? const Text("ENVIANDO...") : const Text("CONFIRMAR ALERTA"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.categoria.color, // Botón del color de la categoría
                  foregroundColor: Colors.white
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}