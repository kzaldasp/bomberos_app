import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../servicios/servicio_auth.dart';
import '../modelos/categoria_modelo.dart';

class PantallaCrearAlerta extends StatefulWidget {
  final CategoriaModelo categoria;

  const PantallaCrearAlerta({super.key, required this.categoria});

  @override
  State<PantallaCrearAlerta> createState() => _PantallaCrearAlertaState();
}

class _PantallaCrearAlertaState extends State<PantallaCrearAlerta> {
  LatLng _ubicacionSeleccionada = const LatLng(0.2343, -78.2625);
  late final TextEditingController _descController;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _descController = TextEditingController();
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  // Helper: Convierte Color(0xFFF57C00) -> String "#F57C00"
  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
  }

  void _publicarAlerta() async {
    if (_guardando) return;
    setState(() => _guardando = true);

    try {
      // 1. PREPARAR DATOS EXACTOS COMO LOS PEDISTE
      // Convertimos el color de vuelta a String Hex
      final String colorString = _colorToHex(widget.categoria.color);
      
      // Asumimos que el ID de la categoría (ej: 'incendio') o una propiedad 'nombreIcono'
      // contiene el string "car_crash" o "local_fire_department".
      // Si tu modelo no tiene el campo 'nombreIcono', usamos 'id' o lo que uses para el string del icono.
      // Aquí intentaré usar una propiedad 'nombreIcono' si existe, si no, uso el ID como fallback.
      final String iconoString = widget.categoria.id; // O widget.categoria.nombreIcono

      final alerta = {
        // Datos de Identificación
        "titulo": widget.categoria.nombre,
        "tipo_id": widget.categoria.id,
        "tipo_nombre": widget.categoria.nombre,
        "importancia": widget.categoria.importancia,
        
        // --- AQUÍ ESTÁ LO QUE PEDISTE ---
        // Guardamos los strings exactos para pintar luego
        "color": colorString,  // Ej: "#F57C00"
        "icono": iconoString,  // Ej: "car_crash" (o el ID que mapea al icono)
        // -------------------------------

        "descripcion": _descController.text.trim().isEmpty 
            ? "Sin detalles adicionales" 
            : _descController.text.trim(),
            
        "estado": "activa",
        "fecha_hora": FieldValue.serverTimestamp(),
        "creado_por_uid": ServicioAuth().usuarioActual?.uid,
        "ubicacion": GeoPoint(_ubicacionSeleccionada.latitude, _ubicacionSeleccionada.longitude),
        "respuestas": [] 
      };

      await FirebaseFirestore.instance.collection('emergencias').add(alerta);

      if (mounted) {
        Navigator.pop(context); 
        Navigator.pop(context); 
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 10),
              Text("¡ALERTA DE ${widget.categoria.nombre.toUpperCase()} ENVIADA!"),
            ]),
            backgroundColor: widget.categoria.color,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          )
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
        setState(() => _guardando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorCat = widget.categoria.color;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text("Confirmar ${widget.categoria.nombre}", style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: colorCat,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 1. INPUT
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))]
            ),
            child: TextField(
              controller: _descController,
              decoration: InputDecoration(
                labelText: "Detalles adicionales",
                hintText: "Ej: Piso 2, referencia visual...",
                prefixIcon: Icon(Icons.description_outlined, color: colorCat),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade300)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: colorCat, width: 2)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              maxLines: 2,
            ),
          ),

          const SizedBox(height: 20),

          // 2. INSTRUCCIÓN
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(Icons.location_on_rounded, color: colorCat, size: 20),
                const SizedBox(width: 8),
                Text("Ubicación exacta:", style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text("Mueve el mapa", style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
              ],
            ),
          ),
          
          const SizedBox(height: 10),

          // 3. MAPA CON MIRA
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
                border: Border.all(color: Colors.white, width: 4),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    FlutterMap(
                      options: MapOptions(
                        initialCenter: _ubicacionSeleccionada,
                        initialZoom: 16.5,
                        onTap: (_, point) => setState(() => _ubicacionSeleccionada = point),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.bomberos.app',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _ubicacionSeleccionada,
                              width: 60, height: 60,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Halo
                                  Container(
                                    width: 60, height: 60,
                                    decoration: BoxDecoration(
                                      color: colorCat.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: colorCat.withOpacity(0.5), width: 1),
                                    ),
                                  ),
                                  // Punto central
                                  Container(
                                    width: 12, height: 12,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: colorCat, width: 3),
                                    ),
                                  ),
                                  // Icono
                                  Positioned(
                                    top: 5,
                                    child: Icon(widget.categoria.icono, size: 18, color: colorCat),
                                  )
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 4. BOTÓN
          Container(
            padding: const EdgeInsets.all(20.0),
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _guardando ? null : _publicarAlerta,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorCat,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                icon: _guardando 
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white))
                  : const Icon(Icons.podcasts, size: 26),
                label: Text(
                  _guardando ? "ENVIANDO..." : "CONFIRMAR ALERTA",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}