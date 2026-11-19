import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ipr_mobile/core/config/app_config.dart';
import 'package:ipr_mobile/core/config/app_version.dart';
import 'package:ipr_mobile/core/config/remote_config.dart';
import 'package:ipr_mobile/core/config/remote_config_repository.dart';
import 'package:ipr_mobile/core/network/result.dart';

/// Configuración pública del flavor (override en el arranque).
final appConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError('appConfigProvider sin override'),
);

/// Versión instalada de la app `x.y.z` (override en el arranque).
final appVersionProvider = Provider<String>(
  (ref) => throw UnimplementedError('appVersionProvider sin override'),
);

final remoteConfigRepositoryProvider = Provider<RemoteConfigRepository>(
  (ref) => throw UnimplementedError('remoteConfigRepositoryProvider'),
);

/// Estado de la configuración remota.
final class RemoteConfigState {
  const new({
    required this.config,
    required this.source,
    this.fetchedAt,
    this.upgradeRequiredBy426 = false,
  });

  final RemoteConfig config;
  final RemoteConfigSource source;
  final DateTime? fetchedAt;

  /// Algún endpoint respondió 426 `app_version_unsupported`.
  final bool upgradeRequiredBy426;

  RemoteConfigState copyWith({
    RemoteConfig? config,
    RemoteConfigSource? source,
    DateTime? fetchedAt,
    bool? upgradeRequiredBy426,
  }) => RemoteConfigState(
    config: config ?? this.config,
    source: source ?? this.source,
    fetchedAt: fetchedAt ?? this.fetchedAt,
    upgradeRequiredBy426: upgradeRequiredBy426 ?? this.upgradeRequiredBy426,
  );
}

final remoteConfigProvider =
    NotifierProvider<RemoteConfigController, RemoteConfigState>(
      RemoteConfigController.new,
    );

/// Mantiene `/config` fresco: se refresca al arrancar y al volver a primer
/// plano si pasaron más de 5 minutos (RNF-029). Sin red conserva el último
/// valor conocido.
class RemoteConfigController extends Notifier<RemoteConfigState> {
  static const staleAfter = Duration(minutes: 5);

  DateTime Function() clock = DateTime.now;

  @override
  RemoteConfigState build() => RemoteConfigState(
    config: RemoteConfig.defaults(ref.read(appConfigProvider)),
    source: RemoteConfigSource.defaults,
  );

  /// Carga el último valor guardado (arranque sin red).
  Future<void> loadCached() async {
    final cached = await ref.read(remoteConfigRepositoryProvider).readCached();
    if (cached != null && state.source == RemoteConfigSource.defaults) {
      state = state.copyWith(config: cached, source: RemoteConfigSource.cache);
    }
  }

  /// Refresca si nunca se cargó o si pasaron más de [staleAfter].
  Future<void> refreshIfStale() async {
    final fetchedAt = state.fetchedAt;
    if (fetchedAt != null && clock().difference(fetchedAt) < staleAfter) {
      return;
    }
    await refresh();
  }

  Future<void> refresh() async {
    final result = await ref.read(remoteConfigRepositoryProvider).fetch();
    if (result case Ok<RemoteConfig>(:final value)) {
      state = state.copyWith(
        config: value,
        source: RemoteConfigSource.network,
        fetchedAt: clock(),
      );
    }
  }

  /// Lo llama el interceptor de errores ante un 426.
  void markUpgradeRequired() {
    if (!state.upgradeRequiredBy426) {
      state = state.copyWith(upgradeRequiredBy426: true);
    }
  }
}

/// `true` si hay que mostrar `/update-required`: versión por debajo del
/// mínimo remoto o 426 de cualquier endpoint.
final updateRequiredProvider = Provider<bool>((ref) {
  final remote = ref.watch(remoteConfigProvider);
  if (remote.upgradeRequiredBy426) return true;
  final minimum = remote.config.minSupportedVersion;
  if (minimum == null) return false;
  return !isVersionSupported(
    current: ref.watch(appVersionProvider),
    minimum: minimum,
  );
});
