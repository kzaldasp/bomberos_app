import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Mantiene el catálogo base de tipos de emergencia en Firestore.
///
/// Las categorías se administran desde la colección `categorias`, pero si
/// alguna de las básicas aún no existe (p. ej. instalación nueva o pedidos
/// del cuerpo de bomberos como "Rescate" u "Otros"), un admin la crea
/// automáticamente al abrir la pantalla de selección.
class ServicioCategorias {
  static const Map<String, Map<String, dynamic>> _categoriasBase = {
    'rescate': {
      'nombre': 'Rescate',
      'importancia': 'ALTA',
      'color': '#00897B',
      'icono': 'support',
    },
    'desastre_natural': {
      'nombre': 'Desastres Naturales',
      'importancia': 'ALTA',
      'color': '#6D4C41',
      'icono': 'landslide',
    },
    'otros': {
      'nombre': 'Otros',
      'importancia': 'MEDIA',
      'color': '#546E7A',
      'icono': 'more_horiz',
    },
  };

  /// Crea las categorías base que falten. Solo debe llamarse con un admin
  /// logueado (las reglas de Firestore rechazan la escritura a los demás).
  Future<void> asegurarCategoriasBase() async {
    try {
      final coleccion = FirebaseFirestore.instance.collection('categorias');
      final existentes = await coleccion.get();

      final idsExistentes = existentes.docs.map((d) => d.id).toSet();
      final nombresExistentes = existentes.docs
          .map((d) => (d.data()['nombre'] ?? '').toString().trim().toLowerCase())
          .toSet();

      final batch = FirebaseFirestore.instance.batch();
      var hayNuevas = false;

      _categoriasBase.forEach((id, datos) {
        final nombre = (datos['nombre'] as String).toLowerCase();
        if (!idsExistentes.contains(id) && !nombresExistentes.contains(nombre)) {
          batch.set(coleccion.doc(id), datos);
          hayNuevas = true;
        }
      });

      if (hayNuevas) await batch.commit();
    } catch (e) {
      // Sin conexión o sin permisos: la pantalla sigue mostrando las que haya.
      debugPrint('No se pudieron sembrar las categorías base: $e');
    }
  }
}
