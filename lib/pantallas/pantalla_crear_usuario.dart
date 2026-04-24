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

  String _rolSeleccionado = 'bombero';
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

    setState(() => _guardando = false);

    if (error == null) {
      if (mounted) {
        UtilidadMensajes.mostrarExito(context, "¡Personal registrado exitosamente!");
        Navigator.pop(context); // Regresa a la pantalla anterior
      }
    } else {
      if (mounted) UtilidadMensajes.mostrarError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TemaApp.fondoClaro,
      appBar: AppBar(
        title: const Text("Registrar Personal", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Datos del Perfil", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              const SizedBox(height: 15),
              
              // NOMBRE
              TextFormField(
                controller: _nombreCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: "Nombre completo (Ej: Juan Pérez)",
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  filled: true, fillColor: Colors.white,
                ),
                validator: (val) => val!.isEmpty ? "Ingrese el nombre" : null,
              ),
              const SizedBox(height: 15),

              // RANGO Y ROL EN FILA
              Row(
                children: [
                  Expanded(
                    flex: 6,
                    child: DropdownButtonFormField<String>(
                      value: _rangoSeleccionado,
                      decoration: InputDecoration(
                        labelText: "Grado / Rango",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                        filled: true, fillColor: Colors.white,
                      ),
                      items: _rangos.map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 14)))).toList(),
                      onChanged: (val) => setState(() => _rangoSeleccionado = val!),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 4,
                    child: DropdownButtonFormField<String>(
                      value: _rolSeleccionado,
                      decoration: InputDecoration(
                        labelText: "Permisos",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                        filled: true, fillColor: Colors.white,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'bombero', child: Text("Tropa")),
                        DropdownMenuItem(value: 'admin', child: Text("Admin", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                      ],
                      onChanged: (val) => setState(() => _rolSeleccionado = val!),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 30),
              const Text("Credenciales de Acceso", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              const SizedBox(height: 15),

              // CORREO
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: "Correo Institucional",
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  filled: true, fillColor: Colors.white,
                ),
                validator: (val) {
                  if (val!.isEmpty) return "Ingrese el correo";
                  if (!val.contains('@')) return "Correo inválido";
                  return null;
                },
              ),
              const SizedBox(height: 15),

              // CONTRASEÑA
              TextFormField(
                controller: _passCtrl,
                obscureText: _ocultarPass,
                decoration: InputDecoration(
                  labelText: "Contraseña Temporal",
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_ocultarPass ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _ocultarPass = !_ocultarPass),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                  filled: true, fillColor: Colors.white,
                ),
                validator: (val) => val!.length < 6 ? "Mínimo 6 caracteres" : null,
              ),

              const SizedBox(height: 40),

              // BOTÓN GUARDAR
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: _guardando ? null : _crearUsuario,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  icon: _guardando 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.person_add_alt_1),
                  label: Text(_guardando ? "REGISTRANDO..." : "CREAR CUENTA", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}