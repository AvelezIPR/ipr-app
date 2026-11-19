/// Analítica de producto tras una interfaz. SDK no adoptado (PA-08, jurídico
/// debe aprobar herramienta y finalidades): el adaptador por defecto no envía
/// nada.
abstract interface class AnalyticsSink {
  Future<void> track(String event, {Map<String, String> parameters});
}

final class NoOpAnalyticsSink implements AnalyticsSink {
  const new();

  @override
  Future<void> track(
    String event, {
    Map<String, String> parameters = const {},
  }) async {}
}
