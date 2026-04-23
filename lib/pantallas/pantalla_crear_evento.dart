import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../servicios/servicio_auth.dart';
import '../servicios/servicio_almacenamiento.dart';
import '../config/tema_app.dart';

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

  // --- Funciones para seleccionar Fecha y Hora nativas ---
  Future<void> _seleccionarFecha(BuildContext context) async {
    final DateTime? fecha = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime.now(), // No permite agendar en el pasado
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: TemaApp.azulInstitucional,
            colorScheme: const ColorScheme.light(primary: TemaApp.azulInstitucional),
          ),
          child: child!,
        );
      },
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor, ingresa una descripción.")),
      );
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

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("¡$_tipoEvento agendado con éxito!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al agendar: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Agendar Evento", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: TemaApp.azulInstitucional,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. SELECTOR DE TIPO
            const Text("Tipo de Evento", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(15),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _tipoEvento,
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down, color: TemaApp.azulInstitucional),
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
            const SizedBox(height: 20),

            // 2. DESCRIPCIÓN
            const Text("Detalles del Evento", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              decoration: InputDecoration(
                hintText: "Ej: Capacitación de uso de extintores en Plaza Central...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 20),

            // 3. FECHA Y HORA
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _seleccionarFecha(context),
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text("${_fechaSeleccionada.day}/${_fechaSeleccionada.month}/${_fechaSeleccionada.year}"),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _seleccionarHora(context),
                    icon: const Icon(Icons.access_time, size: 18),
                    label: Text(_horaSeleccionada.format(context)),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 4. ARCHIVO ADJUNTO
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(15),
              ),
              child: ListTile(
                leading: Icon(
                  _archivoAdjunto == null ? Icons.attach_file : Icons.check_circle,
                  color: _archivoAdjunto == null ? Colors.grey : Colors.green,
                  size: 30,
                ),
                title: Text(
                  _archivoAdjunto == null ? "Adjuntar Archivo (Opcional)" : "Archivo cargado",
                  style: TextStyle(
                    color: _archivoAdjunto == null ? Colors.black87 : Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: const Text("PDF, JPG o PNG"),
                onTap: () async {
                  File? archivo = await _servicioAlmacenamiento.seleccionarArchivo();
                  if (archivo != null) {
                    setState(() => _archivoAdjunto = archivo);
                  }
                },
              ),
            ),
            const SizedBox(height: 30),

            // 5. BOTÓN GUARDAR
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _guardando ? null : _guardarEvento,
                style: ElevatedButton.styleFrom(
                  backgroundColor: TemaApp.azulInstitucional,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                icon: _guardando 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save),
                label: Text(
                  _guardando ? "AGENDANDO..." : "AGENDAR EVENTO",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}