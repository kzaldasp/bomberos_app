import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

import '../modelos/emergencia_modelo.dart';
import '../servicios/servicio_auth.dart';
import '../servicios/servicio_rastreo.dart';
import '../config/tema_app.dart';
import '../config/utilidad_formato.dart';
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

  // UID del bombero del que se está dibujando la ruta en el mapa
  String? _bomberoRutaActiva;

  final MapController _mapController = MapController();

  // El rastreo GPS vive en ServicioRastreo (singleton): sigue activo aunque
  // el bombero salga de esta pantalla, y se apaga solo al finalizar el caso.

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

  // Abre la ruta en Google Maps desde la posición del bombero hasta la emergencia
  void _verUbicacionBombero(LatLng? posicionBombero) async {
    if (posicionBombero == null || widget.alerta.ubicacion == null) {
      UtilidadMensajes.mostrarError(context, "Faltan coordenadas");
      return;
    }

    final latDestino = widget.alerta.ubicacion!.latitude;
    final lngDestino = widget.alerta.ubicacion!.longitude;

    final Uri url = Uri.parse(
        "https://www.google.com/maps/dir/?api=1&origin=${posicionBombero.latitude},${posicionBombero.longitude}&destination=$latDestino,$lngDestino");

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) UtilidadMensajes.mostrarError(context, "Error al abrir Google Maps");
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

  void _confirmarAsistencia() async {
    final int? tiempoEstimado = await _mostrarDialogoETA();
    if (tiempoEstimado == null) return;

    setState(() => _enviandoRespuesta = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw 'Se requiere el permiso de ubicación';
      }
      if (permission == LocationPermission.deniedForever) {
        throw 'El permiso de ubicación está bloqueado. Actívalo en Ajustes del teléfono.';
      }

      Position posicion = await Geolocator.getCurrentPosition();
      final uid = ServicioAuth().usuarioActual?.uid;
      if (uid == null) throw 'Sesión no válida';

      final docUsuario = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
      final String nombreReal = docUsuario.data()?['nombre'] ?? "Bombero";

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

      // Arranca el rastreo del trayecto (sigue aunque cierre esta pantalla)
      await ServicioRastreo().iniciar(
        emergenciaId: widget.alerta.id,
        bomberoUid: uid,
        nombreBombero: nombreReal,
        posicionInicial: posicion,
      );

      if (mounted) {
        UtilidadMensajes.mostrarExito(context, "GPS activado. Llegada en ~$tiempoEstimado min.");
        setState(() { _yaRespondio = true; _enviandoRespuesta = false; });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _enviandoRespuesta = false);
        UtilidadMensajes.mostrarError(context, "Error: $e");
      }
    }
  }

  void _dejarDeCompartir() async {
    await ServicioRastreo().detener();
    if (mounted) {
      setState(() {});
      UtilidadMensajes.mostrarExito(context, "Dejaste de compartir tu ubicación.");
    }
  }

  /// Retoma el rastreo si el bombero cerró la app a mitad del trayecto.
  void _reanudarRastreo() async {
    try {
      final uid = ServicioAuth().usuarioActual?.uid;
      if (uid == null) return;

      final posicion = await Geolocator.getCurrentPosition();
      final docUsuario = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();

      await ServicioRastreo().iniciar(
        emergenciaId: widget.alerta.id,
        bomberoUid: uid,
        nombreBombero: docUsuario.data()?['nombre'] ?? 'Bombero',
        posicionInicial: posicion,
      );

      if (mounted) {
        setState(() {});
        UtilidadMensajes.mostrarExito(context, "Rastreo GPS reanudado.");
      }
    } catch (e) {
      if (mounted) UtilidadMensajes.mostrarError(context, "No se pudo reanudar el GPS: $e");
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
        // Al pasar a 'finalizada', el ServicioRastreo de cada bombero
        // detecta el cambio y apaga su GPS automáticamente.
        await FirebaseFirestore.instance.collection('emergencias').doc(widget.alerta.id).update({'estado': 'finalizada'});
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) setState(() => _enviandoRespuesta = false);
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

          // Escuchamos los trayectos en vivo (emergencias/{id}/trayectos/{uid})
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('emergencias')
                .doc(widget.alerta.id)
                .collection('trayectos')
                .snapshots(),
            builder: (context, snapTrayectos) {
              // Recorrido completo y última posición conocida de cada bombero
              final Map<String, List<LatLng>> rutasPorBombero = {};
              final Map<String, LatLng> posicionActual = {};

              for (final doc in snapTrayectos.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[]) {
                final puntos = (doc.data()['puntos'] as List<dynamic>? ?? [])
                    .map((p) => LatLng((p['lat'] as num).toDouble(), (p['lng'] as num).toDouble()))
                    .toList();
                if (puntos.isNotEmpty) {
                  rutasPorBombero[doc.id] = puntos;
                  posicionActual[doc.id] = puntos.last;
                }
              }

              // Ruta del bombero seleccionado para dibujar en el mapa
              final List<LatLng> puntosRuta =
                  _bomberoRutaActiva != null ? (rutasPorBombero[_bomberoRutaActiva] ?? []) : [];

              return Column(
            children: [
              // --- MAPA ---
              Expanded(
                flex: 4,
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
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
                                  Container(width: 80, height: 80, decoration: BoxDecoration(color: colorTema.withValues(alpha: 0.3), shape: BoxShape.circle, border: Border.all(color: colorTema, width: 2))),
                                  Container(width: 14, height: 14, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: colorTema, width: 4))),
                                  Positioned(top: 10, child: Icon(widget.alerta.iconoCategoria, color: colorTema, size: 24))
                                ],
                              ),
                            ),
                            ...respuestasEnVivo.map<Marker?>((r) {
                              // Última posición del trayecto; si aún no hay, el punto de partida
                              LatLng? pos = posicionActual[r['bombero_uid']];
                              if (pos == null && r['ubicacion_inicial'] != null) {
                                final gp = r['ubicacion_inicial'] as GeoPoint;
                                pos = LatLng(gp.latitude, gp.longitude);
                              }
                              if (pos == null) return null;
                              return Marker(
                                point: pos,
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
                            }).whereType<Marker>(),
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
                                UtilidadFormato.horaInteligente(widget.alerta.fechaHora.toDate()),
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
                                  final hora = ts != null ? UtilidadFormato.hora(ts.toDate()) : "--:--";
                                  final uidBombero = r['bombero_uid'];
                                  
                                  String infoLlegada = "Salida: $hora";
                                  if (r.containsKey('eta_minutos')) infoLlegada += " • Llega en ~${r['eta_minutos']} min";
                                  
                                  final bool rutaActiva = _bomberoRutaActiva == uidBombero;
                                  
                                  return ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(backgroundColor: colorTema.withValues(alpha: 0.1), radius: 18, child: Icon(Icons.person, size: 18, color: colorTema)),
                                    title: Text(r['nombre'] ?? 'Bombero', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text(infoLlegada, style: TextStyle(color: Colors.grey.shade500)),
                                    
                                    // --- DOS BOTONES PARA EL ADMIN ---
                                    trailing: widget.rolUsuario == Roles.admin
                                        ? Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              // Botón de trazar línea en el mapa interno
                                              IconButton(
                                                icon: Icon(rutaActiva ? Icons.route : Icons.route_outlined, color: rutaActiva ? Colors.orange : Colors.grey),
                                                tooltip: "Ver ruta en mapa",
                                                onPressed: () {
                                                  setState(() {
                                                    _bomberoRutaActiva = rutaActiva ? null : uidBombero;
                                                  });
                                                  // Ajustamos el mapa para que se vea todo el recorrido
                                                  final ruta = rutasPorBombero[uidBombero];
                                                  if (!rutaActiva && ruta != null && ruta.isNotEmpty) {
                                                    _mapController.fitCamera(
                                                      CameraFit.coordinates(
                                                        coordinates: [...ruta, puntoMapa],
                                                        padding: const EdgeInsets.all(60),
                                                      ),
                                                    );
                                                  }
                                                }
                                              ),
                                              // Botón de abrir en Google Maps externo
                                              IconButton(
                                                icon: const Icon(Icons.open_in_new, color: Colors.blue),
                                                tooltip: "Abrir en Google Maps",
                                                onPressed: () {
                                                  LatLng? pos = posicionActual[uidBombero];
                                                  if (pos == null && r['ubicacion_inicial'] != null) {
                                                    final gp = r['ubicacion_inicial'] as GeoPoint;
                                                    pos = LatLng(gp.latitude, gp.longitude);
                                                  }
                                                  _verUbicacionBombero(pos);
                                                },
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
                        else if (widget.rolUsuario == Roles.admin)
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
                        else if (widget.rolUsuario == Roles.bombero)
                          Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                height: 55,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: _yaRespondio ? Colors.green : colorTema, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                                  onPressed: (_enviandoRespuesta || _yaRespondio) ? null : _confirmarAsistencia,
                                  icon: _enviandoRespuesta ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Icon(_yaRespondio ? Icons.check : Icons.directions_run, color: Colors.white),
                                  label: Text(_yaRespondio ? "ASISTENCIA CONFIRMADA" : "VOY EN CAMINO", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                ),
                              ),
                              // Si está compartiendo: botón para detener.
                              // Si respondió pero el GPS se apagó (cerró la app): botón para reanudar.
                              if (_yaRespondio && ServicioRastreo().emergenciaActiva == widget.alerta.id)
                                TextButton.icon(
                                  onPressed: _dejarDeCompartir,
                                  icon: const Icon(Icons.location_off_outlined, size: 18, color: Colors.grey),
                                  label: const Text("Dejar de compartir mi ubicación", style: TextStyle(color: Colors.grey, fontSize: 13)),
                                )
                              else if (_yaRespondio)
                                TextButton.icon(
                                  onPressed: _reanudarRastreo,
                                  icon: const Icon(Icons.my_location_rounded, size: 18, color: Colors.blueAccent),
                                  label: const Text("Reanudar rastreo GPS", style: TextStyle(color: Colors.blueAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          )
                      ],
                    ),
                  ),
                ),
              ),
            ],
              );
            },
          );
        }
      ),
    );
  }
}