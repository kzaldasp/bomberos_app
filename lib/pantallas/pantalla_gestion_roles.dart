import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/tema_app.dart';
import '../config/utilidad_mensajes.dart';
import '../servicios/servicio_auth.dart';
import 'pantalla_crear_usuario.dart';

class PantallaGestionRoles extends StatelessWidget {
  const PantallaGestionRoles({super.key});

  /// Diálogo de confirmación antes de subir/bajar el rol de alguien.
  Future<bool> _confirmarCambio(BuildContext context, String nombre, bool haciaAdmin) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(haciaAdmin ? "¿Dar permisos de Admin?" : "¿Quitar permisos de Admin?"),
        content: Text(haciaAdmin
            ? "$nombre podrá crear alertas, gestionar personal y agendar eventos."
            : "$nombre pasará a ser Tropa y perderá el acceso administrativo."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancelar", style: TextStyle(color: TemaApp.textoSecundario)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: haciaAdmin ? TemaApp.rojo : TemaApp.negro,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(haciaAdmin ? "SÍ, DAR ADMIN" : "SÍ, QUITAR"),
          ),
        ],
      ),
    );
    return confirmado == true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TemaApp.fondo,
      appBar: AppBar(title: const Text("Gestión de personal")),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const PantallaCrearUsuario()));
        },
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text(
          "NUEVO PERSONAL",
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.6),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Escuchamos a la colección de usuarios en tiempo real
        stream: FirebaseFirestore.instance.collection('usuarios').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "No hay usuarios registrados.",
                style: TextStyle(color: TemaApp.textoSecundario),
              ),
            );
          }

          final usuarios = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: usuarios.length,
            itemBuilder: (context, index) {
              final user = usuarios[index];
              final userId = user.id;

              // Extraemos datos con seguridad por si algún campo falta en Firestore
              final Map<String, dynamic> userData = user.data() as Map<String, dynamic>;
              final String nombre = userData['nombre'] ?? 'Bombero sin nombre';
              final String correo = userData['email'] ?? 'Sin correo';
              final String rango = userData['rango'] ?? 'Sin rango';

              final String rolActual = userData['rol'] ?? Roles.bombero;
              final bool esAdmin = rolActual == Roles.admin;

              // Nadie puede cambiarse el rol a sí mismo: evita que el último
              // admin se degrade por accidente y se quede sin acceso.
              final bool esMiCuenta = userId == ServicioAuth().usuarioActual?.uid;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: TemaApp.decoracionTarjeta(),
                child: SwitchListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(TemaApp.radioTarjeta),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  title: Text(
                    esMiCuenta ? "$nombre (Tú)" : nombre,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                      color: TemaApp.negro,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      "$correo\n$rango · ${esAdmin ? 'ADMIN' : 'TROPA'}",
                      style: const TextStyle(
                        color: TemaApp.textoSecundario,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),
                  value: esAdmin,
                  secondary: Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: esAdmin ? TemaApp.rojoSuave : TemaApp.relleno,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      esAdmin ? Icons.local_police_rounded : Icons.person_rounded,
                      color: esAdmin ? TemaApp.rojo : TemaApp.textoTerciario,
                      size: 22,
                    ),
                  ),
                  onChanged: esMiCuenta
                      ? null // Deshabilitado en la propia cuenta
                      : (bool valorSwitch) async {
                          if (!await _confirmarCambio(context, nombre, valorSwitch)) return;

                          final String nuevoRol = valorSwitch ? Roles.admin : Roles.bombero;
                          try {
                            await FirebaseFirestore.instance
                                .collection('usuarios')
                                .doc(userId)
                                .update({'rol': nuevoRol});

                            if (context.mounted) {
                              UtilidadMensajes.mostrarExito(context,
                                  "Rol de $nombre actualizado a ${valorSwitch ? 'Admin' : 'Tropa'}");
                            }
                          } catch (e) {
                            if (context.mounted) {
                              UtilidadMensajes.mostrarError(context, "Error al actualizar: $e");
                            }
                          }
                        },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
