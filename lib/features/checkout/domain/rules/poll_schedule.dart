/// Calendario del sondeo de `GET /checkout/{ref}` (RNF-025, EP-24): espera
/// creciente 2, 4, 8 y 16 s y luego cada 15 s hasta los 120 s desde que
/// empezó la verificación.
abstract final class PollSchedule {
  /// Esperas iniciales, en segundos.
  static const _initial = [2, 4, 8, 16];

  /// Espera de régimen tras las iniciales.
  static const steady = Duration(seconds: 15);

  /// Tiempo máximo de verificación.
  static const deadline = Duration(seconds: 120);

  /// Espera antes de la siguiente consulta, o `null` si ya no cabe otra
  /// dentro de [deadline].
  ///
  /// [polls] es el número de consultas ya hechas (≥ 1) y [elapsed] el tiempo
  /// transcurrido desde la primera.
  static Duration? nextDelay({required int polls, required Duration elapsed}) {
    final index = polls < 1 ? 0 : polls - 1;
    final delay = index < _initial.length
        ? Duration(seconds: _initial[index])
        : steady;
    if (elapsed + delay > deadline) return null;
    return delay;
  }
}
