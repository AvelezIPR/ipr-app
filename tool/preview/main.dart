// SOLO PARA PREVISUALIZAR en Chrome (no es un flavor ni se publica).
// Arranca la app con almacenamiento en memoria contra el BFF simulado
// (`dart run tool/mock_bff/main.dart`). Los datos son ejemplos sintetizados
// del contrato, no productos reales.
//
//   flutter run -d chrome -t tool/preview/main.dart
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ipr_mobile/app/app.dart';
import 'package:ipr_mobile/app/providers.dart';
import 'package:ipr_mobile/core/config/app_config.dart';
import 'package:ipr_mobile/core/config/remote_config_controller.dart';
import 'package:ipr_mobile/core/session/session_controller.dart';
import 'package:ipr_mobile/core/storage/cache_store.dart';
import 'package:ipr_mobile/core/storage/durable_store.dart';
import 'package:ipr_mobile/core/storage/preferences_store.dart';
import 'package:ipr_mobile/core/storage/secure_key_value.dart';

final class MemoryPrefs implements PreferencesStore {
  final Map<String, Object> _data = {};

  @override
  bool? getBool(String key) => _data[key] as bool?;

  @override
  Future<void> setBool(String key, {required bool value}) async =>
      _data[key] = value;

  @override
  String? getString(String key) => _data[key] as String?;

  @override
  Future<void> setString(String key, String value) async => _data[key] = value;

  @override
  Future<void> remove(String key) async => _data.remove(key);
}

final class MemorySecure implements SecureKeyValue {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;

  @override
  Future<void> delete(String key) async => _data.remove(key);

  @override
  Future<void> deleteAll() async => _data.clear();
}

ProviderContainer createPreviewContainer({
  String apiBaseUrl = 'http://127.0.0.1:8787/mobile/v1',
  SecureKeyValue? secure,
  PreferencesStore? preferences,
  CacheStore? cache,
  DurableStore? durable,
}) {
  final config = AppConfig.fromMap({
    'environment': 'dev',
    'apiBaseUrl': apiBaseUrl,
    'deepLinkHost': 'dev.invalid',
    'checkoutAllowedHosts': 'dev.invalid',
    'mediaHosts': 'dev.invalid',
    'supportWhatsApp': '573000000000',
  });
  return ProviderContainer(
    overrides: coreOverrides(
      config: config,
      appVersion: '1.0.0',
      platform: 'android',
      secure: secure ?? MemorySecure(),
      preferences: preferences ?? MemoryPrefs(),
      cache: cache ?? MemoryCacheStore(),
      durable: durable ?? MemoryDurableStore(),
    )..addAll(integrationOverrides()),
  );
}

Future<void> bootstrapPreviewContainer(ProviderContainer container) async {
  await container.read(sessionControllerProvider.notifier).restore();
  final remote = container.read(remoteConfigProvider.notifier);
  await remote.loadCached();
  unawaited(remote.refreshIfStale());
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = createPreviewContainer();
  await bootstrapPreviewContainer(container);
  runApp(
    UncontrolledProviderScope(container: container, child: const IprApp()),
  );
}
