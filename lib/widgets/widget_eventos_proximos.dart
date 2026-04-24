import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/tema_app.dart'; // Ajusta la ruta si es necesario

class WidgetEventosProximos extends StatelessWidget {
  const WidgetEventosProximos({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Text(
            "Eventos y Capacitaciones",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey),
          ),
        ),
        StreamBuilder<QuerySnapshot>(
          // Consultamos los eventos ordenados por la fecha programada más próxima
          stream: FirebaseFirestore.instance
              .collection('eventos')
              .orderBy('fecha_programada', descending: false)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text("No hay eventos agendados por el momento.", style: TextStyle(color: Colors.grey)),
              );
            }

            final eventos = snapshot.data!.docs;

            return ListView.builder(
              shrinkWrap: true, // Importante para que no de error de espacio
              physics: const NeverScrollableScrollPhysics(), // El scroll lo hace la pantalla principal
              padding: const EdgeInsets.symmetric(horizontal: 15),
              itemCount: eventos.length,
              itemBuilder: (context, index) {
                var ev = eventos[index].data() as Map<String, dynamic>;
                
                // Extraer datos
                String titulo = ev['tipo_evento'] ?? 'Evento';
                String descripcion = ev['descripcion'] ?? '';
                String? urlAdjunto = ev['url_adjunto'];
                Timestamp ts = ev['fecha_programada'];
                DateTime fecha = ts.toDate();

                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  margin: const EdgeInsets.only(bottom: 15),
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Cabecera del Evento
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: TemaApp.azulInstitucional.withOpacity(0.1), shape: BoxShape.circle),
                              child: const Icon(Icons.event, color: TemaApp.azulInstitucional),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(titulo.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text(
                                    "📅 ${fecha.day}/${fecha.month}/${fecha.year} - ⏰ ${fecha.hour}:${fecha.minute.toString().padLeft(2, '0')}",
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        
                        // Descripción
                        Text(descripcion, style: TextStyle(color: Colors.grey.shade800)),
                        
                        // Botón de Adjunto (Solo si existe)
                        if (urlAdjunto != null && urlAdjunto.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                              child: OutlinedButton.icon(
                              onPressed: () async {
                                final url = Uri.parse(urlAdjunto);
                                // Intentamos abrirlo directamente sin preguntar si "puede"
                                bool lanzado = await launchUrl(
                                  url, 
                                  mode: LaunchMode.externalApplication // Fuerza a abrir el navegador externo
                                );
                                
                                if (!lanzado && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("No se encontró una app para abrir este archivo")),
                                  );
                                }
                              },
                              icon: const Icon(Icons.picture_as_pdf, size: 18),
                              label: const Text("Ver Material / Doc"),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: TemaApp.azulInstitucional,
                                side: const BorderSide(color: TemaApp.azulInstitucional),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                              ),
                            ),
                          )
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}