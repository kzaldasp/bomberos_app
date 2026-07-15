import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../pantallas/pantalla_historial.dart';
import '../pantallas/pantalla_gestion_roles.dart';
import '../pantallas/pantalla_crear_evento.dart';
import '../pantallas/pantalla_lista_eventos.dart';
import '../pantallas/pantalla_personal_guardia.dart';
import '../servicios/servicio_auth.dart';
import '../config/tema_app.dart';

class MenuLateral extends StatelessWidget {
  final String nombreUsuario;
  final String rangoUsuario;
  final String rolUsuario;
  final VoidCallback onCerrarSesion;

  const MenuLateral({
    super.key,
    required this.nombreUsuario,
    required this.rangoUsuario,
    required this.rolUsuario,
    required this.onCerrarSesion,
  });

  void _ir(BuildContext context, Widget pantalla) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));
  }

  @override
  Widget build(BuildContext context) {
    final String correo = FirebaseAuth.instance.currentUser?.email ?? "";
    final String inicial = nombreUsuario.isNotEmpty ? nombreUsuario[0].toUpperCase() : "B";

    return Drawer(
      backgroundColor: TemaApp.superficie,
      shape: const RoundedRectangleBorder(), // Bordes rectos: limpio y sobrio
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ---- CABECERA: perfil sobre negro carbón con acento rojo ----
            Container(
              color: TemaApp.negro,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: TemaApp.rojo,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          inicial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nombreUsuario,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              correo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.55),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Insignia de rango sobre línea roja
                  Row(
                    children: [
                      Container(
                        width: 3,
                        height: 14,
                        decoration: BoxDecoration(
                          color: TemaApp.rojo,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        rangoUsuario.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.6,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ---- NAVEGACIÓN ----
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 18, 14, 10),
                children: [
                  const _TituloSeccion("OPERACIONES"),
                  _ItemMenu(
                    icono: Icons.grid_view_rounded,
                    texto: "Central de alertas",
                    activo: true,
                    onTap: () => Navigator.pop(context),
                  ),
                  _ItemMenu(
                    icono: Icons.history_rounded,
                    texto: "Historial operativo",
                    onTap: () => _ir(context, PantallaHistorial(rolUsuario: rolUsuario)),
                  ),
                  _ItemMenu(
                    icono: Icons.calendar_month_rounded,
                    texto: "Eventos institucionales",
                    onTap: () => _ir(context, const PantallaListaEventos()),
                  ),

                  if (rolUsuario == Roles.admin) ...[
                    const SizedBox(height: 18),
                    const _TituloSeccion("ADMINISTRACIÓN"),
                    _ItemMenu(
                      icono: Icons.group_rounded,
                      texto: "Gestión de personal",
                      onTap: () => _ir(context, const PantallaGestionRoles()),
                    ),
                    _ItemMenu(
                      icono: Icons.local_fire_department_rounded,
                      texto: "Personal de guardia",
                      onTap: () => _ir(context, const PantallaPersonalGuardia()),
                    ),
                    _ItemMenu(
                      icono: Icons.event_available_rounded,
                      texto: "Agendar evento",
                      onTap: () => _ir(context, const PantallaCrearEvento()),
                    ),
                  ],
                ],
              ),
            ),

            // ---- PIE: cerrar sesión + versión ----
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ItemMenu(
                    icono: Icons.logout_rounded,
                    texto: "Cerrar sesión",
                    esDestructivo: true,
                    onTap: onCerrarSesion,
                  ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      "Bomberos Cotacachi · v1.0.0",
                      style: TextStyle(
                        color: TemaApp.textoTerciario,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TituloSeccion extends StatelessWidget {
  final String texto;
  const _TituloSeccion(this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Text(
        texto,
        style: const TextStyle(
          color: TemaApp.textoTerciario,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

class _ItemMenu extends StatelessWidget {
  final IconData icono;
  final String texto;
  final bool activo;
  final bool esDestructivo;
  final VoidCallback onTap;

  const _ItemMenu({
    required this.icono,
    required this.texto,
    required this.onTap,
    this.activo = false,
    this.esDestructivo = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color colorContenido = esDestructivo
        ? TemaApp.rojo
        : (activo ? TemaApp.rojo : TemaApp.textoSecundario);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: activo ? TemaApp.rojoSuave : Colors.transparent,
        borderRadius: BorderRadius.circular(TemaApp.radio),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(TemaApp.radio),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
            child: Row(
              children: [
                Icon(icono, color: colorContenido, size: 21),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    texto,
                    style: TextStyle(
                      color: esDestructivo
                          ? TemaApp.rojo
                          : (activo ? TemaApp.negro : TemaApp.textoSecundario),
                      fontWeight: activo || esDestructivo ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (activo)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(color: TemaApp.rojo, shape: BoxShape.circle),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
