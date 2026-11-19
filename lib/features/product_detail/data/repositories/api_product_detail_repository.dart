import 'dart:convert';

import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/api_client.dart';
import 'package:ipr_mobile/core/network/api_request.dart';
import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/core/storage/cache_store.dart';
import 'package:ipr_mobile/features/product_detail/data/dtos/product_detail_dto.dart';
import 'package:ipr_mobile/features/product_detail/data/mappers/product_detail_mapper.dart';
import 'package:ipr_mobile/features/product_detail/domain/entities/product_detail.dart';
import 'package:ipr_mobile/features/product_detail/domain/repositories/product_detail_repository.dart';

/// `GET /products/{slug}` con caché SWR (5 min vigente / 24 h obsoleta,
/// [CachePolicy.listing]).
///
/// * Vigente → se sirve sin red.
/// * Obsoleta o con `forceRefresh` → se pide al servidor; si falla (red,
///   5xx, contrato) y hay copia, se muestra **marcada como obsoleta**
///   (`stale`); sin copia, el fallo llega a la UI.
/// * 404 definitivo → la copia se borra y se devuelve `NotFound` (el producto
///   ya no existe). Un fallo de red **nunca** borra la caché.
final class ApiProductDetailRepository implements ProductDetailRepository {
  new({required this._client, required this._cache});

  final ApiClient _client;
  final CacheStore _cache;

  static const CachePolicy _policy = CachePolicy.listing;

  /// Patrón del parámetro `slug` del contrato.
  static final _slugPattern = RegExp(r'^[a-z0-9][a-z0-9._%-]{0,199}$');

  static String cacheKey(String slug) => 'product.v1.$slug';

  @override
  Future<Result<ProductDetailLoad>> load(
    String slug, {
    bool forceRefresh = false,
    RequestCancellation? cancellation,
  }) async {
    // Un slug que el contrato rechazaría no puede existir: no se pide.
    if (!_slugPattern.hasMatch(slug)) return const Err(NotFound());

    final key = cacheKey(slug);
    final cached = await _readCache(key);
    if (cached != null && !forceRefresh && !cached.isStale) {
      return Ok(ProductDetailLoad(product: cached.product));
    }

    final result = await _client.send(
      ApiRequest.get('/products/${Uri.encodeComponent(slug)}'),
      cancellation: cancellation,
    );
    switch (result) {
      case Err<ApiResponse>(:final failure):
        if (failure is NotFound) {
          await _cache.remove(key);
          return Err(failure);
        }
        return _fallback(cached, failure);
      case Ok<ApiResponse>(:final value):
        if (value.notModified) {
          return cached == null
              ? const Err(ContractFailure(detail: 'GET /products/{slug} 304'))
              : Ok(ProductDetailLoad(product: cached.product));
        }
        final parsed = _parse(value.data);
        if (parsed == null) {
          return _fallback(
            cached,
            const ContractFailure(detail: 'GET /products/{slug}'),
          );
        }
        await _cache.write(key, jsonEncode(parsed.raw));
        return Ok(
          ProductDetailLoad(product: parsed.product, stale: value.isStale),
        );
    }
  }

  Result<ProductDetailLoad> _fallback(_Cached? cached, AppFailure failure) =>
      cached == null
      ? Err(failure)
      : Ok(ProductDetailLoad(product: cached.product, stale: true));

  Future<_Cached?> _readCache(String key) async {
    final read = await _cache.read(key, _policy);
    if (read == null) return null;
    try {
      final json = jsonDecode(read.value);
      if (json is! Map<String, dynamic>) throw const FormatException();
      return _Cached(
        ProductDetailDto.fromJson(json).toEntity(),
        isStale: read.isStale,
      );
    } on Object {
      await _cache.remove(key);
      return null;
    }
  }

  ({ProductDetail product, Map<String, dynamic> raw})? _parse(Object? body) {
    try {
      if (body is! Map<String, dynamic>) return null;
      final data = body['data'];
      if (data is! Map<String, dynamic>) return null;
      return (product: ProductDetailDto.fromJson(data).toEntity(), raw: data);
    } on Object {
      return null;
    }
  }
}

final class _Cached {
  const new(this.product, {required this.isStale});

  final ProductDetail product;
  final bool isStale;
}
