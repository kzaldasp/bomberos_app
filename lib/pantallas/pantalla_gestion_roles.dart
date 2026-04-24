import 'package:bomberos_app/config/tema_app.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'pantalla_crear_usuario.dart';
class PantallaGestionRoles extends StatelessWidget {
  const PantallaGestionRoles({super.key});

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
              final String correo = userData['correo'] ?? 'Sin correo';
              
              // Si no tiene el campo rol, asumimos que es 'operativo'
              final String rolActual = userData.containsKey('rol') ? userData['rol'] : 'operativo';
              final bool esAdmin = rolActual == 'admin';

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: SwitchListTile(
                  title: Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  subtitle: Text("$correo\nRol actual: ${rolActual.toUpperCase()}"),
                  value: esAdmin,
                  activeColor: Colors.orange, // Color cuando es admin
                  secondary: CircleAvatar(
                    backgroundColor: esAdmin ? Colors.orange : Colors.grey,
                    child: Icon(
                      esAdmin ? Icons.admin_panel_settings : Icons.person, 
                      color: Colors.white
                    ),
                  ),
                  onChanged: (bool valorSwitch) async {
                    // Lógica para cambiar el rol en Firestore al presionar el switch
                    String nuevoRol = valorSwitch ? 'admin' : 'operativo';
                    
                    try {
                      await FirebaseFirestore.instance
                          .collection('usuarios')
                          .doc(userId)
                          .update({'rol': nuevoRol});
                          
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Rol de $nombre actualizado a $nuevoRol"),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Error al actualizar: $e"),
                            backgroundColor: Colors.red,
                          ),
                        );
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