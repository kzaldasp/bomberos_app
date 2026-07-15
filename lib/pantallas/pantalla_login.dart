import 'package:flutter/material.dart';
import '../config/tema_app.dart';
import '../servicios/servicio_auth.dart';
import 'pantalla_cambiar_clave.dart';
import 'pantalla_dashboard.dart';
import '../config/utilidad_mensajes.dart';

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
  bool _ocultarClave = true;

  void _procesarIngreso() async {
    final correo = _controladorCorreo.text.trim();
    final clave = _controladorClave.text.trim();

    if (correo.isEmpty || clave.isEmpty) {
      UtilidadMensajes.mostrarError(context, "Ingresa tu correo y contraseña.");
      return;
    }

    setState(() => _estaCargando = true);

    final resultado = await _servicioAuth.iniciarSesion(correo, clave);

    if (!mounted) return;
    setState(() => _estaCargando = false);

    final rol = resultado.rol;
    if (rol == Roles.admin || rol == Roles.bombero) {
      // Cuenta nueva con contraseña temporal: el cambio es obligatorio
      // antes de entrar al dashboard.
      final Widget destino = resultado.debeCambiarClave
          ? PantallaCambiarClave(rolUsuario: rol!)
          : PantallaDashboard(rolUsuario: rol!);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => destino),
      );
    } else {
      UtilidadMensajes.mostrarError(context, resultado.error ?? "Error desconocido");
    }
  }

  @override
  void dispose() {
    _controladorCorreo.dispose();
    _controladorClave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TemaApp.negro,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    // ---- ZONA SUPERIOR OSCURA: identidad ----
                    Expanded(
                      flex: 4,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/images/logo.png',
                              height: 96,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              "BOMBEROS",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 6,
                                height: 1.1,
                              ),
                            ),
                            const Text(
                              "COTACACHI",
                              style: TextStyle(
                                color: TemaApp.rojo,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 6,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "Sistema de alertas de emergencia",
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ---- PANEL BLANCO INFERIOR: formulario ----
                    Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                      ),
                      padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Iniciar sesión",
                            style: TextStyle(
                              color: TemaApp.negro,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "Accede con tu cuenta institucional",
                            style: TextStyle(color: TemaApp.textoSecundario, fontSize: 13),
                          ),
                          const SizedBox(height: 24),

                          TextField(
                            controller: _controladorCorreo,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            decoration: const InputDecoration(
                              hintText: "Correo electrónico",
                              prefixIcon: Icon(Icons.alternate_email_rounded, size: 20),
                            ),
                          ),
                          const SizedBox(height: 14),

                          TextField(
                            controller: _controladorClave,
                            obscureText: _ocultarClave,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _estaCargando ? null : _procesarIngreso(),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            decoration: InputDecoration(
                              hintText: "Contraseña",
                              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _ocultarClave
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _ocultarClave = !_ocultarClave),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: _estaCargando ? null : _procesarIngreso,
                              child: _estaCargando
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2.5),
                                    )
                                  : const Text("INGRESAR"),
                            ),
                          ),

                          const SizedBox(height: 20),
                          const Center(
                            child: Text(
                              "Versión 1.0.0",
                              style: TextStyle(color: TemaApp.textoTerciario, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
