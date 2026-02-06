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
            _rangoUsuario = doc.data()?['rango'] ?? (widget.rolUsuario == 'admin' ? "Comandancia" : "Tropa");
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
      backgroundColor: TemaApp.fondoClaro,
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "CENTRAL DE ALERTAS",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
            Text(
              "Cuerpo de Bomberos Otavalo",
              style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.w400),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: TemaApp.azulInstitucional,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            onPressed: _refrescarAlertas,
            icon: const Icon(Icons.refresh_rounded),
          )
        ],
      ),
      drawer: MenuLateral(
        nombreUsuario: _nombreUsuario,
        rangoUsuario: _rangoUsuario,
        onCerrarSesion: _cerrarSesion,
      ),
      floatingActionButton: widget.rolUsuario == 'admin'
          ? FloatingActionButton.extended(
              backgroundColor: TemaApp.rojoBombero,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PantallaSeleccionTipo()),
                );
              },
              icon: const Icon(Icons.add_alert_rounded, color: Colors.white),
              label: const Text(
                "NUEVA ALERTA",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              elevation: 4,
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _refrescarAlertas,
        color: TemaApp.rojoBombero,
        child: VistaListaAlertas(
          servicioEmergencias: _servicioEmergencias,
          rolUsuario: widget.rolUsuario,
        ),
      ),
    );
  }
}