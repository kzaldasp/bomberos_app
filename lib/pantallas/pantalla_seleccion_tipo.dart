import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../modelos/categoria_modelo.dart';
import '../config/tema_app.dart';
import '../servicios/servicio_auth.dart';
import '../servicios/servicio_categorias.dart';
import 'pantalla_crear_alerta.dart';

class PantallaSeleccionTipo extends StatefulWidget {
  final String rolUsuario;

  const PantallaSeleccionTipo({super.key, required this.rolUsuario});

  @override
  State<PantallaSeleccionTipo> createState() => _PantallaSeleccionTipoState();
}

class _PantallaSeleccionTipoState extends State<PantallaSeleccionTipo> {
  // El catálogo casi nunca cambia: un get() puntual en vez de un stream vivo.
  late final Future<QuerySnapshot> _futuroCategorias = _cargarCategorias();

  Future<QuerySnapshot> _cargarCategorias() async {
    // Un admin completa el catálogo si faltan categorías base
    // (Rescate, Desastres Naturales, Otros) ANTES de leerlas.
    if (widget.rolUsuario == Roles.admin) {
      await ServicioCategorias().asegurarCategoriasBase();
    }
    return FirebaseFirestore.instance.collection('categorias').get();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TemaApp.fondo,
      appBar: AppBar(title: const Text("Nueva alerta")),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "¿Qué está ocurriendo?",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: TemaApp.negro,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "Selecciona el tipo de emergencia para continuar",
              style: TextStyle(fontSize: 13, color: TemaApp.textoSecundario),
            ),
            const SizedBox(height: 20),

            Expanded(
              child: FutureBuilder<QuerySnapshot>(
                future: _futuroCategorias,
                builder: (context, snapshot) {
                  // 1. Error (sin conexión o sin permisos)
                  if (snapshot.hasError) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(30),
                        child: Text(
                          "No se pudieron cargar las categorías.\nRevisa tu conexión.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: TemaApp.textoSecundario),
                        ),
                      ),
                    );
                  }

                  // 2. Cargando
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // 3. Sin datos
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text("No hay categorías configuradas"));
                  }

                  final docs = snapshot.data!.docs;

                  return GridView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.05,
                    ),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final categoria = CategoriaModelo.desdeFirestore(docs[index]);

                      return _TarjetaCategoria(
                        categoria: categoria,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PantallaCrearAlerta(categoria: categoria),
                            ),
                          );
                        },
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

/// Tarjeta blanca minimalista: icono en cápsula de color + nombre + prioridad.
class _TarjetaCategoria extends StatelessWidget {
  final CategoriaModelo categoria;
  final VoidCallback onTap;

  const _TarjetaCategoria({required this.categoria, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: TemaApp.decoracionTarjeta(),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: categoria.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(categoria.icono, size: 26, color: categoria.color),
                ),
                const Spacer(),
                Text(
                  categoria.nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: TemaApp.negro,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: categoria.color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "Prioridad ${categoria.importancia}",
                      style: const TextStyle(
                        color: TemaApp.textoSecundario,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
