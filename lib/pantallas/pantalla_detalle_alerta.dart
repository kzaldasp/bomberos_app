import 'dart:async'; 
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'package:geolocator/geolocator.dart';

import '../modelos/emergencia_modelo.dart';
import '../servicios/servicio_auth.dart';
import '../config/tema_app.dart';
import '../config/utilidad_mensajes.dart'; 

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
  
  StreamSubscription<Position>? _rastreoGps;
  
  // --- NUEVO: Variable para saber de qué bombero estamos dibujando la ruta ---
  String? _bomberoRutaActiva;

  @override
  void initState() {
    super.initState();
    _verificarSiYaRespondio();
  }

  @override
  void dispose() {
    _rastreoGps?.cancel();
    super.dispose();
  }

  void _verificarSiYaRespondio() {
    final miUid = ServicioAuth().usuarioActual?.uid;
    if (miUid != null) {
      final yaEsta = widget.alerta.respuestas.any((r) => r['bombero_uid'] == miUid);
      if (mounted) {
        setState(() => _yaRespondio = yaEsta);
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
        throw 'Error';
      }
    } catch (e) {
      if (mounted) UtilidadMensajes.mostrarError(context,"No tienes una app de mapas instalada");
    }
  }

  // Ahora esta función abre la ruta en Google Maps usando Origin y Destination
  void _verUbicacionBombero(Map<String, dynamic> respuesta) async {
    if (respuesta['ubicacion_inicial'] == null || widget.alerta.ubicacion == null) {
      UtilidadMensajes.mostrarError(context,"Faltan coordenadas");
      return;
    }
    
    final GeoPoint gpOrigen = respuesta['ubicacion_inicial'];
    final latDestino = widget.alerta.ubicacion!.latitude;
    final lngDestino = widget.alerta.ubicacion!.longitude;
    
    // Abre Google Maps en modo navegación desde el bombero hasta la emergencia
    final Uri url = Uri.parse("https://www.google.com/maps/dir/?api=1&origin=${gpOrigen.latitude},${gpOrigen.longitude}&destination=$latDestino,$lngDestino");

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) UtilidadMensajes.mostrarError(context,"Error al abrir Google Maps");
    }
  }

  Future<int?> _mostrarDialogoETA() async {
    return showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Tiempo de Llegada", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("¿En cuánto tiempo aproximado llegarás a la zona de la emergencia?", textAlign: TextAlign.center),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  ActionChip(label: const Text("5 min"), backgroundColor: Colors.green.shade100, onPressed: () => Navigator.pop(context, 5)),
                  ActionChip(label: const Text("10 min"), backgroundColor: Colors.orange.shade100, onPressed: () => Navigator.pop(context, 10)),
                  ActionChip(label: const Text("15 min"), backgroundColor: Colors.red.shade100, onPressed: () => Navigator.pop(context, 15)),
                  ActionChip(label: const Text("20+ min"), backgroundColor: Colors.grey.shade200, onPressed: () => Navigator.pop(context, 20)),
                ],
              )
            ],
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context, null), child: const Text("Cancelar", style: TextStyle(color: Colors.red)))],
        );
      }
    );
  }

  void _iniciarRastreoGps() {
    const LocationSettings ajustesGps = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 15, 
    );

    _rastreoGps = Geolocator.getPositionStream(locationSettings: ajustesGps).listen((Position position) async {
      try {
        final docRef = FirebaseFirestore.instance.collection('emergencias').doc(widget.alerta.id);
        final doc = await docRef.get();
        if (!doc.exists) return;

        List<dynamic> respuestas = doc.data()?['respuestas'] ?? [];
        final miUid = ServicioAuth().usuarioActual?.uid;

        for (var i = 0; i < respuestas.length; i++) {
          if (respuestas[i]['bombero_uid'] == miUid) {
            respuestas[i]['ubicacion_inicial'] = GeoPoint(position.latitude, position.longitude);
            break;
          }
        }
        await docRef.update({'respuestas': respuestas});
      } catch (e) {
        print("Error en tracking GPS: $e");
      }
    });
  }

  void _confirmarAsistencia() async {
    final int? tiempoEstimado = await _mostrarDialogoETA();
    if (tiempoEstimado == null) return; 

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
      
      Map<String, dynamic>? userData = docUsuario.data();
      String nombreReal = userData != null && userData.containsKey('nombre') ? userData['nombre'] : "Bombero";

      final respuesta = {
        "bombero_uid": uid,
        "nombre": nombreReal,
        "hora": Timestamp.now(),
        "ubicacion_inicial": GeoPoint(posicion.latitude, posicion.longitude),
        "eta_minutos": tiempoEstimado, 
      };

      await FirebaseFirestore.instance.collection('emergencias').doc(widget.alerta.id).update({
        "respuestas": FieldValue.arrayUnion([respuesta])
      });

      if (mounted) {
        UtilidadMensajes.mostrarExito(context, "GPS Activado. Llegada en ~$tiempoEstimado min.");
        setState(() { _yaRespondio = true; _enviandoRespuesta = false; });
        _iniciarRastreoGps();
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
        content: const Text("La emergencia pasará al historial y se apagará el GPS de todos."),
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
        await FirebaseFirestore.instance.collection('emergencias').doc(widget.alerta.id).update({'estado': 'finalizada'});
        _rastreoGps?.cancel(); 
        if (mounted) Navigator.pop(context); 
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

    return Scaffold(
      backgroundColor: TemaApp.fondoClaro,
      appBar: AppBar(
        title: Text(widget.alerta.tipoId.toUpperCase(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
        backgroundColor: widget.alerta.colorCategoria,
        centerTitle: true,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('emergencias').doc(widget.alerta.id).snapshots(),
        builder: (context, snapshot) {
          
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data == null) return const Center(child: Text("Datos no encontrados"));

          final List<dynamic> respuestasEnVivo = data['respuestas'] ?? [];
          final bool esFinalizada = data['estado'] == 'finalizada';
          final Color colorTema = esFinalizada ? Colors.grey : widget.alerta.colorCategoria;

          // Extraemos las coordenadas del bombero seleccionado para trazar la línea
          List<LatLng> puntosRuta = [];
          if (_bomberoRutaActiva != null) {
            try {
              final bombero = respuestasEnVivo.firstWhere((r) => r['bombero_uid'] == _bomberoRutaActiva);
              if (bombero['ubicacion_inicial'] != null) {
                final gp = bombero['ubicacion_inicial'] as GeoPoint;
                puntosRuta = [LatLng(gp.latitude, gp.longitude), puntoMapa];
              }
            } catch (e) {
              // Bombero no encontrado en la lista
            }
          }

          return Column(
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
                        
                        // --- NUEVO: CAPA DE RUTAS (POLYLINES) ---
                        PolylineLayer(
                          polylines: [
                            if (puntosRuta.isNotEmpty)
                              Polyline(
                                points: puntosRuta,
                                strokeWidth: 4.0,
                                color: Colors.blueAccent,
                              ),
                          ],
                        ),

                        MarkerLayer(
                          markers: [
                            Marker(
                              point: puntoMapa,
                              width: 80, height: 80,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(width: 80, height: 80, decoration: BoxDecoration(color: colorTema.withOpacity(0.3), shape: BoxShape.circle, border: Border.all(color: colorTema, width: 2))),
                                  Container(width: 14, height: 14, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: colorTema, width: 4))),
                                  Positioned(top: 10, child: Icon(widget.alerta.iconoCategoria, color: colorTema, size: 24))
                                ],
                              ),
                            ),
                            ...respuestasEnVivo.map((r) {
                              if (r['ubicacion_inicial'] == null) return const Marker(point: LatLng(0,0), child: SizedBox());
                              final gp = r['ubicacion_inicial'] as GeoPoint;
                              return Marker(
                                point: LatLng(gp.latitude, gp.longitude),
                                width: 60, height: 60,
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), boxShadow: const [BoxShadow(blurRadius: 2)]),
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
                        
                        if (widget.alerta.urlAdjunto != null && widget.alerta.urlAdjunto!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 15),
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final url = Uri.parse(widget.alerta.urlAdjunto!);
                                bool lanzado = await launchUrl(url, mode: LaunchMode.externalApplication);
                                if (!lanzado && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No se pudo abrir el archivo.")));
                                }
                              },
                              icon: const Icon(Icons.attach_file),
                              label: const Text("VER ARCHIVO ADJUNTO / CROQUIS"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueGrey.shade50,
                                foregroundColor: Colors.blueGrey.shade800,
                                elevation: 0,
                                side: BorderSide(color: Colors.blueGrey.shade200),
                                minimumSize: const Size(double.infinity, 45),
                              ),
                            ),
                          ),

                        const SizedBox(height: 15),
                        const Divider(),
                        
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text("Personal respondiendo (${respuestasEnVivo.length})", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
                        ),
                        
                        Expanded(
                          child: respuestasEnVivo.isEmpty
                            ? Center(child: Text("Esperando respuesta del personal...", style: TextStyle(color: Colors.grey.shade400, fontStyle: FontStyle.italic)))
                            : ListView.builder(
                                itemCount: respuestasEnVivo.length,
                                padding: EdgeInsets.zero,
                                itemBuilder: (ctx, i) {
                                  final r = respuestasEnVivo[i];
                                  final Timestamp? ts = r['hora'];
                                  final hora = ts != null ? "${ts.toDate().hour}:${ts.toDate().minute.toString().padLeft(2,'0')}" : "--:--";
                                  final uidBombero = r['bombero_uid'];
                                  
                                  String infoLlegada = "Salida: $hora";
                                  if (r.containsKey('eta_minutos')) infoLlegada += " • Llega en ~${r['eta_minutos']} min";
                                  
                                  final bool rutaActiva = _bomberoRutaActiva == uidBombero;
                                  
                                  return ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(backgroundColor: colorTema.withOpacity(0.1), radius: 18, child: Icon(Icons.person, size: 18, color: colorTema)),
                                    title: Text(r['nombre'] ?? 'Bombero', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text(infoLlegada, style: TextStyle(color: Colors.grey.shade500)),
                                    
                                    // --- NUEVO: DOS BOTONES PARA EL ADMIN ---
                                    trailing: widget.rolUsuario == 'admin' 
                                        ? Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              // Botón de trazar línea en el mapa interno
                                              IconButton(
                                                icon: Icon(rutaActiva ? Icons.route : Icons.route_outlined, color: rutaActiva ? Colors.orange : Colors.grey), 
                                                tooltip: "Ver ruta en mapa",
                                                onPressed: () {
                                                  setState(() {
                                                    if (rutaActiva) {
                                                      _bomberoRutaActiva = null; // Apaga la línea si ya estaba activa
                                                    } else {
                                                      _bomberoRutaActiva = uidBombero; // Dibuja la línea para este bombero
                                                    }
                                                  });
                                                }
                                              ),
                                              // Botón de abrir en Google Maps externo
                                              IconButton(
                                                icon: const Icon(Icons.open_in_new, color: Colors.blue), 
                                                tooltip: "Abrir en Google Maps",
                                                onPressed: () => _verUbicacionBombero(r as Map<String, dynamic>)
                                              ),
                                            ],
                                          )
                                        : const Icon(Icons.check_circle, color: Colors.green),
                                  );
                                },
                              ),
                        ),

                        const SizedBox(height: 10),
                        if (esFinalizada)
                           Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
                            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.lock, color: Colors.grey), SizedBox(width: 10), Text("CASO CERRADO", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.5))]),
                           )
                        else if (widget.rolUsuario == 'admin')
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.black87, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                              onPressed: _enviandoRespuesta ? null : _finalizarEmergencia,
                              icon: _enviandoRespuesta ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.stop_circle_outlined, color: Colors.white),
                              label: const Text("FINALIZAR OPERATIVO", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          )
                        else if (widget.rolUsuario == 'bombero')
                          SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: _yaRespondio ? Colors.green : colorTema, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                              onPressed: (_enviandoRespuesta || _yaRespondio) ? null : _confirmarAsistencia,
                              icon: _enviandoRespuesta ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Icon(_yaRespondio ? Icons.check : Icons.directions_run, color: Colors.white),
                              label: Text(_yaRespondio ? "ASISTENCIA CONFIRMADA" : "VOY EN CAMINO", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          )
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        }
      ),
    );
  }
}