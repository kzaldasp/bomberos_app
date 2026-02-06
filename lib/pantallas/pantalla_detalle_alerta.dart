import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart'; // <--- IMPORT NUEVO
import '../modelos/emergencia_modelo.dart';
import '../servicios/servicio_auth.dart';
import '../config/tema_app.dart';

class PantallaDetalleAlerta extends StatefulWidget {
  final EmergenciaModelo alerta;
  final String rolUsuario;

  const PantallaDetalleAlerta({super.key, required this.alerta, required this.rolUsuario});

  @override
  State<PantallaDetalleAlerta> createState() => _PantallaDetalleAlertaState();
}

class _PantallaDetalleAlertaState extends State<PantallaDetalleAlerta> {
  bool _enviandoRespuesta = false;
  bool _yaRespondio = false;

  @override
  void initState() {
    super.initState();
    final miUid = ServicioAuth().usuarioActual?.uid;
    if (miUid != null) {
      final yaEsta = widget.alerta.respuestas.any((r) => r['bombero_uid'] == miUid);
      setState(() {
        _yaRespondio = yaEsta;
      });
    }
  }

  // --- FUNCIÓN NUEVA: ABRIR GPS EXTERNO ---
  Future<void> _abrirMapaExterno() async {
    if (widget.alerta.ubicacion == null) return;
    
    final lat = widget.alerta.ubicacion!.latitude;
    final lng = widget.alerta.ubicacion!.longitude;
    
    // Este link funciona para Google Maps y Waze en Android/iOS
    final Uri googleMapsUrl = Uri.parse("google.navigation:q=$lat,$lng");

    try {
      if (!await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication)) {
        throw 'No se pudo abrir el mapa';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No tienes una app de mapas instalada")));
      }
    }
  }

  void _confirmarAsistencia() async {
    setState(() => _enviandoRespuesta = true);
    try {
      final uid = ServicioAuth().usuarioActual?.uid;
      
      // --- CAMBIO CLAVE: BUSCAMOS EL NOMBRE REAL ---
      // 1. Vamos a la colección de usuarios
      final docUsuario = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
      
      // 2. Sacamos el nombre (o ponemos uno por defecto si no hay)
      String nombreReal = "Bombero";
      if (docUsuario.exists && docUsuario.data()!.containsKey('nombre')) {
        nombreReal = docUsuario.get('nombre');
      } else {
        nombreReal = widget.rolUsuario == 'admin' ? "Comandante" : "Bombero (Sin Nombre)";
      }

      final respuesta = {
        "bombero_uid": uid,
        "nombre": nombreReal, // ¡Aquí va el nombre real!
        "hora": Timestamp.now(),
      };

      await FirebaseFirestore.instance
          .collection('emergencias')
          .doc(widget.alerta.id)
          .update({
            "respuestas": FieldValue.arrayUnion([respuesta])
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Confirmado. ¡Ten cuidado!"), backgroundColor: TemaApp.estadoFinalizado)
        );
        setState(() {
          _yaRespondio = true;
          _enviandoRespuesta = false;
        });
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
        setState(() => _enviandoRespuesta = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    LatLng puntoMapa;
    if (widget.alerta.ubicacion != null) {
      puntoMapa = LatLng(widget.alerta.ubicacion!.latitude, widget.alerta.ubicacion!.longitude);
    } else {
      puntoMapa = const LatLng(0.2343, -78.2625); 
    }

    final colorTema = widget.alerta.estado == 'activa' ? TemaApp.rojoBombero : Colors.grey;

    return Scaffold(
      backgroundColor: TemaApp.fondoClaro,
      appBar: AppBar(
        title: Text(widget.alerta.tipoId.toUpperCase(), style: const TextStyle(fontSize: 16, letterSpacing: 1)),
        backgroundColor: colorTema,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // --- 1. SECCIÓN DEL MAPA ---
          Expanded(
            flex: 4, 
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: puntoMapa,
                    initialZoom: 16.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.bomberos_app',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: puntoMapa,
                          width: 80,
                          height: 80,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(Icons.location_on, color: Colors.black.withOpacity(0.2), size: 55),
                              Icon(Icons.location_on, color: colorTema, size: 50),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                
                // --- BOTÓN NUEVO: ABRIR GOOGLE MAPS ---
                Positioned(
                  bottom: 50,
                  right: 15,
                  child: FloatingActionButton.extended(
                    heroTag: "btnMaps",
                    onPressed: _abrirMapaExterno,
                    backgroundColor: Colors.blueAccent,
                    icon: const Icon(Icons.map, color: Colors.white),
                    label: const Text("IR CON GPS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),

                Positioned(
                  bottom: 0, left: 0, right: 0,
                  height: 40,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withOpacity(0.1)],
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),

          // --- 2. SECCIÓN DE INFORMACIÓN ---
          Expanded(
            flex: 6, 
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -5))
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 30.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            widget.alerta.titulo, 
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: TemaApp.azulInstitucional)
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: TemaApp.grisInput, borderRadius: BorderRadius.circular(20)),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time, size: 14, color: Colors.grey),
                              const SizedBox(width: 5),
                              Text(
                                "${widget.alerta.fechaHora.hour}:${widget.alerta.fechaHora.minute.toString().padLeft(2, '0')}",
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12),
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                    
                    const SizedBox(height: 15),
                    
                    Text(
                      widget.alerta.descripcion, 
                      style: TextStyle(fontSize: 16, color: Colors.grey.shade600, height: 1.5)
                    ),

                    const SizedBox(height: 25),
                    const Divider(),
                    const SizedBox(height: 15),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Personal en camino", 
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey.shade800)
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: TemaApp.azulInstitucional.withOpacity(0.1), shape: BoxShape.circle),
                          child: Text(
                            "${widget.alerta.respuestas.length}",
                            style: const TextStyle(fontWeight: FontWeight.bold, color: TemaApp.azulInstitucional),
                          ),
                        )
                      ],
                    ),

                    const SizedBox(height: 15),

                    Expanded(
                      child: widget.alerta.respuestas.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.group_off_outlined, size: 40, color: Colors.grey.shade300),
                                const SizedBox(height: 10),
                                Text("Esperando respuesta...", style: TextStyle(color: Colors.grey.shade400)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: widget.alerta.respuestas.length,
                            itemBuilder: (context, index) {
                              final respuesta = widget.alerta.respuestas[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: TemaApp.fondoClaro,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: TemaApp.azulInstitucional,
                                    child: const Icon(Icons.person, color: Colors.white, size: 18),
                                  ),
                                  // AHORA MUESTRA EL NOMBRE REAL
                                  title: Text(respuesta['nombre'] ?? 'Bombero', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  subtitle: const Text("En movimiento", style: TextStyle(fontSize: 12, color: Colors.green)),
                                  trailing: const Icon(Icons.directions_run, color: Colors.green, size: 20),
                                ),
                              );
                            },
                          ),
                    ),

                    if (widget.rolUsuario == 'bombero' && widget.alerta.estado == 'activa')
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: (_enviandoRespuesta || _yaRespondio) ? null : _confirmarAsistencia,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _yaRespondio ? TemaApp.estadoFinalizado : TemaApp.rojoBombero,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              elevation: 8,
                              shadowColor: (_yaRespondio ? TemaApp.estadoFinalizado : TemaApp.rojoBombero).withOpacity(0.4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(_yaRespondio ? Icons.check_circle : Icons.notification_important_rounded),
                                const SizedBox(width: 10),
                                Text(
                                  _yaRespondio ? "ASISTENCIA CONFIRMADA" : "¡VOY EN CAMINO!",
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}