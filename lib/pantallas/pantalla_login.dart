import 'package:flutter/material.dart';
import '../config/tema_app.dart';
import '../servicios/servicio_auth.dart';
import 'pantalla_dashboard.dart';

class PantallaLogin extends StatefulWidget {
  const PantallaLogin({super.key});

  @override
  State<PantallaLogin> createState() => _PantallaLoginState();
}

class _PantallaLoginState extends State<PantallaLogin> {
  final _controladorCorreo = TextEditingController();
  final _controladorClave = TextEditingController();
  final _servicioAuth = ServicioAuth();
  bool _estaCargando = false;

  void _procesarIngreso() async {
    setState(() => _estaCargando = true);

    String? resultado = await _servicioAuth.iniciarSesion(
      _controladorCorreo.text.trim(),
      _controladorClave.text.trim(),
    );

    setState(() => _estaCargando = false);

    if (resultado == 'admin' || resultado == 'bombero') {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => PantallaDashboard(rolUsuario: resultado!)),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(resultado ?? "Error desconocido"),
            backgroundColor: TemaApp.rojoBombero,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Usamos LayoutBuilder para asegurar que el footer quede abajo
    // pero que todo sea desplazable si sale el teclado.
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0), // Padding estándar moderno
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(), // Empuja contenido al centro visual

                      // --- 1. LOGO E IDENTIDAD ---
                      Image.asset(
                        'assets/images/logo.png',
                        height: 120, 
                        fit: BoxFit.contain,
                      ),
                      
                      const SizedBox(height: 30),

                      // Títulos con Jerarquía
                      Text(
                        "SISTEMA DE ALERTAS",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0, // Espaciado elegante
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "BOMBEROS OTAVALO",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: TemaApp.azulInstitucional, // Tu azul Navy
                          fontSize: 24,
                          fontWeight: FontWeight.w900, // Extra Bold
                          height: 1.0,
                        ),
                      ),

                      const SizedBox(height: 50),

                      // --- 2. INPUTS (Siguiendo tu TemaApp) ---
                      // Correo
                      TextField(
                        controller: _controladorCorreo,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          hintText: "Correo electrónico",
                          hintStyle: TextStyle(color: Colors.grey.shade400),
                          prefixIcon: const Icon(Icons.email_outlined),
                          prefixIconColor: Colors.grey.shade500,
                          filled: true,
                          fillColor: TemaApp.grisInput, // Tu gris del tema
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16), // Tu radio del tema
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                        ),
                      ),
                      
                      const SizedBox(height: 16), // Espacio limpio entre inputs

                      // Contraseña
                      TextField(
                        controller: _controladorClave,
                        obscureText: true,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                        decoration: InputDecoration(
                          hintText: "Contraseña",
                          hintStyle: TextStyle(color: Colors.grey.shade400),
                          prefixIcon: const Icon(Icons.lock_outline),
                          prefixIconColor: Colors.grey.shade500,
                          filled: true,
                          fillColor: TemaApp.grisInput,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // --- 3. BOTÓN DE ACCIÓN (Tu TemaApp) ---
                      SizedBox(
                        width: double.infinity,
                        height: 58, // Altura cómoda para el dedo
                        child: ElevatedButton(
                          onPressed: _estaCargando ? null : _procesarIngreso,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TemaApp.rojoBombero,
                            foregroundColor: Colors.white,
                            elevation: 5,
                            shadowColor: TemaApp.rojoBombero.withOpacity(0.4), // Glow rojo
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16), // Tu radio del tema
                            ),
                          ),
                          child: _estaCargando 
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                            : const Text("INGRESAR", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                        ),
                      ),

                      const Spacer(), // Empuja el footer al final

                      // --- 4. FOOTER MINIMALISTA ---
                      Padding(
                        padding: const EdgeInsets.only(bottom: 30.0),
                        child: Text(
                          "Versión 1.0.0",
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 12,
                            fontWeight: FontWeight.w500
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}