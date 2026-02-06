import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../pantallas/pantalla_historial.dart';
import '../config/tema_app.dart';

class MenuLateral extends StatelessWidget {
  final String nombreUsuario;
  final String rangoUsuario;
  final VoidCallback onCerrarSesion;

  const MenuLateral({
    super.key,
    required this.nombreUsuario,
    required this.rangoUsuario,
    required this.onCerrarSesion,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      // Fondo blanco puro con una forma sutil
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topRight: Radius.circular(30), bottomRight: Radius.circular(30)),
      ),
      child: Column(
        children: [
          // --- 1. CABECERA PERSONALIZADA Y ELEGANTE ---
          Container(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F172A), // Azul noche profundo
                  TemaApp.azulInstitucional, // Azul de tu marca
                ],
              ),
              borderRadius: BorderRadius.only(bottomRight: Radius.circular(40)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fila con Avatar y Logo
                Row(
                  children: [
                    // Logo sutil en la esquina
                    Opacity(
                      opacity: 0.8,
                      child: Image.asset('assets/images/logo.png', width: 65, height: 65),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Nombre del Usuario
                Text(
                  nombreUsuario,
                  style: const TextStyle(
                    color: Colors.white, 
                    fontSize: 20, 
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                
                const SizedBox(height: 5),
                
                // Correo Electrónico
                Text(
                  FirebaseAuth.instance.currentUser?.email ?? "",
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                ),

                const SizedBox(height: 15),

                // Etiqueta de Rango (Estilo Chip)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Text(
                    rangoUsuario.toUpperCase(),
                    style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600, letterSpacing: 1),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // --- 2. LISTA DE OPCIONES ---
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Column(
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
                        Navigator.push(
                        context,
                        MaterialPageRoute(
                          // Aquí necesitamos pasar el rol. 
                          // Como MenuLateral no tiene el rol, usaremos un truco simple:
                          // Asumimos 'bombero' por defecto para visualización, 
                          // ya que el historial se ve igual para todos.
                          builder: (context) => const PantallaHistorial(rolUsuario: 'bombero')
                        )
                      );
                    },
                  ),

                  // Puedes agregar más opciones aquí fácilmente
                ],
              ),
            ),
          ),

          // --- 3. BOTÓN DE SALIDA ---
          Padding(
            padding: const EdgeInsets.all(25.0),
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
                      color: TemaApp.rojoBombero.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.logout_rounded, color: TemaApp.rojoBombero),
                        SizedBox(width: 15),
                        Text(
                          "Cerrar Sesión",
                          style: TextStyle(color: TemaApp.rojoBombero, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Bomberos Otavalo v1.0.0",
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

// Widget auxiliar para mantener el código limpio
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
            color: isSelected ? TemaApp.azulInstitucional.withOpacity(0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: [
              Icon(
                icon, 
                color: isSelected ? TemaApp.azulInstitucional : Colors.grey.shade500,
                size: 26,
              ),
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