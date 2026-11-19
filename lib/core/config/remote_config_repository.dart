import 'dart:convert';

import 'package:ipr_mobile/core/config/remote_config.dart';
import 'package:ipr_mobile/core/config/remote_config_dto.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/api_client.dart';
import 'package:ipr_mobile/core/network/api_request.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/core/storage/cache_store.dart';

/// De dónde salió la configuración vigente.
enum RemoteConfigSource { defaults, cache, network }

/// Lectura de `GET /config` con respaldo en caché (último valor conocido).
final class RemoteConfigRepository {
  new({required this._client, required this._cache, required this._platform});

  static const _cacheKey = 'config.v1';
  static const _etagKey = 'config.v1.etag';

  final ApiClient _client;
  final CacheStore _cache;
  final String _platform;

  /// Último valor guardado (cualquier antigüedad dentro de la política).
  Future<RemoteConfig?> readCached() async {
    final cached = await _cache.read(_cacheKey, CachePolicy.config);
    if (cached == null) return null;
    return _parse(cached.value);
  }

  /// Pide la configuración al servidor. Un 304 conserva la caché; un fallo
  /// devuelve el [AppFailure] sin tocar lo guardado.
  Future<Result<RemoteConfig>> fetch() async {
    final etag = (await _cache.read(_etagKey, CachePolicy.config))?.value;
    final result = await _client.send(
      ApiRequest.get('/config', headers: {'If-None-Match': ?etag}),
    );
    return switch (result) {
      Err<ApiResponse>(:final failure) => Err(failure),
      Ok<ApiResponse>(:final value) => await _fromResponse(value),
    };
  }

  Future<Result<RemoteConfig>> _fromResponse(ApiResponse response) async {
    if (response.notModified) {
      final cached = await readCached();
      return cached == null
          ? const Err(ContractFailure(detail: '304 sin caché de /config'))
          : Ok(cached);
    }
    final data = response.data;
    if (data is! Map<String, dynamic> ||
        data['data'] is! Map<String, dynamic>) {
      return const Err(ContractFailure(detail: 'GET /config'));
    }
    final raw = jsonEncode(data['data']);
    final config = _parse(raw);
    if (config == null) {
      return const Err(ContractFailure(detail: 'GET /config'));
    }
    await _cache.write(_cacheKey, raw);
    final newEtag = response.etag;
    if (newEtag != null) await _cache.write(_etagKey, newEtag);
    return Ok(config);
  }

  RemoteConfig? _parse(String raw) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return RemoteConfigDto.fromJson(json).toEntity(platform: _platform);
    } on Object {
      return null;
    }
  }
}
