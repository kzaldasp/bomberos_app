import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/tema_app.dart';
import '../config/utilidad_mensajes.dart';

/// Pantalla exclusiva del admin para marcar, semana a semana, qué bomberos
/// están de guardia. Solo el personal de guardia recibe las notificaciones
/// push de las alertas enviadas a "Todo el personal"; los demás siguen
/// viendo las alertas dentro de la app.
class PantallaPersonalGuardia extends StatelessWidget {
  const PantallaPersonalGuardia({super.key});

  Future<void> _cambiarGuardia(BuildContext context, String uid, String nombre, bool deGuardia) async {
    try {
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .update({'de_guardia': deGuardia});
    } catch (e) {
      if (context.mounted) {
        UtilidadMensajes.mostrarError(context, "No se pudo actualizar a $nombre: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TemaApp.fondo,
      appBar: AppBar(title: const Text("Personal de guardia")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('usuarios').orderBy('nombre').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "No hay personal registrado.",
                style: TextStyle(color: TemaApp.textoSecundario),
              ),
            );
          }

          final usuarios = snapshot.data!.docs;
          final int enGuardia = usuarios.where((u) {
            final data = u.data() as Map<String, dynamic>;
            return data['de_guardia'] != false; // Sin marcar = de guardia
          }).length;

          return Column(
            children: [
              // ---- Resumen de la semana ----
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                padding: const EdgeInsets.all(16),
                decoration: TemaApp.decoracionTarjeta(),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: TemaApp.rojoSuave,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(Icons.local_fire_department_rounded, color: TemaApp.rojo, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "$enGuardia de ${usuarios.length} de guardia esta semana",
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: TemaApp.negro,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            "Los desactivados no recibirán notificaciones push.",
                            style: TextStyle(color: TemaApp.textoSecundario, fontSize: 12.5, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: usuarios.length,
                  itemBuilder: (context, index) {
                    final user = usuarios[index];
                    final data = user.data() as Map<String, dynamic>;
                    final String nombre = data['nombre'] ?? 'Bombero sin nombre';
                    final String rango = data['rango'] ?? 'Sin rango';
                    final bool deGuardia = data['de_guardia'] != false;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: TemaApp.decoracionTarjeta(),
                      child: SwitchListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(TemaApp.radioTarjeta),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        title: Text(
                          nombre,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                            color: TemaApp.negro,
                          ),
                        ),
                        subtitle: Text(
                          deGuardia ? "$rango · De guardia" : "$rango · Sin notificaciones",
                          style: TextStyle(
                            color: deGuardia ? TemaApp.exito : TemaApp.textoTerciario,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        value: deGuardia,
                        secondary: Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: deGuardia
                                ? TemaApp.exito.withValues(alpha: 0.1)
                                : TemaApp.relleno,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(
                            deGuardia
                                ? Icons.notifications_active_rounded
                                : Icons.notifications_off_outlined,
                            color: deGuardia ? TemaApp.exito : TemaApp.textoTerciario,
                            size: 21,
                          ),
                        ),
                        onChanged: (valor) => _cambiarGuardia(context, user.id, nombre, valor),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
