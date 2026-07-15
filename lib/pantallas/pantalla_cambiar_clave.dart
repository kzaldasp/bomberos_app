import 'package:flutter/material.dart';
import '../config/tema_app.dart';
import '../config/utilidad_mensajes.dart';
import '../servicios/servicio_auth.dart';
import 'pantalla_dashboard.dart';
import 'pantalla_login.dart';

/// Cambio de contraseña OBLIGATORIO en el primer ingreso.
///
/// Se muestra cuando el perfil tiene `debe_cambiar_clave: true` (cuenta
/// recién creada por un admin con contraseña temporal). No se puede
/// evadir: sin botón atrás, la única alternativa es cerrar sesión.
class PantallaCambiarClave extends StatefulWidget {
  final String rolUsuario;

  const PantallaCambiarClave({super.key, required this.rolUsuario});

  @override
  State<PantallaCambiarClave> createState() => _PantallaCambiarClaveState();
}

class _PantallaCambiarClaveState extends State<PantallaCambiarClave> {
  final _formKey = GlobalKey<FormState>();
  final _actualCtrl = TextEditingController();
  final _nuevaCtrl = TextEditingController();
  final _confirmarCtrl = TextEditingController();

  bool _guardando = false;
  bool _ocultarActual = true;
  bool _ocultarNueva = true;

  @override
  void dispose() {
    _actualCtrl.dispose();
    _nuevaCtrl.dispose();
    _confirmarCtrl.dispose();
    super.dispose();
  }

  void _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);
    final error = await ServicioAuth().cambiarClave(
      actual: _actualCtrl.text.trim(),
      nueva: _nuevaCtrl.text.trim(),
    );
    if (!mounted) return;

    if (error != null) {
      setState(() => _guardando = false);
      UtilidadMensajes.mostrarError(context, error);
      return;
    }

    UtilidadMensajes.mostrarExito(context, "Contraseña actualizada. ¡Bienvenido!");
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => PantallaDashboard(rolUsuario: widget.rolUsuario),
      ),
    );
  }

  void _cerrarSesion() async {
    await ServicioAuth().cerrarSesion();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const PantallaLogin()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Bloquea el botón/gesto de "atrás": el cambio es obligatorio.
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: TemaApp.fondo,
        appBar: AppBar(
          title: const Text("Contraseña temporal"),
          automaticallyImplyLeading: false,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: TemaApp.superficie,
                    borderRadius: BorderRadius.circular(TemaApp.radio),
                    border: Border.all(color: TemaApp.borde),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.shield_outlined, color: TemaApp.rojo, size: 26),
                      SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          "Tu cuenta fue creada con una contraseña temporal. "
                          "Por seguridad, define una nueva antes de continuar.",
                          style: TextStyle(
                            fontSize: 13.5,
                            color: TemaApp.textoSecundario,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                TextFormField(
                  controller: _actualCtrl,
                  obscureText: _ocultarActual,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: "Contraseña temporal (actual)",
                    prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _ocultarActual ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _ocultarActual = !_ocultarActual),
                    ),
                  ),
                  validator: (val) =>
                      (val == null || val.isEmpty) ? "Ingresa tu contraseña actual" : null,
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _nuevaCtrl,
                  obscureText: _ocultarNueva,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: "Nueva contraseña (mínimo 6 caracteres)",
                    prefixIcon: const Icon(Icons.key_rounded, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _ocultarNueva ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _ocultarNueva = !_ocultarNueva),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().length < 6) return "Mínimo 6 caracteres";
                    if (val.trim() == _actualCtrl.text.trim()) {
                      return "Debe ser distinta a la contraseña temporal";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _confirmarCtrl,
                  obscureText: _ocultarNueva,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    hintText: "Confirmar la nueva contraseña",
                    prefixIcon: Icon(Icons.key_rounded, size: 20),
                  ),
                  validator: (val) =>
                      val != _nuevaCtrl.text ? "Las contraseñas no coinciden" : null,
                ),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _guardando ? null : _guardar,
                    icon: _guardando
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded, size: 20),
                    label: Text(_guardando ? "GUARDANDO..." : "GUARDAR Y CONTINUAR"),
                  ),
                ),
                const SizedBox(height: 12),

                Center(
                  child: TextButton(
                    onPressed: _guardando ? null : _cerrarSesion,
                    child: const Text(
                      "Cerrar sesión",
                      style: TextStyle(color: TemaApp.textoSecundario, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
