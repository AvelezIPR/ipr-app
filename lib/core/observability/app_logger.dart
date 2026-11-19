import 'dart:developer' as developer;

import 'package:ipr_mobile/core/config/app_config.dart';

/// Registro de depuración. En `prod` está desactivado (SC-045) y en ningún
/// entorno recibe tokens, cuerpos ni datos personales.
final class AppLogger {
  const new({required this.enabled});

  factory forEnvironment(AppEnvironment environment) =>
      AppLogger(enabled: environment.allowsDebugLogging);

  final bool enabled;

  void debug(String message) {
    if (!enabled) return;
    developer.log(message, name: 'ipr');
  }
}
