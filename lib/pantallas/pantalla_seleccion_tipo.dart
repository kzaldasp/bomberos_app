import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../modelos/categoria_modelo.dart'; // Importamos el modelo nuevo
import '../config/tema_app.dart';
import 'pantalla_crear_alerta.dart';

class PantallaSeleccionTipo extends StatelessWidget {
  const PantallaSeleccionTipo({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Selecciona el Tipo"),
        backgroundColor: TemaApp.azulInstitucional,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            const Text(
              "¿Qué está ocurriendo?",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            
            // AQUÍ CONECTAMOS CON FIREBASE
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('categorias').snapshots(),
                builder: (context, snapshot) {
                  // 1. Cargando
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // 2. Sin datos
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text("No hay categorías configuradas"));
                  }

                  // 3. Pintamos la grilla
                  final docs = snapshot.data!.docs;
                  
                  return GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.3,
                    ),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      // Convertimos cada documento en nuestro Modelo
                      final categoria = CategoriaModelo.desdeFirestore(docs[index]);
                      
                      return Card(
                        color: categoria.color,
                        elevation: 5,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(15),
                          onTap: () {
                            // Pasamos la categoría al Mapa
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PantallaCrearAlerta(categoria: categoria),
                              ),
                            );
                          },
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(categoria.icono, size: 50, color: Colors.white),
                              const SizedBox(height: 10),
                              Text(
                                categoria.nombre,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white, 
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16
                                ),
                              ),
                              Text(
                                "Prioridad: ${categoria.importancia}",
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}