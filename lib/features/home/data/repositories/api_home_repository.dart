import 'dart:convert';

import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/api_client.dart';
import 'package:ipr_mobile/core/network/api_request.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/core/storage/cache_store.dart';
import 'package:ipr_mobile/features/home/data/mappers/home_mappers.dart';
import 'package:ipr_mobile/features/home/domain/entities/home_brand.dart';
import 'package:ipr_mobile/features/home/domain/entities/home_category.dart';
import 'package:ipr_mobile/features/home/domain/entities/section_data.dart';
import 'package:ipr_mobile/features/home/domain/repositories/home_repository.dart';
import 'package:ipr_mobile/shared/domain/product_summary.dart';

/// Implementación sobre `/mobile/v1` (`listCategories`, `listBrands` y
/// `listProducts`) con caché SWR (`flutter_app_architecture.md` §7.4).
///
/// * Dato guardado vigente (y sin `forceRefresh`) → se devuelve sin red.
/// * Dato guardado caducado → se pide a la red; si falla, se devuelve el dato
///   guardado marcado `stale`. Un fallo de red **nunca** borra la caché.
/// * Sin dato guardado y con fallo → `Err` (no se finge una lista vacía).
final class ApiHomeRepository implements HomeRepository {
  new({required this._client, required this._cache});

  /// Claves de caché (datos públicos, sin PII).
  static const categoriesKey = 'home.categories.v1';
  static const brandsKey = 'home.brands.v1';
  static const featuredKey = 'home.featured.v1';

  /// "Más vendidos": `listProducts` con `sort=popularity`. El criterio real
  /// de selección y la cantidad son DESCONOCIDOS (PA-05): se muestra lo que
  /// entrega el servidor. 12 es el menor `perPage` que admite el contrato.
  static const featuredQuery = <String, Object?>{
    'sort': 'popularity',
    'page': 1,
    'perPage': 12,
  };

  final ApiClient _client;
  final CacheStore _cache;

  @override
  Future<Result<SectionData<List<HomeCategory>>>> categories({
    bool forceRefresh = false,
  }) => _load(
    key: categoriesKey,
    policy: CachePolicy.taxonomy,
    request: const ApiRequest.get('/categories'),
    parse: mapCategories,
    forceRefresh: forceRefresh,
  );

  @override
  Future<Result<SectionData<List<HomeBrand>>>> brands({
    bool forceRefresh = false,
  }) => _load(
    key: brandsKey,
    policy: CachePolicy.taxonomy,
    request: const ApiRequest.get('/brands'),
    parse: mapBrands,
    forceRefresh: forceRefresh,
  );

  @override
  Future<Result<SectionData<List<ProductSummary>>>> featuredProducts({
    bool forceRefresh = false,
  }) => _load(
    key: featuredKey,
    policy: CachePolicy.listing,
    request: const ApiRequest.get('/products', query: featuredQuery),
    parse: mapProducts,
    forceRefresh: forceRefresh,
  );

  Future<Result<SectionData<List<T>>>> _load<T>({
    required String key,
    required CachePolicy policy,
    required ApiRequest request,
    required List<T> Function(List<Map<String, dynamic>> items) parse,
    required bool forceRefresh,
  }) async {
    final cached = await _readCache(key, policy, parse);
    if (cached != null && cached.fresh && !forceRefresh) {
      return Ok(SectionData(cached.value));
    }

    final result = await _client.send(request);
    switch (result) {
      case Err<ApiResponse>(:final failure):
        return _fallback(cached, failure);
      case Ok<ApiResponse>(:final value):
        final body = value.data;
        final items = body is Map<String, dynamic>
            ? itemsOf(body['data'])
            : null;
        if (items == null) {
          return _fallback(
            cached,
            ContractFailure(detail: '${request.method} ${request.path}'),
          );
        }
        final parsed = parse(items);
        if (parsed.isNotEmpty) {
          await _writeCache(key, jsonEncode(items));
        }
        return Ok(SectionData(parsed, stale: value.isStale));
    }
  }

  /// Fallo de red/servidor: con dato guardado se muestra ese dato (obsoleto);
  /// sin él, el error. 426 nunca se disfraza con la caché.
  Result<SectionData<List<T>>> _fallback<T>(
    _Cached<List<T>>? cached,
    AppFailure failure,
  ) {
    if (cached == null || failure is UpgradeRequired) return Err(failure);
    return Ok(SectionData(cached.value, stale: true));
  }

  Future<_Cached<List<T>>?> _readCache<T>(
    String key,
    CachePolicy policy,
    List<T> Function(List<Map<String, dynamic>> items) parse,
  ) async {
    try {
      final read = await _cache.read(key, policy);
      if (read == null) return null;
      final items = itemsOf(jsonDecode(read.value));
      if (items == null) {
        await _cache.remove(key);
        return null;
      }
      final parsed = parse(items);
      if (parsed.isEmpty) return null;
      return _Cached(parsed, fresh: !read.isStale);
    } on Object {
      // Una caché ilegible nunca debe tumbar el bloque.
      return null;
    }
  }

  Future<void> _writeCache(String key, String value) async {
    try {
      await _cache.write(key, value);
    } on Object {
      // Sin caché la app sigue funcionando.
    }
  }
}

final class _Cached<T> {
  const new(this.value, {required this.fresh});

  final T value;
  final bool fresh;
}
