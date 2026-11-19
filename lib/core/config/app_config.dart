/// Entorno de ejecución (un `main_*.dart` por flavor).
enum AppEnvironment {
  dev,
  staging,
  prod;

  static AppEnvironment parse(String value) => AppEnvironment.values.firstWhere(
    (e) => e.name == value,
    orElse: () => throw FormatException('Entorno desconocido: "$value"'),
  );

  /// Solo dev y staging pueden registrar trazas de depuración (SC-045).
  bool get allowsDebugLogging => this != AppEnvironment.prod;
}

/// Configuración PÚBLICA por flavor, inyectada con
/// `--dart-define-from-file=config/<flavor>.json` (ADR-009). Nunca contiene
/// secretos (SC-038): `ci/check_public_config.dart` lo verifica.
final class AppConfig {
  const new({
    required this.environment,
    required this.apiBaseUrl,
    required this.deepLinkHost,
    required this.checkoutAllowedHosts,
    required this.mediaHosts,
    required this.supportWhatsApp,
  });

  /// Lee los `--dart-define` del build. Falla rápido si falta alguno.
  factory fromEnvironment() => AppConfig.fromMap(const {
    'environment': String.fromEnvironment('environment'),
    'apiBaseUrl': String.fromEnvironment('apiBaseUrl'),
    'deepLinkHost': String.fromEnvironment('deepLinkHost'),
    'checkoutAllowedHosts': String.fromEnvironment('checkoutAllowedHosts'),
    'mediaHosts': String.fromEnvironment('mediaHosts'),
    'supportWhatsApp': String.fromEnvironment('supportWhatsApp'),
  });

  /// Construye y valida la configuración desde un mapa de cadenas.
  factory fromMap(Map<String, String> map) {
    String required(String key) {
      final value = map[key]?.trim() ?? '';
      if (value.isEmpty) {
        throw FormatException(
          'Falta la configuración "$key". Ejecuta con '
          '--dart-define-from-file=config/<flavor>.json',
        );
      }
      return value;
    }

    final environment = AppEnvironment.parse(required('environment'));
    final apiBaseUrl = Uri.parse(required('apiBaseUrl'));
    final isLocalDev =
        environment == AppEnvironment.dev &&
        (apiBaseUrl.scheme == 'http' || apiBaseUrl.scheme == 'https');
    if (apiBaseUrl.scheme != 'https' && !isLocalDev) {
      throw FormatException(
        'apiBaseUrl debe usar https fuera del entorno dev: $apiBaseUrl',
      );
    }
    Set<String> hostList(String key) {
      final hosts = required(key)
          .split(',')
          .map((h) => h.trim().toLowerCase())
          .where((h) => h.isNotEmpty)
          .toSet();
      if (hosts.isEmpty) {
        throw FormatException('$key no puede estar vacío');
      }
      return Set.unmodifiable(hosts);
    }

    return AppConfig(
      environment: environment,
      apiBaseUrl: apiBaseUrl,
      deepLinkHost: required('deepLinkHost').toLowerCase(),
      checkoutAllowedHosts: hostList('checkoutAllowedHosts'),
      mediaHosts: hostList('mediaHosts'),
      supportWhatsApp: required('supportWhatsApp'),
    );
  }

  final AppEnvironment environment;
  final Uri apiBaseUrl;

  /// Único host cuyos enlaces profundos acepta la app (SC-067).
  final String deepLinkHost;

  /// Hosts locales permitidos para abrir el checkout (CR-016).
  final Set<String> checkoutAllowedHosts;

  /// Hosts https de los que la app descarga imágenes de producto (SC-043).
  /// Una imagen de cualquier otro host no se carga.
  final Set<String> mediaHosts;

  /// Número público de respaldo si `/config` aún no se ha cargado.
  final String supportWhatsApp;
}
