import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../servicios/servicio_auth.dart';
import '../modelos/categoria_modelo.dart';
import '../config/utilidad_mensajes.dart'; 
import '../servicios/servicio_almacenamiento.dart';

class PantallaCrearAlerta extends StatefulWidget {
  final CategoriaModelo categoria;

  const PantallaCrearAlerta({super.key, required this.categoria});

  @override
  State<PantallaCrearAlerta> createState() => _PantallaCrearAlertaState();
}

class _PantallaCrearAlertaState extends State<PantallaCrearAlerta> {
  // Coordenadas iniciales (Cotacachi)
  LatLng _ubicacionSeleccionada = const LatLng(0.2343, -78.2625);
  late final TextEditingController _descController;
  
  // Variable unificada para bloquear la pantalla mientras carga
  bool _guardando = false;

  // Variables para el archivo adjunto (Cloudinary)
  File? _archivoAdjunto;
  final ServicioAlmacenamiento _servicioAlmacenamiento = ServicioAlmacenamiento();

  // Lista para la alerta selectiva (Tipo WhatsApp)
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

  // Ayudante: Color -> String Hex (#F57C00)
  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
  }

  // Función que abre el selector de destinatarios desde abajo
  void _abrirSelectorUsuarios() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    "Seleccionar Destinatarios",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    "Si no seleccionas ninguno, se enviará a todos.",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const Divider(),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('usuarios').snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final usuarios = snapshot.data!.docs;

                        return ListView.builder(
                          itemCount: usuarios.length,
                          itemBuilder: (context, index) {
                            var user = usuarios[index];
                            String userId = user.id;
                            String nombreUser = user['nombre'] ?? 'Usuario';

                            return CheckboxListTile(
                              title: Text(nombreUser),
                              value: _usuariosSeleccionados.contains(userId),
                              activeColor: widget.categoria.color,
                              onChanged: (bool? seleccionado) {
                                setModalState(() { // Actualiza el modal en vivo
                                  if (seleccionado == true) {
                                    _usuariosSeleccionados.add(userId);
                                  } else {
                                    _usuariosSeleccionados.remove(userId);
                                  }
                                });
                                setState(() {}); // Actualiza la pantalla principal
                              },
                            );
                          },
                        );
                      },
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

  // MÉTODO PRINCIPAL UNIFICADO: Sube archivo (si hay) y guarda en Firestore
  void _publicarAlerta() async {
    if (_guardando) return;
    setState(() => _guardando = true);

    try {
      String? urlSubida;

      // 1. Subir archivo a Cloudinary (si el usuario eligió uno)
      if (_archivoAdjunto != null) {
        urlSubida = await _servicioAlmacenamiento.subirArchivoAdjunto(_archivoAdjunto!);
      }

      // 2. Preparar datos visuales
      final String colorString = _colorToHex(widget.categoria.color);
      final String iconoString = widget.categoria.nombreIcono; 

      // 3. Crear el documento completo para Firestore
      final alerta = {
        "titulo": widget.categoria.nombre,
        "descripcion": _descController.text.trim().isEmpty 
            ? "Sin detalles adicionales" 
            : _descController.text.trim(),
        "fecha_hora": FieldValue.serverTimestamp(),
        "estado": "activa",
        "creado_por_uid": ServicioAuth().usuarioActual?.uid,
        "ubicacion": GeoPoint(_ubicacionSeleccionada.latitude, _ubicacionSeleccionada.longitude),
        "respuestas": [],
        
        // --- NUEVOS CAMPOS AÑADIDOS ---
        "url_adjunto": urlSubida, 
        "destinatarios": _usuariosSeleccionados, // Lista vacía = Enviar a todos
        
        // Información de Categoría (Para no requerir joins en lectura)
        "tipo_id": widget.categoria.id,
        "nombre": widget.categoria.nombre,
        "importancia": widget.categoria.importancia,
        "color": colorString, 
        "icono": iconoString, 
      };

      // 4. Guardar en Base de Datos
      await FirebaseFirestore.instance.collection('emergencias').add(alerta);

      // 5. Salir con éxito
      if (mounted) {
        Navigator.pop(context); // Cierra pantalla actual
        Navigator.pop(context); // Cierra selector de tipo
        
        UtilidadMensajes.mostrarPersonalizado(
          context, 
          "¡ALERTA DE ${widget.categoria.nombre.toUpperCase()} ENVIADA!", 
          widget.categoria.color, 
          Icons.campaign_rounded
        );
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
          // 1. CONTENEDOR SUPERIOR (Texto + Archivo + Destinatarios)
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

                // 1.2 Botón de Adjuntar Archivo
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
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Archivo adjuntado correctamente")),
                            );
                          }
                        }
                      },
                    ),
                    Expanded(
                      child: Text(
                        _archivoAdjunto == null 
                            ? "Adjuntar PDF o Imagen (Opcional)" 
                            : "Archivo listo para enviar",
                        style: TextStyle(
                          color: _archivoAdjunto == null ? Colors.black54 : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                // 1.3 Botón Selector de Usuarios
                ElevatedButton.icon(
                  onPressed: _abrirSelectorUsuarios,
                  icon: const Icon(Icons.people),
                  label: Text(
                    _usuariosSeleccionados.isEmpty 
                        ? "Enviar a TODOS" 
                        : "Enviar a ${_usuariosSeleccionados.length} personas"
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
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

          // 3. MAPA EXPANDIDO
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