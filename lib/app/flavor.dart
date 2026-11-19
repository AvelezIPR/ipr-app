import 'package:ipr_mobile/core/config/app_config.dart';

/// Un punto de entrada por flavor (`main_dev|staging|prod.dart`).
///
/// La configuración PÚBLICA llega por `--dart-define-from-file` con el JSON
/// de `config/` del flavor (ADR-009). El flavor y el JSON deben coincidir: si no, la app no
/// arranca (evita apuntar a producción desde un build de pruebas).
enum Flavor {
  dev(AppEnvironment.dev),
  staging(AppEnvironment.staging),
  prod(AppEnvironment.prod);

  new(this.environment);

  final AppEnvironment environment;

  /// Lee y valida los `--dart-define`; lanza [FormatException] si falta algo
  /// o si el JSON corresponde a otro entorno.
  AppConfig loadConfig() {
    final config = AppConfig.fromEnvironment();
    if (config.environment != environment) {
      throw FormatException(
        'El flavor $name no coincide con config/'
        '${config.environment.name}.json',
      );
    }
    return config;
  }
}
