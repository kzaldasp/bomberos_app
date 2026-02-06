import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'package:geolocator/geolocator.dart';
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
    _verificarSiYaRespondio();
  }

  void _verificarSiYaRespondio() {
    final miUid = ServicioAuth().usuarioActual?.uid;
    if (miUid != null) {
      final yaEsta = widget.alerta.respuestas.any((r) => r['bombero_uid'] == miUid);
      if (mounted) {
        setState(() {
          _yaRespondio = yaEsta;
        });
      }
    }
  }

  // --- 1. ABRIR GOOGLE MAPS (DESTINO INCENDIO) ---
  Future<void> _abrirMapaExterno() async {
    if (widget.alerta.ubicacion == null) return;
    
    final lat = widget.alerta.ubicacion!.latitude;
    final lng = widget.alerta.ubicacion!.longitude;
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

  // --- 2. VER UBICACIÓN DE UN BOMBERO (SOLO ADMIN) ---
  void _verUbicacionBombero(Map<String, dynamic> respuesta) async {
    if (respuesta['ubicacion_inicial'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sin ubicación registrada")));
      return;
    }

    final GeoPoint gp = respuesta['ubicacion_inicial'];
    final Uri url = Uri.parse("geo:${gp.latitude},${gp.longitude}?q=${gp.latitude},${gp.longitude}(${respuesta['nombre']})");

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error al abrir mapa")));
    }
  }

  // --- 3. CONFIRMAR ASISTENCIA (BOMBERO) ---
  void _confirmarAsistencia() async {
    setState(() => _enviandoRespuesta = true);

    try {
      // A. Permisos
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw 'Se requiere ubicación';
      }
      
      // B. Coordenadas
      Position posicion = await Geolocator.getCurrentPosition();

      // C. Datos Usuario
      final uid = ServicioAuth().usuarioActual?.uid;
      final docUsuario = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
      String nombreReal = docUsuario.data()?['nombre'] ?? (widget.rolUsuario == 'admin' ? "Comandante" : "Bombero");

      // D. Enviar
      final respuesta = {
        "bombero_uid": uid,
        "nombre": nombreReal,
        "hora": Timestamp.now(),
        "ubicacion_inicial": GeoPoint(posicion.latitude, posicion.longitude),
      };

      await FirebaseFirestore.instance.collection('emergencias').doc(widget.alerta.id).update({
        "respuestas": FieldValue.arrayUnion([respuesta])
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ En camino. ¡Conduce con cuidado!"), backgroundColor: Colors.green)
        );
        setState(() { _yaRespondio = true; _enviandoRespuesta = false; });
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _enviandoRespuesta = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  // --- 4. FINALIZAR EMERGENCIA (ADMIN) ---
  void _finalizarEmergencia() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Cerrar Operativo?"),
        content: const Text("La emergencia pasará al historial y se notificará el cierre."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("FINALIZAR", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      setState(() => _enviandoRespuesta = true);
      try {
        await FirebaseFirestore.instance.collection('emergencias').doc(widget.alerta.id).update({
          'estado': 'finalizada'
        });
        if (mounted) {
          Navigator.pop(context); // Volver al dashboard
        }
      } catch (e) {
        setState(() => _enviandoRespuesta = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Configuración Mapa
    final LatLng puntoMapa = widget.alerta.ubicacion != null 
        ? LatLng(widget.alerta.ubicacion!.latitude, widget.alerta.ubicacion!.longitude)
        : const LatLng(0.2343, -78.2625);

    // Color según estado: Si finalizada es GRIS, si no, es el color de su CATEGORÍA
    final bool esFinalizada = widget.alerta.estado == 'finalizada';
    final Color colorTema = esFinalizada ? Colors.grey : widget.alerta.colorCategoria;

    return Scaffold(
      backgroundColor: TemaApp.fondoClaro,
      appBar: AppBar(
        title: Text(widget.alerta.tipoId.toUpperCase(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
        backgroundColor: colorTema,
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          // --- MAPA SUPERIOR ---
          Expanded(
            flex: 4,
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(initialCenter: puntoMapa, initialZoom: 16.0),
                  children: [
                    TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.bomberos.app'),
                    MarkerLayer(
                      markers: [
                        // INCENDIO
                        Marker(
                          point: puntoMapa,
                          width: 80, height: 80,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(Icons.location_on, color: colorTema, size: 50),
                              const Positioned(top: 12, child: Icon(Icons.fire_truck, color: Colors.white, size: 20)),
                            ],
                          ),
                        ),
                        // BOMBEROS
                        ...widget.alerta.respuestas.map((r) {
                          if (r['ubicacion_inicial'] == null) return const Marker(point: LatLng(0,0), child: SizedBox());
                          final gp = r['ubicacion_inicial'] as GeoPoint;
                          return Marker(
                            point: LatLng(gp.latitude, gp.longitude),
                            width: 60, height: 60,
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  color: Colors.white,
                                  child: Text(r['nombre'] ?? 'B', style: const TextStyle(fontSize: 8)),
                                ),
                                const Icon(Icons.directions_car, color: TemaApp.azulInstitucional, size: 30),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  bottom: 50, right: 15,
                  child: FloatingActionButton.extended(
                    heroTag: "gpsBtn",
                    onPressed: _abrirMapaExterno,
                    backgroundColor: esFinalizada ? Colors.grey : Colors.blueAccent,
                    icon: const Icon(Icons.map, color: Colors.white),
                    label: const Text("IR AL SITIO", style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),

          // --- DETALLE INFERIOR ---
          Expanded(
            flex: 6,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [BoxShadow(blurRadius: 20, color: Colors.black12)],
              ),
              child: Padding(
                padding: const EdgeInsets.all(25.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Título
                    Text(widget.alerta.titulo, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: colorTema)),
                    const SizedBox(height: 10),
                    Text(widget.alerta.descripcion, style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                    
                    const SizedBox(height: 20),
                    const Divider(),
                    
                    // Lista Bomberos
                    Text("Personal (${widget.alerta.respuestas.length})", style: const TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(
                      child: ListView.builder(
                        itemCount: widget.alerta.respuestas.length,
                        itemBuilder: (ctx, i) {
                          final r = widget.alerta.respuestas[i];
                          final Timestamp? ts = r['hora'];
                          final hora = ts != null ? "${ts.toDate().hour}:${ts.toDate().minute.toString().padLeft(2,'0')}" : "--:--";
                          
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const CircleAvatar(backgroundColor: TemaApp.azulInstitucional, radius: 15, child: Icon(Icons.person, size: 15, color: Colors.white)),
                            title: Text(r['nombre'] ?? 'Bombero', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(widget.rolUsuario == 'admin' ? "Salida: $hora - Ver Mapa" : "En camino"),
                            trailing: widget.rolUsuario == 'admin' 
                                ? const Icon(Icons.location_searching, color: Colors.blue)
                                : const Icon(Icons.check, color: Colors.green),
                            onTap: widget.rolUsuario == 'admin' ? () => _verUbicacionBombero(r) : null,
                          );
                        },
                      ),
                    ),

                    // --- BOTONES DE ACCIÓN ---
                    if (esFinalizada)
                       Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(15),
                        color: Colors.grey.shade100,
                        child: const Center(child: Text("CASO CERRADO", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 2))),
                       )
                    else if (widget.rolUsuario == 'admin')
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black87,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                          ),
                          onPressed: _enviandoRespuesta ? null : _finalizarEmergencia,
                          icon: const Icon(Icons.stop_circle_outlined, color: Colors.white),
                          label: const Text("FINALIZAR OPERATIVO", style: TextStyle(color: Colors.white)),
                        ),
                      )
                    else if (widget.rolUsuario == 'bombero')
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _yaRespondio ? Colors.green : TemaApp.rojoBombero,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                          ),
                          onPressed: (_enviandoRespuesta || _yaRespondio) ? null : _confirmarAsistencia,
                          icon: Icon(_yaRespondio ? Icons.check : Icons.directions_run, color: Colors.white),
                          label: Text(_yaRespondio ? "ASISTENCIA CONFIRMADA" : "VOY EN CAMINO", style: const TextStyle(color: Colors.white)),
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