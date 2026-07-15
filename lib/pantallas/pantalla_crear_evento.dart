import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../servicios/servicio_auth.dart';
import '../servicios/servicio_almacenamiento.dart';
import '../servicios/servicio_notificaciones.dart';
import '../config/tema_app.dart';
import '../config/utilidad_formato.dart';
import '../config/utilidad_mensajes.dart';

class PantallaCrearEvento extends StatefulWidget {
  const PantallaCrearEvento({super.key});

  @override
  State<PantallaCrearEvento> createState() => _PantallaCrearEventoState();
}

class _PantallaCrearEventoState extends State<PantallaCrearEvento> {
  final TextEditingController _descController = TextEditingController();

  // Variables de estado
  String _tipoEvento = 'Entrenamiento'; // Valor por defecto
  final List<String> _tipos = ['Entrenamiento', 'Operativo', 'Capacitación', 'Otro'];

  DateTime _fechaSeleccionada = DateTime.now();
  TimeOfDay _horaSeleccionada = TimeOfDay.now();

  File? _archivoAdjunto;
  final ServicioAlmacenamiento _servicioAlmacenamiento = ServicioAlmacenamiento();

  bool _guardando = false;

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  // --- Funciones para seleccionar Fecha y Hora nativas ---
  Future<void> _seleccionarFecha(BuildContext context) async {
    final DateTime? fecha = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime.now(), // No permite agendar en el pasado
      lastDate: DateTime(2030),
    );
    if (fecha != null) {
      setState(() => _fechaSeleccionada = fecha);
    }
  }

  Future<void> _seleccionarHora(BuildContext context) async {
    final TimeOfDay? hora = await showTimePicker(
      context: context,
      initialTime: _horaSeleccionada,
    );
    if (hora != null) {
      setState(() => _horaSeleccionada = hora);
    }
  }

  // --- Función Principal de Guardado ---
  void _guardarEvento() async {
    if (_descController.text.trim().isEmpty) {
      UtilidadMensajes.mostrarError(context, "Por favor, ingresa una descripción.");
      return;
    }

    setState(() => _guardando = true);

    try {
      String? urlSubida;

      // 1. Subir archivo si existe
      if (_archivoAdjunto != null) {
        urlSubida = await _servicioAlmacenamiento.subirArchivoAdjunto(_archivoAdjunto!);
      }

      // 2. Unir Fecha y Hora en un solo objeto Timestamp para Firebase
      final fechaFinal = DateTime(
        _fechaSeleccionada.year,
        _fechaSeleccionada.month,
        _fechaSeleccionada.day,
        _horaSeleccionada.hour,
        _horaSeleccionada.minute,
      );

      // 3. Crear el documento
      final eventoData = {
        'tipo_evento': _tipoEvento,
        'descripcion': _descController.text.trim(),
        'fecha_programada': Timestamp.fromDate(fechaFinal),
        'url_adjunto': urlSubida,
        'creado_por_id': ServicioAuth().usuarioActual?.uid ?? 'desconocido',
        'fecha_creacion': FieldValue.serverTimestamp(),
      };

      // 4. Guardar en la colección 'eventos'
      await FirebaseFirestore.instance.collection('eventos').add(eventoData);
      await ServicioNotificaciones().enviarNotificacionSelectiva(
        uidsDestinatarios: [], // Al enviarlo vacío, nuestro servicio busca a todos
        titulo: "NUEVO EVENTO: $_tipoEvento",
        cuerpo: _descController.text.trim(),
        urlImagen: urlSubida,
      );
      if (mounted) {
        // Mensaje antes del pop: el context de esta pantalla deja de ser
        // válido tras la navegación.
        UtilidadMensajes.mostrarExito(context, "¡$_tipoEvento agendado con éxito!");
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        UtilidadMensajes.mostrarError(context, "Error al agendar: $e");
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TemaApp.fondo,
      appBar: AppBar(title: const Text("Agendar evento")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Etiqueta("TIPO DE EVENTO"),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: TemaApp.relleno,
                borderRadius: BorderRadius.circular(TemaApp.radio),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _tipoEvento,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: TemaApp.textoSecundario),
                  style: const TextStyle(
                    color: TemaApp.negro,
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5,
                  ),
                  items: _tipos.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() => _tipoEvento = newValue!);
                  },
                ),
              ),
            ),
            const SizedBox(height: 22),

            const _Etiqueta("DETALLES"),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                hintText: "Ej: Capacitación de uso de extintores en Plaza Central...",
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 22),

            const _Etiqueta("FECHA Y HORA"),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _seleccionarFecha(context),
                    icon: const Icon(Icons.calendar_today_rounded, size: 16),
                    label: Text(UtilidadFormato.fecha(_fechaSeleccionada)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _seleccionarHora(context),
                    icon: const Icon(Icons.schedule_rounded, size: 16),
                    label: Text(_horaSeleccionada.format(context)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            const _Etiqueta("ADJUNTO"),
            Container(
              decoration: TemaApp.decoracionTarjeta(radioPersonalizado: TemaApp.radio),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(TemaApp.radio)),
                leading: Icon(
                  _archivoAdjunto == null ? Icons.attach_file_rounded : Icons.check_circle_rounded,
                  color: _archivoAdjunto == null ? TemaApp.textoTerciario : TemaApp.exito,
                ),
                title: Text(
                  _archivoAdjunto == null ? "Adjuntar archivo (opcional)" : "Archivo cargado",
                  style: TextStyle(
                    color: _archivoAdjunto == null ? TemaApp.negro : TemaApp.exito,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                subtitle: const Text(
                  "PDF, JPG o PNG",
                  style: TextStyle(color: TemaApp.textoTerciario, fontSize: 12),
                ),
                onTap: () async {
                  File? archivo = await _servicioAlmacenamiento.seleccionarArchivo();
                  if (archivo != null) {
                    setState(() => _archivoAdjunto = archivo);
                  }
                },
              ),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _guardando ? null : _guardarEvento,
                icon: _guardando
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.event_available_rounded, size: 20),
                label: Text(_guardando ? "AGENDANDO..." : "AGENDAR EVENTO"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Etiqueta de sección en mayúsculas pequeñas, estilo del sistema.
class _Etiqueta extends StatelessWidget {
  final String texto;
  const _Etiqueta(this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        texto,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 10.5,
          color: TemaApp.textoTerciario,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}
