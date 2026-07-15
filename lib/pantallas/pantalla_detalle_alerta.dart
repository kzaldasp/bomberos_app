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

  // Evita repetir la limpieza de trayectos huérfanos en cada rebuild
  bool _limpiezaResidualHecha = false;

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
      if (mounted) UtilidadMensajes.mostrarError(context, "No tienes una app de mapas instalada");
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
          title: const Text("Tiempo de llegada", textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "¿En cuánto tiempo aproximado llegarás a la zona de la emergencia?",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  _ChipETA(texto: "5 min", onTap: () => Navigator.pop(context, 5)),
                  _ChipETA(texto: "10 min", onTap: () => Navigator.pop(context, 10)),
                  _ChipETA(texto: "15 min", onTap: () => Navigator.pop(context, 15)),
                  _ChipETA(texto: "20+ min", onTap: () => Navigator.pop(context, 20)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text("Cancelar", style: TextStyle(color: TemaApp.textoSecundario)),
            ),
          ],
        );
      },
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
        destino: widget.alerta.ubicacion,
      );

      if (mounted) {
        UtilidadMensajes.mostrarExito(context, "GPS activado. Llegada en ~$tiempoEstimado min.");
        setState(() {
          _yaRespondio = true;
          _enviandoRespuesta = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _enviandoRespuesta = false);
        UtilidadMensajes.mostrarError(context, "Error: $e");
      }
    }
  }

  void _dejarDeCompartir() async {
    // El bombero canceló: su ruta parcial ya no sirve, se borra de Firestore.
    await ServicioRastreo().detener(borrarTrayecto: true);
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
        destino: widget.alerta.ubicacion,
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
        title: const Text("¿Cerrar operativo?"),
        content: const Text("La emergencia pasará al historial y se apagará el GPS de todos."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancelar", style: TextStyle(color: TemaApp.textoSecundario)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: TemaApp.negro),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("FINALIZAR"),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      setState(() => _enviandoRespuesta = true);
      try {
        // Al pasar a 'finalizada', el ServicioRastreo de cada bombero
        // detecta el cambio y apaga su GPS automáticamente.
        await FirebaseFirestore.instance
            .collection('emergencias')
            .doc(widget.alerta.id)
            .update({'estado': 'finalizada'});

        // Los trayectos ya cumplieron su función: se borran para no
        // acumular datos viejos. Cubre también a bomberos que nunca
        // llegaron o cuya app murió a mitad del camino.
        await _borrarTodosLosTrayectos();

        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) setState(() => _enviandoRespuesta = false);
      }
    }
  }

  /// Borra todos los documentos de `emergencias/{id}/trayectos` en un batch.
  /// No lanza excepción: si algo falla (p. ej. un bombero escribió justo en
  /// ese instante), la limpieza residual lo recoge la próxima vez que un
  /// admin abra esta emergencia desde el historial.
  Future<void> _borrarTodosLosTrayectos() async {
    try {
      final trayectos = await FirebaseFirestore.instance
          .collection('emergencias')
          .doc(widget.alerta.id)
          .collection('trayectos')
          .get();
      if (trayectos.docs.isEmpty) return;

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in trayectos.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('No se pudieron borrar los trayectos: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final LatLng puntoMapa = widget.alerta.ubicacion != null
        ? LatLng(widget.alerta.ubicacion!.latitude, widget.alerta.ubicacion!.longitude)
        : const LatLng(0.3005, -78.2646);

    return Scaffold(
      backgroundColor: TemaApp.fondo,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.alerta.iconoCategoria, size: 18, color: widget.alerta.colorCategoria),
            const SizedBox(width: 8),
            Flexible(
              child: Text(widget.alerta.tipoId.toUpperCase(), overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('emergencias').doc(widget.alerta.id).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data == null) return const Center(child: Text("Datos no encontrados"));

          final List<dynamic> respuestasEnVivo = data['respuestas'] ?? [];
          final bool esFinalizada = data['estado'] == 'finalizada';
          final Color colorTema = esFinalizada ? TemaApp.textoTerciario : widget.alerta.colorCategoria;

          // Escuchamos los trayectos en vivo (emergencias/{id}/trayectos/{uid})
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('emergencias')
                .doc(widget.alerta.id)
                .collection('trayectos')
                .snapshots(),
            builder: (context, snapTrayectos) {
              final docsTrayectos =
                  snapTrayectos.data?.docs ?? <QueryDocumentSnapshot<Map<String, dynamic>>>[];

              // Trayectos huérfanos: la emergencia ya se cerró pero quedaron
              // documentos (p. ej. el admin que finalizó perdió conexión antes
              // de borrarlos). El primer admin que la abra los limpia.
              if (esFinalizada &&
                  widget.rolUsuario == Roles.admin &&
                  !_limpiezaResidualHecha &&
                  docsTrayectos.isNotEmpty) {
                _limpiezaResidualHecha = true;
                _borrarTodosLosTrayectos();
              }

              // Recorrido completo y última posición conocida de cada bombero
              final Map<String, List<LatLng>> rutasPorBombero = {};
              final Map<String, LatLng> posicionActual = {};
              final Set<String> bomberosEnElLugar = {};
              // Minutos sin actualizar el GPS (app muerta, sin cobertura...):
              // la central debe saber que ese marcador NO está avanzando.
              final Map<String, int> minutosSinSenal = {};

              for (final doc in docsTrayectos) {
                final datos = doc.data();

                // Ya llegó: su documento está compactado (sin puntos),
                // solo trae la marca de llegada y la última posición.
                if (datos['estado'] == 'llegado') {
                  bomberosEnElLugar.add(doc.id);
                  final ultimo = datos['ultimo'];
                  if (ultimo is Map) {
                    posicionActual[doc.id] = LatLng(
                      (ultimo['lat'] as num).toDouble(),
                      (ultimo['lng'] as num).toDouble(),
                    );
                  }
                  continue;
                }

                final puntos = (datos['puntos'] as List<dynamic>? ?? [])
                    .map((p) => LatLng((p['lat'] as num).toDouble(), (p['lng'] as num).toDouble()))
                    .toList();
                if (puntos.isNotEmpty) {
                  rutasPorBombero[doc.id] = puntos;
                  posicionActual[doc.id] = puntos.last;
                }

                if (!esFinalizada) {
                  final Timestamp? actualizado = datos['actualizado'] as Timestamp?;
                  if (actualizado != null) {
                    final minutos =
                        DateTime.now().difference(actualizado.toDate()).inMinutes;
                    if (minutos >= 5) minutosSinSenal[doc.id] = minutos;
                  }
                }
              }

              // Ruta del bombero seleccionado para dibujar en el mapa
              final List<LatLng> puntosRuta =
                  _bomberoRutaActiva != null ? (rutasPorBombero[_bomberoRutaActiva] ?? []) : [];

              return Column(
                children: [
                  // ---- MAPA ----
                  Expanded(
                    flex: 4,
                    child: Stack(
                      children: [
                        FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(initialCenter: puntoMapa, initialZoom: 16.0),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.bomberos.app',
                            ),
                            PolylineLayer(
                              polylines: [
                                if (puntosRuta.isNotEmpty)
                                  Polyline(
                                    points: puntosRuta,
                                    strokeWidth: 4.0,
                                    color: TemaApp.negro,
                                  ),
                              ],
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
                                      Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          color: colorTema.withValues(alpha: 0.25),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: colorTema, width: 2),
                                        ),
                                      ),
                                      Container(
                                        width: 14,
                                        height: 14,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: colorTema, width: 4),
                                        ),
                                      ),
                                      Positioned(
                                        top: 10,
                                        child: Icon(widget.alerta.iconoCategoria, color: colorTema, size: 24),
                                      ),
                                    ],
                                  ),
                                ),
                                ...respuestasEnVivo.map<Marker?>((r) {
                                  // Última posición del trayecto; si aún no hay, el punto de partida
                                  final bool llego = bomberosEnElLugar.contains(r['bombero_uid']);
                                  final bool sinSenal = minutosSinSenal.containsKey(r['bombero_uid']);
                                  LatLng? pos = posicionActual[r['bombero_uid']];
                                  if (pos == null && r['ubicacion_inicial'] != null) {
                                    final gp = r['ubicacion_inicial'] as GeoPoint;
                                    pos = LatLng(gp.latitude, gp.longitude);
                                  }
                                  if (pos == null) return null;

                                  // Verde: llegó. Gris: sin señal (dato viejo). Negro: en camino.
                                  final Color colorMarcador = llego
                                      ? TemaApp.exito
                                      : (sinSenal ? TemaApp.textoTerciario : TemaApp.negro);

                                  return Marker(
                                    point: pos,
                                    width: 60,
                                    height: 60,
                                    child: Column(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: colorMarcador,
                                            borderRadius: BorderRadius.circular(5),
                                          ),
                                          child: Text(
                                            r['nombre']?.split(' ')[0] ?? 'B',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          llego
                                              ? Icons.where_to_vote_rounded
                                              : (sinSenal
                                                  ? Icons.location_disabled_rounded
                                                  : Icons.directions_car_filled),
                                          color: colorMarcador,
                                          size: 26,
                                        ),
                                      ],
                                    ),
                                  );
                                }).whereType<Marker>(),
                              ],
                            ),
                            // Requisito de la política de uso de los tiles de OSM
                            const SimpleAttributionWidget(
                              source: Text("© OpenStreetMap contributors", style: TextStyle(fontSize: 10)),
                            ),
                          ],
                        ),
                        if (!esFinalizada)
                          Positioned(
                            bottom: 20,
                            right: 15,
                            child: FloatingActionButton.extended(
                              heroTag: "gpsBtn",
                              onPressed: _abrirMapaExterno,
                              backgroundColor: TemaApp.negro,
                              icon: const Icon(Icons.navigation_rounded, color: Colors.white, size: 20),
                              label: const Text(
                                "NAVEGAR",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 0.6),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // ---- PANEL DE DETALLE ----
                  Expanded(
                    flex: 6,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: TemaApp.superficie,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                        border: Border(top: BorderSide(color: TemaApp.borde)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    widget.alerta.titulo,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: TemaApp.negro,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: TemaApp.relleno,
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: Text(
                                    UtilidadFormato.horaInteligente(widget.alerta.fechaHora.toDate()),
                                    style: const TextStyle(
                                      color: TemaApp.textoSecundario,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.alerta.descripcion,
                              style: const TextStyle(
                                fontSize: 14.5,
                                color: TemaApp.textoSecundario,
                                height: 1.5,
                              ),
                            ),

                            if (widget.alerta.urlAdjunto != null && widget.alerta.urlAdjunto!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 14),
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final url = Uri.parse(widget.alerta.urlAdjunto!);
                                    bool lanzado = await launchUrl(url, mode: LaunchMode.externalApplication);
                                    if (!lanzado && context.mounted) {
                                      UtilidadMensajes.mostrarError(context, "No se pudo abrir el archivo.");
                                    }
                                  },
                                  icon: const Icon(Icons.attach_file_rounded, size: 18),
                                  label: const Text("Ver archivo adjunto / croquis"),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(double.infinity, 46),
                                  ),
                                ),
                              ),

                            const SizedBox(height: 16),
                            const Divider(),

                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                "PERSONAL RESPONDIENDO (${respuestasEnVivo.length})",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: TemaApp.textoTerciario,
                                  fontSize: 10.5,
                                  letterSpacing: 1.4,
                                ),
                              ),
                            ),

                            Expanded(
                              child: respuestasEnVivo.isEmpty
                                  ? const Center(
                                      child: Text(
                                        "Esperando respuesta del personal...",
                                        style: TextStyle(color: TemaApp.textoTerciario, fontSize: 13),
                                      ),
                                    )
                                  : ListView.builder(
                                      itemCount: respuestasEnVivo.length,
                                      padding: EdgeInsets.zero,
                                      itemBuilder: (ctx, i) {
                                        final r = respuestasEnVivo[i];
                                        final Timestamp? ts = r['hora'];
                                        final hora = ts != null ? UtilidadFormato.hora(ts.toDate()) : "--:--";
                                        final uidBombero = r['bombero_uid'];

                                        String infoLlegada = "Salida: $hora";
                                        if (bomberosEnElLugar.contains(uidBombero)) {
                                          infoLlegada = "Salida: $hora • En el lugar ✓";
                                        } else if (minutosSinSenal.containsKey(uidBombero)) {
                                          infoLlegada =
                                              "Salida: $hora • Sin señal GPS hace ${minutosSinSenal[uidBombero]} min";
                                        } else if (r.containsKey('eta_minutos')) {
                                          infoLlegada += " • Llega en ~${r['eta_minutos']} min";
                                        }

                                        final bool rutaActiva = _bomberoRutaActiva == uidBombero;

                                        return ListTile(
                                          dense: true,
                                          contentPadding: EdgeInsets.zero,
                                          leading: CircleAvatar(
                                            backgroundColor: colorTema.withValues(alpha: 0.1),
                                            radius: 18,
                                            child: Icon(Icons.person_rounded, size: 18, color: colorTema),
                                          ),
                                          title: Text(
                                            r['nombre'] ?? 'Bombero',
                                            style: const TextStyle(fontWeight: FontWeight.w700, color: TemaApp.negro),
                                          ),
                                          subtitle: Text(
                                            infoLlegada,
                                            style: const TextStyle(color: TemaApp.textoSecundario, fontSize: 12),
                                          ),

                                          // --- DOS BOTONES PARA EL ADMIN ---
                                          trailing: widget.rolUsuario == Roles.admin
                                              ? Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    // Botón de trazar línea en el mapa interno
                                                    IconButton(
                                                      icon: Icon(
                                                        rutaActiva ? Icons.route_rounded : Icons.route_outlined,
                                                        color: rutaActiva ? TemaApp.rojo : TemaApp.textoTerciario,
                                                      ),
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
                                                      },
                                                    ),
                                                    // Botón de abrir en Google Maps externo
                                                    IconButton(
                                                      icon: const Icon(Icons.open_in_new_rounded, color: TemaApp.negro),
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
                                              : const Icon(Icons.check_circle_rounded, color: TemaApp.exito),
                                        );
                                      },
                                    ),
                            ),

                            const SizedBox(height: 10),
                            if (esFinalizada)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: TemaApp.relleno,
                                  borderRadius: BorderRadius.circular(TemaApp.radio),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.lock_rounded, color: TemaApp.textoSecundario, size: 18),
                                    SizedBox(width: 10),
                                    Text(
                                      "CASO CERRADO",
                                      style: TextStyle(
                                        color: TemaApp.textoSecundario,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.4,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else if (widget.rolUsuario == Roles.admin)
                              SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: TemaApp.negro),
                                  onPressed: _enviandoRespuesta ? null : _finalizarEmergencia,
                                  icon: _enviandoRespuesta
                                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                      : const Icon(Icons.stop_circle_outlined),
                                  label: const Text("FINALIZAR OPERATIVO"),
                                ),
                              )
                            else if (widget.rolUsuario == Roles.bombero)
                              Column(
                                children: [
                                  SizedBox(
                                    width: double.infinity,
                                    height: 54,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _yaRespondio ? TemaApp.exito : TemaApp.rojo,
                                        disabledBackgroundColor: _yaRespondio
                                            ? TemaApp.exito.withValues(alpha: 0.85)
                                            : TemaApp.rojo.withValues(alpha: 0.35),
                                      ),
                                      onPressed: (_enviandoRespuesta || _yaRespondio) ? null : _confirmarAsistencia,
                                      icon: _enviandoRespuesta
                                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                          : Icon(_yaRespondio ? Icons.check_rounded : Icons.directions_run_rounded),
                                      label: Text(_yaRespondio ? "ASISTENCIA CONFIRMADA" : "VOY EN CAMINO"),
                                    ),
                                  ),
                                  // Si ya llegó al lugar: el GPS se apagó solo, no hay nada que reanudar.
                                  // Si está compartiendo: botón para detener.
                                  // Si respondió pero el GPS se apagó (cerró la app): botón para reanudar.
                                  if (_yaRespondio &&
                                      bomberosEnElLugar.contains(ServicioAuth().usuarioActual?.uid))
                                    const Padding(
                                      padding: EdgeInsets.only(top: 8),
                                      child: Text(
                                        "Llegaste al lugar de la emergencia ✓",
                                        style: TextStyle(
                                          color: TemaApp.exito,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    )
                                  else if (_yaRespondio && ServicioRastreo().emergenciaActiva == widget.alerta.id)
                                    TextButton.icon(
                                      onPressed: _dejarDeCompartir,
                                      icon: const Icon(Icons.location_off_outlined, size: 17, color: TemaApp.textoSecundario),
                                      label: const Text(
                                        "Dejar de compartir mi ubicación",
                                        style: TextStyle(color: TemaApp.textoSecundario, fontSize: 13),
                                      ),
                                    )
                                  else if (_yaRespondio)
                                    TextButton.icon(
                                      onPressed: _reanudarRastreo,
                                      icon: const Icon(Icons.my_location_rounded, size: 17, color: TemaApp.rojo),
                                      label: const Text(
                                        "Reanudar rastreo GPS",
                                        style: TextStyle(color: TemaApp.rojo, fontSize: 13, fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// Chip minimalista para elegir el tiempo estimado de llegada.
class _ChipETA extends StatelessWidget {
  final String texto;
  final VoidCallback onTap;

  const _ChipETA({required this.texto, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(
        texto,
        style: const TextStyle(fontWeight: FontWeight.w700, color: TemaApp.negro, fontSize: 13),
      ),
      backgroundColor: TemaApp.relleno,
      side: const BorderSide(color: TemaApp.borde),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onPressed: onTap,
    );
  }
}
