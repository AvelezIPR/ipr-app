import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:ipr_mobile/core/config/app_config.dart';
import 'package:ipr_mobile/core/config/remote_config_controller.dart';
import 'package:ipr_mobile/core/config/remote_config_repository.dart';
import 'package:ipr_mobile/core/providers.dart';
import 'package:ipr_mobile/core/session/session_controller.dart';
import 'package:ipr_mobile/core/session/session_remote.dart';
import 'package:ipr_mobile/core/storage/cache_store.dart';
import 'package:ipr_mobile/core/storage/preferences_store.dart';
import 'package:ipr_mobile/core/storage/secure_key_value.dart';

/// Overrides que cablean el núcleo con los valores del arranque. Se usan en
/// `bootstrap` y en las pruebas de la app.
List<Override> coreOverrides({
  required AppConfig config,
  required String appVersion,
  required String platform,
  required SecureKeyValue secure,
  required PreferencesStore preferences,
  required CacheStore cache,
}) => [
  appConfigProvider.overrideWithValue(config),
  appVersionProvider.overrideWithValue(appVersion),
  platformProvider.overrideWithValue(platform),
  secureKeyValueProvider.overrideWithValue(secure),
  preferencesStoreProvider.overrideWithValue(preferences),
  cacheStoreProvider.overrideWithValue(cache),
  sessionDependenciesProvider.overrideWith(
    (ref) => SessionDependencies(
      tokenStore: ref.watch(tokenStoreProvider),
      remote: ApiSessionRemote(ref.watch(bareApiClientProvider)),
      hooks: ref.watch(sessionHooksProvider),
    ),
  ),
  remoteConfigRepositoryProvider.overrideWith(
    (ref) => RemoteConfigRepository(
      client: ref.watch(apiClientProvider),
      cache: ref.watch(cacheStoreProvider),
      platform: ref.watch(platformProvider),
    ),
  ),
];
