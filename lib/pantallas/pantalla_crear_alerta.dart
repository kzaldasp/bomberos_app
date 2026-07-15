import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../servicios/servicio_auth.dart';
import '../modelos/categoria_modelo.dart';
import '../config/tema_app.dart';
import '../config/utilidad_mensajes.dart';
import '../servicios/servicio_almacenamiento.dart';
import '../servicios/servicio_notificaciones.dart';

class PantallaCrearAlerta extends StatefulWidget {
  final CategoriaModelo categoria;

  const PantallaCrearAlerta({super.key, required this.categoria});

  @override
  State<PantallaCrearAlerta> createState() => _PantallaCrearAlertaState();
}

class _PantallaCrearAlertaState extends State<PantallaCrearAlerta> {
  // Coordenadas iniciales (Cotacachi)
  LatLng _ubicacionSeleccionada = const LatLng(0.3005, -78.2646);
  late final TextEditingController _descController;

  bool _guardando = false;

  // Archivo adjunto (Cloudinary)
  File? _archivoAdjunto;
  final ServicioAlmacenamiento _servicioAlmacenamiento = ServicioAlmacenamiento();

  // --- LÓGICA DE DESTINATARIOS ---
  bool _enviarATodos = true; // Por defecto envía a todo el personal
  final List<String> _usuariosSeleccionados = [];

  // Nómina cargada UNA sola vez por pantalla (no cambia mientras eliges):
  // un get() puntual en vez de dejar un stream vivo sobre toda la colección.
  Future<QuerySnapshot>? _futuroUsuarios;

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

  String _colorToHex(Color color) {
    final rgb = color.toARGB32() & 0xFFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  // Abre el modal de selección múltiple
  void _abrirSelectorUsuarios() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Para que ocupe buen espacio si hay muchos bomberos
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.6,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                children: [
                  // Asa del modal
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: TemaApp.borde,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Seleccionar personal",
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: TemaApp.negro),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${_usuariosSeleccionados.length} bomberos seleccionados",
                    style: const TextStyle(color: TemaApp.textoSecundario, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  const Divider(),

                  // Lista de Firebase
                  Expanded(
                    child: FutureBuilder<QuerySnapshot>(
                      future: _futuroUsuarios ??=
                          FirebaseFirestore.instance.collection('usuarios').get(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                        final usuarios = snapshot.data!.docs;

                        return ListView.builder(
                          itemCount: usuarios.length,
                          itemBuilder: (context, index) {
                            var user = usuarios[index];
                            String userId = user.id;

                            Map<String, dynamic> userData = user.data() as Map<String, dynamic>;
                            String nombreUser = userData['nombre'] ?? 'Usuario Desconocido';
                            String rangoUser = userData['rol'] ?? 'Operativo';

                            return CheckboxListTile(
                              title: Text(nombreUser, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                              subtitle: Text(rangoUser, style: const TextStyle(fontSize: 12, color: TemaApp.textoSecundario)),
                              value: _usuariosSeleccionados.contains(userId),
                              activeColor: TemaApp.rojo,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              onChanged: (bool? seleccionado) {
                                setModalState(() {
                                  if (seleccionado == true) {
                                    _usuariosSeleccionados.add(userId);
                                  } else {
                                    _usuariosSeleccionados.remove(userId);
                                  }
                                });
                                setState(() {}); // Refresca la pantalla trasera
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 12),
                  // Botón de confirmar selección
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_usuariosSeleccionados.isEmpty) {
                          // Si desmarcó a todos y aceptó, regresamos al modo "Todos" automáticamente
                          setState(() => _enviarATodos = true);
                        }
                        Navigator.pop(context);
                      },
                      child: const Text("CONFIRMAR LISTA"),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _publicarAlerta() async {
    if (_guardando) return;

    // Validación lógica: Si eligió "Selectivo" pero no escogió a nadie
    if (!_enviarATodos && _usuariosSeleccionados.isEmpty) {
      UtilidadMensajes.mostrarError(context, "Debes seleccionar al menos a un bombero, o cambiar a 'Todo el personal'.");
      return;
    }

    setState(() => _guardando = true);

    try {
      String? urlSubida;
      if (_archivoAdjunto != null) {
        urlSubida = await _servicioAlmacenamiento.subirArchivoAdjunto(_archivoAdjunto!);
      }

      final String colorString = _colorToHex(widget.categoria.color);
      final String iconoString = widget.categoria.nombreIcono;

      // Determinamos la lista final (Si es a todos, la lista va vacía)
      final List<String> listaFinalDestinos = _enviarATodos ? [] : _usuariosSeleccionados;

      final alerta = {
        "titulo": widget.categoria.nombre,
        "descripcion": _descController.text.trim().isEmpty ? "Sin detalles adicionales" : _descController.text.trim(),
        "fecha_hora": FieldValue.serverTimestamp(),
        "estado": "activa",
        "creado_por_uid": ServicioAuth().usuarioActual?.uid,
        "ubicacion": GeoPoint(_ubicacionSeleccionada.latitude, _ubicacionSeleccionada.longitude),
        "respuestas": [],
        "url_adjunto": urlSubida,
        "destinatarios": listaFinalDestinos, // Guardamos la lista depurada
        "tipo_id": widget.categoria.id,
        "nombre": widget.categoria.nombre,
        "importancia": widget.categoria.importancia,
        "color": colorString,
        "icono": iconoString,
      };

      await FirebaseFirestore.instance.collection('emergencias').add(alerta);

      // Enviar Notificación Selectiva (a todos = solo personal de guardia)
      await ServicioNotificaciones().enviarNotificacionSelectiva(
        uidsDestinatarios: listaFinalDestinos,
        titulo: "🚨 EMERGENCIA: ${widget.categoria.nombre.toUpperCase()}",
        cuerpo: _descController.text.trim().isEmpty ? "Se requiere asistencia inmediata en el lugar." : _descController.text.trim(),
        urlImagen: urlSubida,
        soloDeGuardia: true,
      );

      if (mounted) {
        // El mensaje va antes de los pop: el ScaffoldMessenger es global y
        // sobrevive a la navegación, pero el context de esta pantalla no.
        UtilidadMensajes.mostrarPersonalizado(context, "¡ALERTA ENVIADA!", widget.categoria.color, Icons.campaign_rounded);
        Navigator.pop(context);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        UtilidadMensajes.mostrarError(context, "No se pudo enviar: $e");
        setState(() => _guardando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorCat = widget.categoria.color;

    return Scaffold(
      backgroundColor: TemaApp.fondo,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.categoria.icono, size: 18, color: colorCat),
            const SizedBox(width: 8),
            Flexible(child: Text(widget.categoria.nombre, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
      body: Column(
        children: [
          // ---- 1. PANEL DE DETALLES ----
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            padding: const EdgeInsets.all(16),
            decoration: TemaApp.decoracionTarjeta(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1.1 Campo de texto
                TextField(
                  controller: _descController,
                  decoration: const InputDecoration(
                    hintText: "Detalles adicionales (piso, referencia...)",
                    prefixIcon: Icon(Icons.notes_rounded, size: 20),
                  ),
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 10),

                // 1.2 Adjuntar archivo
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _archivoAdjunto == null ? Icons.attach_file_rounded : Icons.check_circle_rounded,
                        color: _archivoAdjunto == null ? TemaApp.textoTerciario : TemaApp.exito,
                        size: 24,
                      ),
                      onPressed: () async {
                        File? archivo = await _servicioAlmacenamiento.seleccionarArchivo();
                        if (archivo != null) {
                          setState(() => _archivoAdjunto = archivo);
                        }
                      },
                    ),
                    Expanded(
                      child: Text(
                        _archivoAdjunto == null
                            ? "Adjuntar croquis o documento (opcional)"
                            : _archivoAdjunto!.path.split(RegExp(r'[/\\]')).last,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _archivoAdjunto == null ? TemaApp.textoSecundario : TemaApp.exito,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    // Botón para quitar el adjunto sin salir de la pantalla
                    if (_archivoAdjunto != null)
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18, color: TemaApp.textoTerciario),
                        tooltip: "Quitar archivo",
                        onPressed: () => setState(() => _archivoAdjunto = null),
                      ),
                  ],
                ),

                const Divider(height: 20),

                // 1.3 Selector de destinatarios
                const Text(
                  "NOTIFICAR A",
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: TemaApp.textoTerciario,
                    fontSize: 10.5,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                RadioGroup<bool>(
                  groupValue: _enviarATodos,
                  onChanged: (bool? valor) {
                    setState(() {
                      _enviarATodos = valor!;
                      if (_enviarATodos) _usuariosSeleccionados.clear();
                    });
                    // Si toca "Selectivo", abrimos la lista para ahorrarle un toque
                    if (!_enviarATodos) _abrirSelectorUsuarios();
                  },
                  child: Row(
                    children: const [
                      Expanded(
                        child: RadioListTile<bool>(
                          contentPadding: EdgeInsets.zero,
                          title: Text("Todo el personal", style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                          value: true,
                          activeColor: TemaApp.rojo,
                          dense: true,
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<bool>(
                          contentPadding: EdgeInsets.zero,
                          title: Text("Grupo selectivo", style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                          value: false,
                          activeColor: TemaApp.rojo,
                          dense: true,
                        ),
                      ),
                    ],
                  ),
                ),

                // Aviso: "todos" respeta la lista semanal de guardia
                if (_enviarATodos)
                  const Padding(
                    padding: EdgeInsets.only(left: 4, top: 2),
                    child: Text(
                      "Se notificará al personal de guardia de esta semana.",
                      style: TextStyle(color: TemaApp.textoTerciario, fontSize: 12),
                    ),
                  ),

                // Si está en modo selectivo, mostramos a quiénes eligió y el botón de editar
                if (!_enviarATodos)
                  OutlinedButton.icon(
                    onPressed: _abrirSelectorUsuarios,
                    icon: const Icon(Icons.edit_rounded, size: 16),
                    label: Text(
                      _usuariosSeleccionados.isEmpty
                          ? "Toca para elegir bomberos"
                          : "${_usuariosSeleccionados.length} bomberos seleccionados",
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _usuariosSeleccionados.isEmpty ? TemaApp.rojo : TemaApp.negro,
                      side: BorderSide(
                        color: _usuariosSeleccionados.isEmpty ? TemaApp.rojo : TemaApp.borde,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ---- 2. ETIQUETA DEL MAPA ----
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
            child: Row(
              children: const [
                Icon(Icons.location_on_rounded, color: TemaApp.rojo, size: 18),
                SizedBox(width: 8),
                Text(
                  "Ubicación exacta",
                  style: TextStyle(color: TemaApp.negro, fontWeight: FontWeight.w800, fontSize: 13.5),
                ),
                Spacer(),
                Text(
                  "Toca el mapa para ajustar",
                  style: TextStyle(color: TemaApp.textoTerciario, fontSize: 12),
                ),
              ],
            ),
          ),

          // ---- 3. MAPA ----
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(TemaApp.radioTarjeta),
                border: Border.all(color: TemaApp.borde),
              ),
              clipBehavior: Clip.antiAlias,
              child: FlutterMap(
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
                        width: 60,
                        height: 60,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: colorCat.withValues(alpha: 0.18),
                                shape: BoxShape.circle,
                                border: Border.all(color: colorCat.withValues(alpha: 0.5)),
                              ),
                            ),
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: colorCat, width: 3),
                              ),
                            ),
                            Positioned(
                              top: 5,
                              child: Icon(widget.categoria.icono, size: 18, color: colorCat),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Requisito de la política de uso de los tiles de OSM
                  const SimpleAttributionWidget(
                    source: Text("© OpenStreetMap contributors", style: TextStyle(fontSize: 10)),
                  ),
                ],
              ),
            ),
          ),

          // ---- 4. BOTÓN DE CONFIRMACIÓN ----
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _guardando ? null : _publicarAlerta,
                icon: _guardando
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.campaign_rounded, size: 24),
                label: Text(_guardando ? "ENVIANDO..." : "CONFIRMAR ALERTA"),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
