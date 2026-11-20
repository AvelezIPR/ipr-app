import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:ipr_mobile/core/config/app_config.dart';
import 'package:ipr_mobile/core/config/remote_config_controller.dart';
import 'package:ipr_mobile/core/config/remote_config_repository.dart';
import 'package:ipr_mobile/core/providers.dart';
import 'package:ipr_mobile/core/session/session_controller.dart';
import 'package:ipr_mobile/core/session/session_remote.dart';
import 'package:ipr_mobile/core/storage/cache_store.dart';
import 'package:ipr_mobile/core/storage/durable_store.dart';
import 'package:ipr_mobile/core/storage/preferences_store.dart';
import 'package:ipr_mobile/core/storage/secure_key_value.dart';
import 'package:ipr_mobile/features/cart/cart.dart';
import 'package:ipr_mobile/features/checkout/checkout.dart';
import 'package:ipr_mobile/features/home/home.dart';
import 'package:ipr_mobile/features/product_detail/product_detail.dart';

/// Overrides que cablean el núcleo con los valores del arranque. Se usan en
/// `bootstrap` y en las pruebas de la app.
List<Override> coreOverrides({
  required AppConfig config,
  required String appVersion,
  required String platform,
  required SecureKeyValue secure,
  required PreferencesStore preferences,
  required CacheStore cache,
  required DurableStore durable,
}) => [
  appConfigProvider.overrideWithValue(config),
  appVersionProvider.overrideWithValue(appVersion),
  platformProvider.overrideWithValue(platform),
  secureKeyValueProvider.overrideWithValue(secure),
  preferencesStoreProvider.overrideWithValue(preferences),
  cacheStoreProvider.overrideWithValue(cache),
  durableStoreProvider.overrideWithValue(durable),
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

/// Cableado entre features (M3), solo para la app real: el carrito reacciona
/// a la cuenta (`CartRetentionPolicy`), el pago borra su intento al cerrar
/// sesión y la ficha añade al carrito real. Va aparte de [coreOverrides] para
/// que las pruebas de cada feature puedan registrar sus propios dobles.
List<Override> integrationOverrides() => [
  sessionHooksProvider.overrideWith(
    (ref) => [
      ref.watch(cartSessionHookProvider),
      ref.watch(checkoutSessionHookProvider),
    ],
  ),
  ...productDetailCartOverrides,
  homeCartCountProvider.overrideWith((ref) => ref.watch(cartUnitCountProvider)),
];
