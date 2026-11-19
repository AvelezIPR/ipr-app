/// Cancelación de una petición en vuelo, sin exponer Dio a las features
/// (D2/D6).
///
/// El controlador crea una por petición y la cancela al llegar una nueva o al
/// salir de la pantalla; `ApiClient.send(cancellation: …)` la enlaza con el
/// `CancelToken` de Dio y aborta la conexión.
final class RequestCancellation {
  new();

  final List<void Function()> _listeners = [];
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  /// Registra [listener]; si ya se canceló, se invoca de inmediato.
  void onCancel(void Function() listener) {
    if (_cancelled) {
      listener();
    } else {
      _listeners.add(listener);
    }
  }

  /// Idempotente.
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    final pending = [..._listeners];
    _listeners.clear();
    for (final listener in pending) {
      listener();
    }
  }
}
