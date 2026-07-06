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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(haciaAdmin ? "¿Dar permisos de Admin?" : "¿Quitar permisos de Admin?"),
        content: Text(haciaAdmin
            ? "$nombre podrá crear alertas, gestionar personal y agendar eventos."
            : "$nombre pasará a ser Tropa y perderá el acceso administrativo."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: haciaAdmin ? Colors.orange : Colors.blueGrey),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(haciaAdmin ? "SÍ, DAR ADMIN" : "SÍ, QUITAR", style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return confirmado == true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestión de Personal", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueGrey[800], // Un color más serio para admins
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const PantallaCrearUsuario()));
        },
        backgroundColor: TemaApp.azulInstitucional,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("NUEVO PERSONAL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      // ----------------------------
      body: StreamBuilder<QuerySnapshot>(
        // Escuchamos a la colección de usuarios en tiempo real
        stream: FirebaseFirestore.instance.collection('usuarios').snapshots(),
        builder: (context, snapshot) {
          // 1. Estado de carga
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. Si no hay datos
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No hay usuarios registrados."));
          }

          final usuarios = snapshot.data!.docs;

          // 3. Pintamos la lista de personal
          return ListView.builder(
            padding: const EdgeInsets.all(10),
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

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: SwitchListTile(
                  title: Text(
                    esMiCuenta ? "$nombre (Tú)" : nombre,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Text("$correo\n$rango • ${esAdmin ? 'ADMIN' : 'TROPA'}"),
                  value: esAdmin,
                  activeThumbColor: Colors.orange, // Color cuando es admin
                  secondary: CircleAvatar(
                    backgroundColor: esAdmin ? Colors.orange : Colors.grey,
                    child: Icon(
                      esAdmin ? Icons.admin_panel_settings : Icons.person,
                      color: Colors.white
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