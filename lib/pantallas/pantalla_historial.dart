import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../config/tema_app.dart';
import '../config/utilidad_mensajes.dart';
import '../modelos/emergencia_modelo.dart';
import '../servicios/servicio_auth.dart';
import '../servicios/servicio_emergencias.dart';
import '../widgets/tarjeta_emergencia.dart';
import 'pantalla_detalle_alerta.dart';

/// Historial de casos cerrados, paginado.
///
/// Un caso finalizado ya no cambia, así que se carga por páginas con get()
/// puntuales (sin stream): abrir esta pantalla cuesta máximo 25 lecturas de
/// Firestore aunque el archivo acumule años de casos.
class PantallaHistorial extends StatefulWidget {
  final String rolUsuario;

  const PantallaHistorial({super.key, required this.rolUsuario});

  @override
  State<PantallaHistorial> createState() => _PantallaHistorialState();
}

class _PantallaHistorialState extends State<PantallaHistorial> {
  final ServicioEmergencias _servicio = ServicioEmergencias();

  final List<EmergenciaModelo> _alertas = [];
  DocumentSnapshot? _cursor; // Último doc de la página anterior
  bool _cargando = true;
  bool _cargandoMas = false;
  bool _hayMas = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarPrimeraPagina();
  }

  Future<void> _cargarPrimeraPagina() async {
    setState(() {
      _cargando = true;
      _error = null;
      _alertas.clear();
      _cursor = null;
    });
    try {
      final pagina = await _servicio.obtenerPaginaHistorial();
      if (!mounted) return;
      setState(() {
        _alertas.addAll(pagina.alertas);
        _cursor = pagina.cursor;
        _hayMas = pagina.hayMas;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "No se pudo cargar el historial.";
        _cargando = false;
      });
    }
  }

  Future<void> _cargarMas() async {
    if (_cargandoMas || !_hayMas) return;
    setState(() => _cargandoMas = true);
    try {
      final pagina = await _servicio.obtenerPaginaHistorial(despuesDe: _cursor);
      if (!mounted) return;
      setState(() {
        _alertas.addAll(pagina.alertas);
        _cursor = pagina.cursor;
        _hayMas = pagina.hayMas;
        _cargandoMas = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargandoMas = false);
      UtilidadMensajes.mostrarError(context, "No se pudieron cargar más casos.");
    }
  }

  /// Solo admin: borra los casos con más de un año (y sus trayectos).
  Future<void> _depurarAntiguos() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Depurar historial?"),
        content: const Text(
          "Se eliminarán definitivamente los casos cerrados con más de "
          "1 año de antigüedad. Esta acción no se puede deshacer.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancelar", style: TextStyle(color: TemaApp.textoSecundario)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: TemaApp.rojo),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("DEPURAR"),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    setState(() => _cargando = true);
    try {
      final eliminados = await _servicio.depurarHistorialAntiguo();
      if (!mounted) return;
      UtilidadMensajes.mostrarExito(
        context,
        eliminados == 0
            ? "No hay casos con más de 1 año."
            : "Se eliminaron $eliminados casos antiguos.",
      );
    } catch (e) {
      if (mounted) {
        UtilidadMensajes.mostrarError(context, "No se pudo depurar el historial.");
      }
    }
    await _cargarPrimeraPagina();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TemaApp.fondo,
      appBar: AppBar(
        title: const Text("Historial operativo"),
        actions: [
          if (widget.rolUsuario == Roles.admin)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: "Depurar casos con más de 1 año",
              onPressed: _cargando ? null : _depurarAntiguos,
            ),
        ],
      ),
      body: _construirCuerpo(),
    );
  }

  Widget _construirCuerpo() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: TemaApp.textoSecundario)),
            const SizedBox(height: 12),
            TextButton(onPressed: _cargarPrimeraPagina, child: const Text("Reintentar")),
          ],
        ),
      );
    }

    if (_alertas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: TemaApp.superficie,
                shape: BoxShape.circle,
                border: Border.all(color: TemaApp.borde, width: 1.5),
              ),
              child: const Icon(Icons.history_rounded, size: 42, color: TemaApp.textoTerciario),
            ),
            const SizedBox(height: 24),
            const Text(
              "Sin historial",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: TemaApp.negro),
            ),
            const SizedBox(height: 6),
            const Text(
              "Los casos cerrados aparecerán aquí.",
              style: TextStyle(fontSize: 13, color: TemaApp.textoSecundario),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarPrimeraPagina,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        // +1 para el botón "Cargar más" al final (si quedan páginas)
        itemCount: _alertas.length + (_hayMas ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _alertas.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: _cargandoMas
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : TextButton.icon(
                        onPressed: _cargarMas,
                        icon: const Icon(Icons.expand_more_rounded, size: 20),
                        label: const Text(
                          "Cargar casos anteriores",
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
              ),
            );
          }

          final alerta = _alertas[index];

          // Misma tarjeta del tablero; al tocarla se abre el detalle bloqueado
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TarjetaEmergencia(
              alerta: alerta,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PantallaDetalleAlerta(
                      alerta: alerta,
                      rolUsuario: widget.rolUsuario,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
