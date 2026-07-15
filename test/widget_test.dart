import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bomberos_app/config/utilidad_iconos.dart';
import 'package:bomberos_app/config/tema_app.dart';

void main() {
  group('UtilidadIconos', () {
    test('traduce nombres conocidos a su icono', () {
      expect(UtilidadIconos.obtenerIcono('local_fire_department'), Icons.local_fire_department);
      expect(UtilidadIconos.obtenerIcono('medical_services'), Icons.medical_services);
    });

    test('devuelve icono genérico para nombres desconocidos o nulos', () {
      expect(UtilidadIconos.obtenerIcono('no_existe'), Icons.help_outline);
      expect(UtilidadIconos.obtenerIcono(null), Icons.help_outline);
    });
  });

  test('TemaApp genera un tema Material 3 con los colores del logo', () {
    final tema = TemaApp.obtenerTema();
    expect(tema.useMaterial3, isTrue);
    expect(tema.colorScheme.primary, TemaApp.rojo);
    expect(tema.colorScheme.secondary, TemaApp.negro);
  });
}
