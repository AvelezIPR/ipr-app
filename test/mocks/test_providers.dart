import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:ipr_mobile/app/providers.dart';
import 'package:ipr_mobile/core/external/external_launcher.dart';
import 'package:ipr_mobile/core/providers.dart';
import 'package:ipr_mobile/core/storage/cache_store.dart';

import 'memory_preferences_store.dart';
import 'memory_secure_key_value.dart';
import 'test_clients.dart';

/// [ExternalLauncher] de prueba: registra las URL y devuelve [result].
final class FakeExternalLauncher implements ExternalLauncher {
  new({this.result = true, List<bool>? results}) : _results = [...?results];

  bool result;
  final List<bool> _results;
  final List<Uri> opened = [];

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return _results.isEmpty ? result : _results.removeAt(0);
  }
}

/// Overrides mínimos para montar widgets y controladores de features: la
/// configuración de pruebas (`mediaHosts: staging.invalid`), almacenes en
/// memoria y un lanzador externo falso. Añade los de tu feature con
/// [extra].
List<Override> testOverrides({
  FakeExternalLauncher? launcher,
  CacheStore? cache,
  List<Override> extra = const [],
}) => [
  ...coreOverrides(
    config: testConfig,
    appVersion: '1.0.0',
    platform: 'android',
    secure: InMemorySecureKeyValue(),
    preferences: InMemoryPreferencesStore(),
    cache: cache ?? MemoryCacheStore(),
  ),
  externalLauncherProvider.overrideWithValue(
    launcher ?? FakeExternalLauncher(),
  ),
  ...extra,
];
