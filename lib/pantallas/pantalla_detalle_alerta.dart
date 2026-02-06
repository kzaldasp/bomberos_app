import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'package:geolocator/geolocator.dart';
import '../modelos/emergencia_modelo.dart';
import '../servicios/servicio_auth.dart';
import '../config/tema_app.dart';
import '../config/utilidad_mensajes.dart'; // <--- Importar la utilidad
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
        UtilidadMensajes.mostrarError(context,"No tienes una app de mapas instalada");
      }
    }
  }

  void _verUbicacionBombero(Map<String, dynamic> respuesta) async {
    if (respuesta['ubicacion_inicial'] == null) {
      UtilidadMensajes.mostrarError(context,"Sin ubicación registrada");
      return;
    }

    final GeoPoint gp = respuesta['ubicacion_inicial'];
    final Uri url = Uri.parse("geo:${gp.latitude},${gp.longitude}?q=${gp.latitude},${gp.longitude}(${respuesta['nombre']})");

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      UtilidadMensajes.mostrarError(context,"Error al abrir mapa");
    }
  }

  void _confirmarAsistencia() async {
    setState(() => _enviandoRespuesta = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw 'Se requiere ubicación';
      }
      
      Position posicion = await Geolocator.getCurrentPosition();
      final uid = ServicioAuth().usuarioActual?.uid;
      final docUsuario = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
      String nombreReal = docUsuario.data()?['nombre'] ?? (widget.rolUsuario == 'admin' ? "Comandante" : "Bombero");

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
        UtilidadMensajes.mostrarExito(context, " En camino. ¡Conduce con cuidado!");
        
        setState(() { _yaRespondio = true; _enviandoRespuesta = false; });
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _enviandoRespuesta = false);
        UtilidadMensajes.mostrarError(context,"Error: $e");
      }
    }
  }

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
          Navigator.pop(context); 
        }
      } catch (e) {
        setState(() => _enviandoRespuesta = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final LatLng puntoMapa = widget.alerta.ubicacion != null 
        ? LatLng(widget.alerta.ubicacion!.latitude, widget.alerta.ubicacion!.longitude)
        : const LatLng(0.2343, -78.2625);

    final bool esFinalizada = widget.alerta.estado == 'finalizada';
    // Usamos el color de la categoría, o gris si finalizó
    final Color colorTema = esFinalizada ? Colors.grey : widget.alerta.colorCategoria;

    return Scaffold(
      backgroundColor: TemaApp.fondoClaro,
      
      appBar: AppBar(
        title: Text(widget.alerta.tipoId.toUpperCase(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
        backgroundColor: colorTema,
        centerTitle: true,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      
      body: Column(
        children: [
          // --- MAPA ---
          Expanded(
            flex: 4,
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(initialCenter: puntoMapa, initialZoom: 16.0),
                  children: [
                    TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.bomberos.app'),
                    
                    // Capa de Marcadores
                    MarkerLayer(
                      markers: [
                        // A. INCENDIO (Mira Telescópica coherente con Crear Alerta)
                        Marker(
                          point: puntoMapa,
                          width: 80, height: 80,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 80, height: 80,
                                decoration: BoxDecoration(
                                  color: colorTema.withOpacity(0.3),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: colorTema, width: 2),
                                ),
                              ),
                              Container(
                                width: 14, height: 14,
                                decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: colorTema, width: 4)),
                              ),
                              Positioned(
                                top: 10,
                                child: Icon(widget.alerta.iconoCategoria, color: colorTema, size: 24)
                              )
                            ],
                          ),
                        ),

                        // B. BOMBEROS EN CAMINO
                        ...widget.alerta.respuestas.map((r) {
                          if (r['ubicacion_inicial'] == null) return const Marker(point: LatLng(0,0), child: SizedBox());
                          final gp = r['ubicacion_inicial'] as GeoPoint;
                          return Marker(
                            point: LatLng(gp.latitude, gp.longitude),
                            width: 60, height: 60,
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                    boxShadow: const [BoxShadow(blurRadius: 2)]
                                  ),
                                  child: Text(r['nombre']?.split(' ')[0] ?? 'B', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                                const Icon(Icons.directions_car_filled, color: TemaApp.azulInstitucional, size: 28),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ],
                ),
                
                // Botón Flotante (Solo si está activa)
                if (!esFinalizada)
                  Positioned(
                    bottom: 20, right: 15,
                    child: FloatingActionButton.extended(
                      heroTag: "gpsBtn",
                      onPressed: _abrirMapaExterno,
                      backgroundColor: Colors.blueAccent,
                      icon: const Icon(Icons.map, color: Colors.white),
                      label: const Text("NAVEGAR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
          ),

          // --- DETALLE ---
          Expanded(
            flex: 6,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [BoxShadow(blurRadius: 20, color: Colors.black12)],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(25, 30, 25, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Título y Hora
                    Row(
                      children: [
                        Expanded(child: Text(widget.alerta.titulo, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: colorTema))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
                          child: Text(
                            "${widget.alerta.fechaHora.toDate().hour}:${widget.alerta.fechaHora.toDate().minute.toString().padLeft(2,'0')}",
                            style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(widget.alerta.descripcion, style: TextStyle(fontSize: 16, color: Colors.grey.shade700, height: 1.4)),
                    
                    const SizedBox(height: 20),
                    const Divider(),
                    
                    // Lista
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text("Personal respondiendo (${widget.alerta.respuestas.length})", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
                    ),
                    
                    Expanded(
                      child: widget.alerta.respuestas.isEmpty
                        ? Center(child: Text("Esperando respuesta del personal...", style: TextStyle(color: Colors.grey.shade400, fontStyle: FontStyle.italic)))
                        : ListView.builder(
                            itemCount: widget.alerta.respuestas.length,
                            padding: EdgeInsets.zero,
                            itemBuilder: (ctx, i) {
                              final r = widget.alerta.respuestas[i];
                              final Timestamp? ts = r['hora'];
                              final hora = ts != null ? "${ts.toDate().hour}:${ts.toDate().minute.toString().padLeft(2,'0')}" : "--:--";
                              
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(backgroundColor: colorTema.withOpacity(0.1), radius: 18, child: Icon(Icons.person, size: 18, color: colorTema)),
                                title: Text(r['nombre'] ?? 'Bombero', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text("Salida: $hora", style: TextStyle(color: Colors.grey.shade500)),
                                trailing: widget.rolUsuario == 'admin' 
                                    ? IconButton(icon: const Icon(Icons.location_searching, color: Colors.blue), onPressed: () => _verUbicacionBombero(r))
                                    : const Icon(Icons.check_circle, color: Colors.green),
                              );
                            },
                          ),
                    ),

                    // --- ZONA DE ACCIÓN ---
                    const SizedBox(height: 10),
                    if (esFinalizada)
                       Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock, color: Colors.grey),
                            SizedBox(width: 10),
                            Text("CASO CERRADO", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                          ],
                        ),
                       )
                    else if (widget.rolUsuario == 'admin')
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black87,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                          ),
                          onPressed: _enviandoRespuesta ? null : _finalizarEmergencia,
                          icon: _enviandoRespuesta 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                            : const Icon(Icons.stop_circle_outlined, color: Colors.white),
                          label: const Text("FINALIZAR OPERATIVO", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      )
                    else if (widget.rolUsuario == 'bombero')
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _yaRespondio ? Colors.green : colorTema,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                          ),
                          onPressed: (_enviandoRespuesta || _yaRespondio) ? null : _confirmarAsistencia,
                          icon: _enviandoRespuesta 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                            : Icon(_yaRespondio ? Icons.check : Icons.directions_run, color: Colors.white),
                          label: Text(_yaRespondio ? "ASISTENCIA CONFIRMADA" : "VOY EN CAMINO", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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