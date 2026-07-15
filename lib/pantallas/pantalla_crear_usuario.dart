import 'package:flutter/material.dart';
import '../config/tema_app.dart';
import '../servicios/servicio_auth.dart';
import '../config/utilidad_mensajes.dart';

class PantallaCrearUsuario extends StatefulWidget {
  const PantallaCrearUsuario({super.key});

  @override
  State<PantallaCrearUsuario> createState() => _PantallaCrearUsuarioState();
}

class _PantallaCrearUsuarioState extends State<PantallaCrearUsuario> {
  final _formKey = GlobalKey<FormState>();

  final _nombreCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  String _rolSeleccionado = Roles.bombero;
  String _rangoSeleccionado = 'Bombero Operativo';

  bool _guardando = false;
  bool _ocultarPass = true;

  final List<String> _rangos = [
    'Comandante', 'Jefe de Operaciones', 'Capitán', 'Teniente',
    'Subteniente', 'Sargento', 'Cabo', 'Bombero Operativo'
  ];

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _crearUsuario() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);

    String? error = await ServicioAuth().registrarNuevoPersonal(
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text.trim(),
      nombre: _nombreCtrl.text.trim(),
      rol: _rolSeleccionado,
      rango: _rangoSeleccionado,
    );

    if (!mounted) return;
    setState(() => _guardando = false);

    if (error == null) {
      UtilidadMensajes.mostrarExito(
          context, "¡Personal registrado! Deberá cambiar la contraseña temporal al ingresar.");
      Navigator.pop(context); // Regresa a la pantalla anterior
    } else {
      UtilidadMensajes.mostrarError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TemaApp.fondo,
      appBar: AppBar(title: const Text("Registrar personal")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Etiqueta("DATOS DEL PERFIL"),

              // NOMBRE
              TextFormField(
                controller: _nombreCtrl,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(fontWeight: FontWeight.w600),
                decoration: const InputDecoration(
                  hintText: "Nombre completo (Ej: Juan Pérez)",
                  prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                ),
                validator: (val) => val!.isEmpty ? "Ingrese el nombre" : null,
              ),
              const SizedBox(height: 14),

              // RANGO Y ROL EN FILA
              Row(
                children: [
                  Expanded(
                    flex: 6,
                    child: DropdownButtonFormField<String>(
                      initialValue: _rangoSeleccionado,
                      decoration: const InputDecoration(labelText: "Grado / Rango"),
                      items: _rangos
                          .map((r) => DropdownMenuItem(
                                value: r,
                                child: Text(r, style: const TextStyle(fontSize: 13.5)),
                              ))
                          .toList(),
                      onChanged: (val) => setState(() => _rangoSeleccionado = val!),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 4,
                    child: DropdownButtonFormField<String>(
                      initialValue: _rolSeleccionado,
                      decoration: const InputDecoration(labelText: "Permisos"),
                      items: const [
                        DropdownMenuItem(value: Roles.bombero, child: Text("Tropa")),
                        DropdownMenuItem(
                          value: Roles.admin,
                          child: Text(
                            "Admin",
                            style: TextStyle(color: TemaApp.rojo, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                      onChanged: (val) => setState(() => _rolSeleccionado = val!),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),
              const _Etiqueta("CREDENCIALES DE ACCESO"),

              // CORREO
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(fontWeight: FontWeight.w600),
                decoration: const InputDecoration(
                  hintText: "Correo institucional",
                  prefixIcon: Icon(Icons.alternate_email_rounded, size: 20),
                ),
                validator: (val) {
                  if (val!.isEmpty) return "Ingrese el correo";
                  if (!val.contains('@')) return "Correo inválido";
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // CONTRASEÑA
              TextFormField(
                controller: _passCtrl,
                obscureText: _ocultarPass,
                style: const TextStyle(fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: "Contraseña temporal",
                  helperText: "El usuario deberá cambiarla en su primer ingreso",
                  helperStyle: const TextStyle(fontSize: 11.5, color: TemaApp.textoTerciario),
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _ocultarPass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _ocultarPass = !_ocultarPass),
                  ),
                ),
                validator: (val) => val!.length < 6 ? "Mínimo 6 caracteres" : null,
              ),

              const SizedBox(height: 36),

              // BOTÓN GUARDAR
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _guardando ? null : _crearUsuario,
                  icon: _guardando
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.person_add_alt_1_rounded, size: 20),
                  label: Text(_guardando ? "REGISTRANDO..." : "CREAR CUENTA"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Etiqueta de sección en mayúsculas pequeñas, estilo del sistema.
class _Etiqueta extends StatelessWidget {
  final String texto;
  const _Etiqueta(this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 2),
      child: Text(
        texto,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 10.5,
          color: TemaApp.textoTerciario,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}
