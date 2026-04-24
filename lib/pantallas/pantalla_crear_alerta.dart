import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../servicios/servicio_auth.dart';
import '../modelos/categoria_modelo.dart';
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
  // Coordenadas iniciales (Otavalo/Cotacachi)
  LatLng _ubicacionSeleccionada = const LatLng(0.2343, -78.2625);
  late final TextEditingController _descController;
  
  bool _guardando = false;

  // Archivo adjunto (Cloudinary)
  File? _archivoAdjunto;
  final ServicioAlmacenamiento _servicioAlmacenamiento = ServicioAlmacenamiento();

  // --- NUEVA LÓGICA DE DESTINATARIOS ---
  bool _enviarATodos = true; // Por defecto envía a general
  List<String> _usuariosSeleccionados = [];

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
    return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
  }

  // Abre el modal de selección múltiple
  void _abrirSelectorUsuarios() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Para que ocupe buen espacio si hay muchos bomberos
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.6, // Ocupa el 60% de la pantalla
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text("Seleccionar Personal", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Text(
                    "${_usuariosSeleccionados.length} bomberos seleccionados", 
                    style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)
                  ),
                  const Divider(height: 30),
                  
                  // Lista de Firebase
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('usuarios').snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                        final usuarios = snapshot.data!.docs;

                  return ListView.builder(
                          itemCount: usuarios.length,
                          itemBuilder: (context, index) {
                            var user = usuarios[index];
                            String userId = user.id;
                            
                            // 🚀 CORRECCIÓN: Convertimos los datos a un Map seguro
                            Map<String, dynamic> userData = user.data() as Map<String, dynamic>;

                            // Ahora sí podemos usar ?? con total seguridad
                            String nombreUser = userData['nombre'] ?? 'Usuario Desconocido';
                            String rangoUser = userData['rol'] ?? 'Operativo';

                            return CheckboxListTile(
                              title: Text(nombreUser, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(rangoUser, style: const TextStyle(fontSize: 12)),
                              value: _usuariosSeleccionados.contains(userId),
                              activeColor: widget.categoria.color,
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
                        );   },
                    ),
                  ),
                  
                  // Botón de confirmar selección
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.categoria.color,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        if (_usuariosSeleccionados.isEmpty) {
                          // Si desmarcó a todos y aceptó, regresamos al modo "Todos" automáticamente
                          setState(() => _enviarATodos = true);
                        }
                        Navigator.pop(context);
                      },
                      child: const Text("CONFIRMAR LISTA"),
                    ),
                  )
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

      // Enviar Notificación Selectiva
      await ServicioNotificaciones().enviarNotificacionSelectiva(
        uidsDestinatarios: listaFinalDestinos, 
        titulo: "🚨 EMERGENCIA: ${widget.categoria.nombre.toUpperCase()}",
        cuerpo: _descController.text.trim().isEmpty ? "Se requiere asistencia inmediata en el lugar." : _descController.text.trim(),
        urlImagen: urlSubida, 
      );

      if (mounted) {
        Navigator.pop(context); 
        Navigator.pop(context); 
        UtilidadMensajes.mostrarPersonalizado(context, "¡ALERTA ENVIADA!", widget.categoria.color, Icons.campaign_rounded);
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
          // 1. PANEL SUPERIOR BLANCO
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))]
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1.1 Campo de Texto
                TextField(
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
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 10),

                // 1.2 Adjuntar Archivo
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _archivoAdjunto == null ? Icons.attach_file : Icons.check_circle,
                        color: _archivoAdjunto == null ? Colors.grey : Colors.green,
                        size: 30,
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
                        _archivoAdjunto == null ? "Adjuntar Croquis/Doc (Opcional)" : "Archivo listo",
                        style: TextStyle(
                          color: _archivoAdjunto == null ? Colors.black54 : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const Divider(),

                // 1.3 SELECTOR DE DESTINATARIOS VISUAL (LOS RADIOS)
                const Text("Notificar a:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<bool>(
                        contentPadding: EdgeInsets.zero,
                        title: const Text("Todo el personal", style: TextStyle(fontSize: 14)),
                        value: true,
                        groupValue: _enviarATodos,
                        activeColor: colorCat,
                        onChanged: (bool? valor) {
                          setState(() {
                            _enviarATodos = valor!;
                            _usuariosSeleccionados.clear(); // Limpiamos la lista si vuelve a general
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<bool>(
                        contentPadding: EdgeInsets.zero,
                        title: const Text("Grupo selectivo", style: TextStyle(fontSize: 14)),
                        value: false,
                        groupValue: _enviarATodos,
                        activeColor: colorCat,
                        onChanged: (bool? valor) {
                          setState(() {
                            _enviarATodos = valor!;
                          });
                          // Si toca "Selectivo", abrimos automáticamente la lista para ahorrarle un toque
                          if (!_enviarATodos) _abrirSelectorUsuarios();
                        },
                      ),
                    ),
                  ],
                ),
                
                // Si está en modo selectivo, mostramos a quiénes eligió y el botón de editar
                if (!_enviarATodos)
                  OutlinedButton.icon(
                    onPressed: _abrirSelectorUsuarios,
                    icon: const Icon(Icons.edit, size: 18),
                    label: Text(_usuariosSeleccionados.isEmpty ? "Toca para elegir bomberos" : "${_usuariosSeleccionados.length} bomberos seleccionados"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _usuariosSeleccionados.isEmpty ? Colors.red : colorCat,
                      side: BorderSide(color: _usuariosSeleccionados.isEmpty ? Colors.red : colorCat),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 15),

          // 2. INSTRUCCIÓN DE MAPA
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

          // 3. MAPA
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
                          width: 60, height: 60,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 60, height: 60,
                                decoration: BoxDecoration(
                                  color: colorCat.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: colorCat.withOpacity(0.5), width: 1),
                                ),
                              ),
                              Container(
                                width: 12, height: 12,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: colorCat, width: 3),
                                ),
                              ),
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
              ),
            ),
          ),

          // 4. BOTÓN FINAL DE CONFIRMACIÓN
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
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
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