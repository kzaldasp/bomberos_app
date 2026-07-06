import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../pantallas/pantalla_historial.dart';
import '../pantallas/pantalla_gestion_roles.dart';
import '../pantallas/pantalla_crear_evento.dart';
import '../pantallas/pantalla_lista_eventos.dart';
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

  @override
  Widget build(BuildContext context) {
    return Drawer(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topRight: Radius.circular(30), bottomRight: Radius.circular(30)),
      ),
      child: Column(
        children: [
          // 1. CABECERA (Fija arriba)
          Container(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F172A), TemaApp.azulInstitucional],
              ),
              borderRadius: BorderRadius.only(bottomRight: Radius.circular(40)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Opacity(
                  opacity: 0.8,
                  child: Image.asset('assets/images/logo.png', width: 65, height: 65),
                ),
                const SizedBox(height: 20),
                Text(
                  nombreUsuario,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Text(
                  FirebaseAuth.instance.currentUser?.email ?? "",
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                ),
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Text(
                    rangoUsuario.toUpperCase(),
                    style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600, letterSpacing: 1),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 10),

          // 2. LISTA DE OPCIONES (Deslizable / Scrollable)
          Expanded(
            // ✅ CORRECCIÓN: Cambiamos Column por ListView para evitar el desbordamiento
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 0),
              children: [
                _ItemMenu(
                  icon: Icons.dashboard_rounded,
                  text: "Tablero Principal",
                  isSelected: true,
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(height: 10),
                _ItemMenu(
                  icon: Icons.history_rounded,
                  text: "Historial de Guardias",
                  isSelected: false,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => PantallaHistorial(rolUsuario: rolUsuario)),
                    );
                  },
                ),
                const SizedBox(height: 10),
                _ItemMenu(
                  icon: Icons.calendar_today_rounded,
                  text: "Eventos Institucionales",
                  isSelected: false,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const PantallaListaEventos()));
                  },
                ),
                const SizedBox(height: 10),

                // OPCIONES EXCLUSIVAS PARA ADMINISTRADORES
                if (rolUsuario == Roles.admin) ...[
                  _ItemMenu(
                    icon: Icons.manage_accounts_rounded,
                    text: "Gestión de Personal",
                    isSelected: false,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const PantallaGestionRoles()));
                    },
                  ),
                  const SizedBox(height: 10),
                  _ItemMenu(
                    icon: Icons.event_available_rounded,
                    text: "Agendar Evento",
                    isSelected: false,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const PantallaCrearEvento()));
                    },
                  ),
                ],
              ],
            ),
          ),

          // 3. BOTÓN DE SALIDA (Fijo abajo)
          Padding(
            padding: const EdgeInsets.all(20.0), // Reduje un poco el padding para pantallas muy pequeñas
            child: Column(
              children: [
                const Divider(),
                const SizedBox(height: 10),
                InkWell(
                  onTap: onCerrarSesion,
                  borderRadius: BorderRadius.circular(15),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                    decoration: BoxDecoration(
                      color: TemaApp.rojoBombero.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.logout_rounded, color: TemaApp.rojoBombero),
                        SizedBox(width: 15),
                        Text("Cerrar Sesión", style: TextStyle(color: TemaApp.rojoBombero, fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  "Bomberos v1.0.0",
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// WIDGET AUXILIAR
class _ItemMenu extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  const _ItemMenu({
    required this.icon,
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
          decoration: BoxDecoration(
            color: isSelected ? TemaApp.azulInstitucional.withValues(alpha: 0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: [
              Icon(icon, color: isSelected ? TemaApp.azulInstitucional : Colors.grey.shade500, size: 26),
              const SizedBox(width: 15),
              Text(
                text,
                style: TextStyle(
                  color: isSelected ? TemaApp.azulInstitucional : Colors.grey.shade700,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}