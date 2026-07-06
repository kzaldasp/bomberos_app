import 'package:intl/intl.dart';

/// Formatos de fecha/hora centralizados para toda la app.
/// Evita los "9:5" por no rellenar con ceros y unifica el estilo.
class UtilidadFormato {
  static final DateFormat _hora = DateFormat('HH:mm');
  static final DateFormat _fechaCorta = DateFormat('dd/MM');
  static final DateFormat _fechaCompleta = DateFormat('dd/MM/yyyy');

  /// "14:05"
  static String hora(DateTime fecha) => _hora.format(fecha);

  /// "06/07/2026"
  static String fecha(DateTime fecha) => _fechaCompleta.format(fecha);

  /// Si es de hoy muestra solo la hora ("14:05"),
  /// si es de otro día antepone la fecha ("04/07 · 14:05").
  static String horaInteligente(DateTime fecha) {
    final ahora = DateTime.now();
    final esHoy = fecha.year == ahora.year &&
        fecha.month == ahora.month &&
        fecha.day == ahora.day;
    return esHoy ? _hora.format(fecha) : '${_fechaCorta.format(fecha)} · ${_hora.format(fecha)}';
  }

  /// "Hace 5 min", "Hace 2 h", o la fecha si es muy antiguo.
  static String tiempoRelativo(DateTime fecha) {
    final diferencia = DateTime.now().difference(fecha);
    if (diferencia.inMinutes < 1) return 'Ahora mismo';
    if (diferencia.inMinutes < 60) return 'Hace ${diferencia.inMinutes} min';
    if (diferencia.inHours < 24) return 'Hace ${diferencia.inHours} h';
    return _fechaCompleta.format(fecha);
  }
}
