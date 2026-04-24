import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/tema_app.dart';

class PantallaListaEventos extends StatefulWidget {
  const PantallaListaEventos({super.key});

  @override
  State<PantallaListaEventos> createState() => _PantallaListaEventosState();
}

class _PantallaListaEventosState extends State<PantallaListaEventos> {
  DateTime _fechaFiltro = DateTime.now();

  @override
  Widget build(BuildContext context) {
    // Calculamos el inicio y fin del día seleccionado para el filtro de Firestore
    DateTime inicioDia = DateTime(_fechaFiltro.year, _fechaFiltro.month, _fechaFiltro.day, 0, 0, 0);
    DateTime finDia = DateTime(_fechaFiltro.year, _fechaFiltro.month, _fechaFiltro.day, 23, 59, 59);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Calendario de Eventos"),
        backgroundColor: TemaApp.azulInstitucional,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () async {
              final fecha = await showDatePicker(
                context: context,
                initialDate: _fechaFiltro,
                firstDate: DateTime(2024),
                lastDate: DateTime(2030),
              );
              if (fecha != null) setState(() => _fechaFiltro = fecha);
            },
          )
        ],
      ),
      body: Column(
        children: [
          // Selector de fecha rápido
          Container(
            padding: const EdgeInsets.all(15),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.filter_alt, color: Colors.grey, size: 18),
                const SizedBox(width: 10),
                Text(
                  "Mostrando: ${_fechaFiltro.day}/${_fechaFiltro.month}/${_fechaFiltro.year}",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                if (_fechaFiltro.day != DateTime.now().day)
                  TextButton(
                    onPressed: () => setState(() => _fechaFiltro = DateTime.now()),
                    child: const Text("Ver Hoy"),
                  )
              ],
            ),
          ),
          
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('eventos')
                  .where('fecha_programada', isGreaterThanOrEqualTo: inicioDia)
                  .where('fecha_programada', isLessThanOrEqualTo: finDia)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final eventos = snapshot.data!.docs;

                if (eventos.isEmpty) {
                  return const Center(
                    child: Text("No hay eventos agendados para esta fecha."),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(15),
                  itemCount: eventos.length,
                  itemBuilder: (context, index) {
                    var ev = eventos[index].data() as Map<String, dynamic>;
                    Timestamp ts = ev['fecha_programada'];
                    DateTime hora = ts.toDate();

                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: TemaApp.azulInstitucional.withOpacity(0.1),
                          child: const Icon(Icons.event_note, color: TemaApp.azulInstitucional),
                        ),
                        title: Text(ev['tipo_evento'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("${ev['descripcion']}\n⏰ ${hora.hour}:${hora.minute.toString().padLeft(2,'0')}"),
                        trailing: ev['url_adjunto'] != null 
                          ? IconButton(
                              icon: const Icon(Icons.file_present, color: Colors.blue),
                              onPressed: () => launchUrl(Uri.parse(ev['url_adjunto']), mode: LaunchMode.externalApplication),
                            )
                          : null,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}