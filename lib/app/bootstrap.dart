import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ipr_mobile/app/app.dart';
import 'package:ipr_mobile/app/flavor.dart';
import 'package:ipr_mobile/app/providers.dart';
import 'package:ipr_mobile/core/config/remote_config_controller.dart';
import 'package:ipr_mobile/core/lifecycle/app_lifecycle_observer.dart';
import 'package:ipr_mobile/core/providers.dart';
import 'package:ipr_mobile/core/session/session_controller.dart';
import 'package:ipr_mobile/core/storage/cache_store.dart';
import 'package:ipr_mobile/core/storage/durable_store.dart';
import 'package:ipr_mobile/core/storage/hive_bootstrap.dart';
import 'package:ipr_mobile/core/storage/preferences_store.dart';
import 'package:ipr_mobile/core/storage/secure_key_value.dart';
import 'package:ipr_mobile/core/storage/storage_hygiene.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Arranque común de los tres flavors: valida la configuración pública,
/// prepara el almacenamiento, engancha los errores globales al reporte
/// (depurado de PII) y lanza la app.
Future<void> bootstrap(Flavor flavor) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Falla rápido si falta configuración o corresponde a otro entorno.
  final config = flavor.loadConfig();

  final prefs = SharedPreferencesStore(await SharedPreferences.getInstance());
  final secure = FlutterSecureKeyValue();
  await clearSecureStorageOnFirstLaunch(preferences: prefs, secure: secure);
  final cache = HiveCacheStore(await openCacheBox());
  final durable = HiveDurableStore(await openCartBox());

  final info = await PackageInfo.fromPlatform();
  final version = info.version.split('+').first;

  final container = ProviderContainer(
    overrides: coreOverrides(
      config: config,
      appVersion: version,
      platform: Platform.isIOS ? 'ios' : 'android',
      secure: secure,
      preferences: prefs,
      cache: cache,
      durable: durable,
    )..addAll(integrationOverrides()),
  );

  _installErrorHooks(container);

  // Sesión y configuración antes del primer cuadro (sin bloquear por red).
  await container.read(sessionControllerProvider.notifier).restore();
  final remote = container.read(remoteConfigProvider.notifier);
  await remote.loadCached();
  unawaited(remote.refreshIfStale());

  final lifecycle = AppLifecycleObserver();
  lifecycle.onForeground.listen((_) {
    unawaited(remote.refreshIfStale());
    unawaited(
      container
          .read(sessionControllerProvider.notifier)
          .retryPendingRevocation(),
    );
  });

  runApp(
    UncontrolledProviderScope(container: container, child: const IprApp()),
  );
}

/// Errores globales → `CrashReporter` con depuración de PII; nunca se muestran
/// trazas al usuario (RNF-027).
void _installErrorHooks(ProviderContainer container) {
  final reporter = container.read(crashReporterProvider);
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    unawaited(reporter.recordError(details.exception, details.stack));
    if (kDebugMode) previous?.call(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(reporter.recordError(error, stack, fatal: true));
    return true;
  };
  if (kReleaseMode) {
    ErrorWidget.builder = (_) => const SizedBox.shrink();
  }
}
