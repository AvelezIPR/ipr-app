import 'dart:async';

import 'package:flutter/widgets.dart';

/// Avisa cuando la app vuelve a primer plano (refrescar `/config`, revocación
/// pendiente, consulta del resultado de pago).
final class AppLifecycleObserver with WidgetsBindingObserver {
  new() {
    WidgetsBinding.instance.addObserver(this);
  }

  final _foreground = StreamController<void>.broadcast();

  /// Emite cada vez que la app pasa a `resumed`.
  Stream<void> get onForeground => _foreground.stream;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _foreground.add(null);
  }

  /// Para pruebas: simula la vuelta a primer plano.
  @visibleForTesting
  void emitForeground() => _foreground.add(null);

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_foreground.close());
  }
}
