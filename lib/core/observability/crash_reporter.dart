import 'package:ipr_mobile/core/observability/pii_scrubber.dart';

/// Reporte de fallos tras una interfaz (ADR-010). El proveedor concreto
/// (Crashlytics o Sentry) está **PENDIENTE (DN-02)**: mientras tanto el
/// adaptador por defecto es [NoOpCrashReporter].
abstract interface class CrashReporter {
  /// Registra un error. [message] y [stackTrace] llegan ya depurados.
  Future<void> recordError(
    String message, {
    String? stackTrace,
    bool fatal = false,
  });

  /// Migas de pan sin PII.
  Future<void> log(String message);
}

/// No hace nada: se usa mientras DN-02 siga abierta y en pruebas.
final class NoOpCrashReporter implements CrashReporter {
  const new();

  @override
  Future<void> log(String message) async {}

  @override
  Future<void> recordError(
    String message, {
    String? stackTrace,
    bool fatal = false,
  }) async {}
}

/// Envuelve cualquier [CrashReporter] y depura todo con [PiiScrubber] antes
/// de entregarlo (el proveedor nunca ve PII ni tokens).
final class ScrubbingCrashReporter {
  const new(this._delegate, [this._scrubber = const PiiScrubber()]);

  final CrashReporter _delegate;
  final PiiScrubber _scrubber;

  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    bool fatal = false,
  }) async {
    try {
      await _delegate.recordError(
        _scrubber.scrub('${error.runtimeType}: $error'),
        stackTrace: stackTrace == null
            ? null
            : _scrubber.scrub(stackTrace.toString()),
        fatal: fatal,
      );
    } on Object {
      // Un fallo del reporte nunca debe tumbar la app.
    }
  }

  Future<void> log(String message) async {
    try {
      await _delegate.log(_scrubber.scrub(message));
    } on Object {
      // Ver arriba.
    }
  }
}
