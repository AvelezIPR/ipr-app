// Providers de los servicios del núcleo. Viven en `core/` (no en `app/`) para
// que las features puedan usarlos sin violar D1 (features → shared → core).
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ipr_mobile/core/config/app_config.dart';
import 'package:ipr_mobile/core/config/remote_config_controller.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/external/external_launcher.dart';
import 'package:ipr_mobile/core/external/external_url_policy.dart';
import 'package:ipr_mobile/core/external/media_host_policy.dart';
import 'package:ipr_mobile/core/external/screen_protection.dart';
import 'package:ipr_mobile/core/external/secure_browser.dart';
import 'package:ipr_mobile/core/network/api_client.dart';
import 'package:ipr_mobile/core/network/interceptors/app_headers_interceptor.dart';
import 'package:ipr_mobile/core/network/interceptors/debug_log_interceptor.dart';
import 'package:ipr_mobile/core/network/interceptors/error_mapping_interceptor.dart';
import 'package:ipr_mobile/core/network/interceptors/retry_interceptor.dart';
import 'package:ipr_mobile/core/observability/analytics_sink.dart';
import 'package:ipr_mobile/core/observability/crash_reporter.dart';
import 'package:ipr_mobile/core/session/auth_interceptor.dart';
import 'package:ipr_mobile/core/session/session_controller.dart';
import 'package:ipr_mobile/core/session/token_store.dart';
import 'package:ipr_mobile/core/storage/cache_store.dart';
import 'package:ipr_mobile/core/storage/preferences_store.dart';
import 'package:ipr_mobile/core/storage/secure_key_value.dart';

// ── Valores que se inyectan en el arranque (override) ─────────────────────

final secureKeyValueProvider = Provider<SecureKeyValue>(
  (ref) => throw UnimplementedError('secureKeyValueProvider sin override'),
);
final preferencesStoreProvider = Provider<PreferencesStore>(
  (ref) => throw UnimplementedError('preferencesStoreProvider sin override'),
);
final cacheStoreProvider = Provider<CacheStore>(
  (ref) => throw UnimplementedError('cacheStoreProvider sin override'),
);

/// `android` o `ios`.
final platformProvider = Provider<String>(
  (ref) => throw UnimplementedError('platformProvider sin override'),
);

// ── Servicios con valor por defecto seguro ────────────────────────────────

/// Mientras DN-02 siga abierta, el reporte de fallos no envía nada.
final crashReporterProvider = Provider<ScrubbingCrashReporter>(
  (ref) => const ScrubbingCrashReporter(NoOpCrashReporter()),
);

final analyticsSinkProvider = Provider<AnalyticsSink>(
  (ref) => const NoOpAnalyticsSink(),
);

final screenProtectionProvider = Provider<ScreenProtection>(
  (ref) => const MethodChannelScreenProtection(),
);

final secureBrowserProvider = Provider<SecureBrowser>(
  (ref) => const UrlLauncherSecureBrowser(),
);

final externalLauncherProvider = Provider<ExternalLauncher>((ref) {
  final config = ref.watch(appConfigProvider);
  return UrlLauncherExternalLauncher(
    ExternalUrlPolicy(extraHttpsHosts: {config.deepLinkHost}),
  );
});

/// Hosts de imágenes permitidos (SC-043): `config/<flavor>.json` → `mediaHosts`.
final mediaHostPolicyProvider = Provider<MediaHostPolicy>(
  (ref) =>
      MediaHostPolicy(allowedHosts: ref.watch(appConfigProvider).mediaHosts),
);

final checkoutUrlPolicyProvider = Provider<CheckoutUrlPolicy>((ref) {
  return CheckoutUrlPolicy(
    localHosts: ref.watch(appConfigProvider).checkoutAllowedHosts,
  );
});

/// Acciones que otras features registran al cerrar sesión o eliminar la cuenta.
final sessionHooksProvider = Provider<List<SessionHook>>((ref) => const []);

final tokenStoreProvider = Provider<TokenStore>(
  (ref) => TokenStore(ref.watch(secureKeyValueProvider)),
);

// ── Red ───────────────────────────────────────────────────────────────────

AppHeadersInterceptor _headers(Ref ref) => AppHeadersInterceptor(
  appVersion: ref.read(appVersionProvider),
  platform: ref.read(platformProvider),
  deviceId: () => ref.read(tokenStoreProvider).deviceId(),
);

Interceptor? _debugLog(AppConfig config) =>
    config.environment.allowsDebugLogging
    ? DebugLogInterceptor((line) => developer.log(line, name: 'ipr.http'))
    : null;

/// Cliente SIN `AuthInterceptor`: lo usa la propia sesión para refrescar y
/// revocar sin recursión.
final bareApiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(appConfigProvider);
  return ApiClient.build(
    config: config,
    interceptors: (dio) => [
      _headers(ref),
      RetryInterceptor(dio: dio),
      ErrorMappingInterceptor(),
      ?_debugLog(config),
    ],
  );
});

/// Cliente de la app: orden estricto de interceptores
/// (`flutter_app_architecture.md` §7.2): cabeceras → auth → reintentos →
/// mapeo de errores → depuración (solo dev/staging).
final apiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(appConfigProvider);
  final session = ref.watch(sessionControllerProvider.notifier);
  return ApiClient.build(
    config: config,
    interceptors: (dio) => [
      _headers(ref),
      AuthInterceptor(gateway: session, dio: dio),
      RetryInterceptor(dio: dio),
      ErrorMappingInterceptor(
        onFailure: (failure) {
          if (failure is UpgradeRequired) {
            ref.read(remoteConfigProvider.notifier).markUpgradeRequired();
          }
        },
      ),
      ?_debugLog(config),
    ],
  );
});
