import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/tema_app.dart';
import '../config/utilidad_formato.dart';

class PantallaListaEventos extends StatefulWidget {
  const PantallaListaEventos({super.key});

  @override
  State<PantallaListaEventos> createState() => _PantallaListaEventosState();
}

class _PantallaListaEventosState extends State<PantallaListaEventos> {
  DateTime _fechaFiltro = DateTime.now();

  bool _esHoy(DateTime fecha) {
    final hoy = DateTime.now();
    return fecha.year == hoy.year && fecha.month == hoy.month && fecha.day == hoy.day;
  }

  @override
  Widget build(BuildContext context) {
    // Calculamos el inicio y fin del día seleccionado para el filtro de Firestore
    DateTime inicioDia = DateTime(_fechaFiltro.year, _fechaFiltro.month, _fechaFiltro.day, 0, 0, 0);
    DateTime finDia = DateTime(_fechaFiltro.year, _fechaFiltro.month, _fechaFiltro.day, 23, 59, 59);

    return Scaffold(
      backgroundColor: TemaApp.fondo,
      appBar: AppBar(
        title: const Text("Eventos"),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded),
            tooltip: "Elegir fecha",
            onPressed: () async {
              final fecha = await showDatePicker(
                context: context,
                initialDate: _fechaFiltro,
                firstDate: DateTime(2024),
                lastDate: DateTime(2030),
              );
              if (fecha != null) setState(() => _fechaFiltro = fecha);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ---- Filtro de fecha ----
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: TemaApp.decoracionTarjeta(radioPersonalizado: TemaApp.radio),
            child: Row(
              children: [
                const Icon(Icons.event_rounded, color: TemaApp.rojo, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _esHoy(_fechaFiltro) ? "Hoy · ${UtilidadFormato.fecha(_fechaFiltro)}" : UtilidadFormato.fecha(_fechaFiltro),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: TemaApp.negro,
                    ),
                  ),
                ),
                if (!_esHoy(_fechaFiltro))
                  TextButton(
                    onPressed: () => setState(() => _fechaFiltro = DateTime.now()),
                    child: const Text("Ver hoy"),
                  ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('eventos')
                  .where('fecha_programada', isGreaterThanOrEqualTo: inicioDia)
                  .where('fecha_programada', isLessThanOrEqualTo: finDia)
                  .orderBy('fecha_programada')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final eventos = snapshot.data!.docs;

                if (eventos.isEmpty) {
                  return const Center(
                    child: Text(
                      "No hay eventos agendados para esta fecha.",
                      style: TextStyle(color: TemaApp.textoSecundario, fontSize: 13.5),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: eventos.length,
                  itemBuilder: (context, index) {
                    var ev = eventos[index].data() as Map<String, dynamic>;
                    Timestamp ts = ev['fecha_programada'];
                    DateTime hora = ts.toDate();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: TemaApp.decoracionTarjeta(),
                      child: Row(
                        children: [
                          // Bloque de hora
                          Container(
                            width: 58,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: TemaApp.rojoSuave,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.schedule_rounded, size: 15, color: TemaApp.rojo),
                                const SizedBox(height: 4),
                                Text(
                                  UtilidadFormato.hora(hora),
                                  style: const TextStyle(
                                    color: TemaApp.rojo,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ev['tipo_evento'] ?? 'Evento',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: TemaApp.negro,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  ev['descripcion'] ?? '',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: TemaApp.textoSecundario,
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (ev['url_adjunto'] != null)
                            IconButton(
                              icon: const Icon(Icons.file_present_rounded, color: TemaApp.negro),
                              tooltip: "Ver adjunto",
                              onPressed: () => launchUrl(
                                Uri.parse(ev['url_adjunto']),
                                mode: LaunchMode.externalApplication,
                              ),
                            ),
                        ],
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
