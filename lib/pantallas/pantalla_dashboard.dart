import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/tema_app.dart';
import '../servicios/servicio_auth.dart';
import '../servicios/servicio_emergencias.dart';
import 'pantalla_login.dart';
import 'pantalla_seleccion_tipo.dart';
import '../widgets/menu_lateral.dart';
import '../widgets/vista_lista_alertas.dart';

class PantallaDashboard extends StatefulWidget {
  final String rolUsuario;

  const PantallaDashboard({super.key, required this.rolUsuario});

  @override
  State<PantallaDashboard> createState() => _PantallaDashboardState();
}

class _PantallaDashboardState extends State<PantallaDashboard> {
  String _nombreUsuario = "Cargando...";
  String _rangoUsuario = "";
  final ServicioEmergencias _servicioEmergencias = ServicioEmergencias();
  final ServicioAuth _auth = ServicioAuth();

  @override
  void initState() {
    super.initState();
    _cargarDatosUsuario();
  }

  void _cargarDatosUsuario() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
        if (doc.exists && mounted) {
          setState(() {
            _nombreUsuario = doc.data()?['nombre'] ?? "Usuario";
            _rangoUsuario = doc.data()?['rango'] ?? (widget.rolUsuario == Roles.admin ? "Comandancia" : "Tropa");
          });
        }
      } catch (e) {
        if (mounted) setState(() => _nombreUsuario = "Bombero");
      }
    }
  }

  void _cerrarSesion() async {
    await _auth.cerrarSesion();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const PantallaLogin()),
        (route) => false,
      );
    }
  }

  Future<void> _refrescarAlertas() async {
    setState(() {});
    await Future.delayed(const Duration(seconds: 1));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TemaApp.fondo,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/logo.png', height: 26),
            const SizedBox(width: 10),
            const Text("Central de Alertas"),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _refrescarAlertas,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: "Actualizar",
          ),
        ],
      ),
      drawer: MenuLateral(
        nombreUsuario: _nombreUsuario,
        rangoUsuario: _rangoUsuario,
        rolUsuario: widget.rolUsuario,
        onCerrarSesion: _cerrarSesion,
      ),
      // Cualquier usuario (admin o tropa) puede emitir una alerta.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PantallaSeleccionTipo(rolUsuario: widget.rolUsuario),
            ),
          );
        },
        icon: const Icon(Icons.add_alert_rounded),
        label: const Text(
          "NUEVA ALERTA",
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.6),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refrescarAlertas,
        color: TemaApp.rojo,
        child: VistaListaAlertas(
          servicioEmergencias: _servicioEmergencias,
          rolUsuario: widget.rolUsuario,
        ),
      ),
    );
  }
}
