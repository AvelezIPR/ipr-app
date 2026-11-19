/// Colombia está en UTC−5 todo el año (sin horario de verano).
const Duration bogotaOffset = Duration(hours: -5);

/// Convierte un instante cualquiera a la hora de pared de America/Bogota.
DateTime toBogota(DateTime instant) => instant.toUtc().add(bogotaOffset);

/// `dd/MM/aaaa` en hora de Colombia. Las fechas del servidor llegan en UTC
/// (`date-time`) y se muestran en hora de Colombia.
String formatDate(DateTime instant) {
  final d = toBogota(instant);
  return '${_two(d.day)}/${_two(d.month)}/${d.year.toString().padLeft(4, '0')}';
}

/// `dd/MM/aaaa HH:mm` en hora de Colombia (24 h).
String formatDateTime(DateTime instant) {
  final d = toBogota(instant);
  return '${formatDate(instant)} ${_two(d.hour)}:${_two(d.minute)}';
}

/// Interpreta una fecha ISO 8601 del contrato. `null` si es ilegible.
DateTime? tryParseServerDate(Object? value) {
  if (value is! String) return null;
  return DateTime.tryParse(value);
}

String _two(int value) => value.toString().padLeft(2, '0');
