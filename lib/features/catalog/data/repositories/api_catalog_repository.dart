import 'dart:convert';

import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/api_request.dart';
import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/core/storage/cache_store.dart';
import 'package:ipr_mobile/features/catalog/data/datasources/catalog_remote_datasource.dart';
import 'package:ipr_mobile/features/catalog/data/mappers/catalog_mappers.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/brand.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/brand_landing.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/category_node.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/filter_dimension.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/product_page.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/product_query.dart';
import 'package:ipr_mobile/features/catalog/domain/repositories/catalog_repository.dart';

/// Implementación sobre `/mobile/v1` con caché SWR
/// (`flutter_app_architecture.md` §7.4):
///
/// * Dato guardado **vigente** (y sin `forceRefresh`) → se devuelve sin red.
/// * Dato caducado o ausente → se pide a la red; si falla (y es un fallo
///   reintentable) y hay dato guardado, se devuelve marcado `stale`. Un fallo
///   de red **nunca** borra la caché.
/// * Sin dato guardado y con fallo → `Err` (no se finge una lista vacía).
/// * Un 404 jamás se sustituye por la caché: el recurso ya no existe.
/// * Si el servidor sirve `X-IPR-Data-State: stale`, el dato se marca `stale`
///   y no se guarda (para volver a pedirlo en la siguiente apertura).
///
/// Taxonomía (categorías, marcas, filtros): 1 h / 7 d. Listados: 5 min / 24 h
/// y solo la **página 1**; la búsqueda interna no se guarda nunca (el término
/// lo escribe el usuario). Cero PII en las claves.
final class ApiCatalogRepository implements CatalogRepository {
  new({required this._remote, required this._cache});

  static const categoriesKey = 'catalog.categories.v1';
  static const brandsKey = 'catalog.brands.v1';
  static const brandLandingKeyPrefix = 'catalog.brandLanding.v1:';
  static const filtersKeyPrefix = 'catalog.filters.v1:';
  static const productsKeyPrefix = 'catalog.products.v1:';

  final CatalogRemoteDataSource _remote;
  final CacheStore _cache;

  @override
  Future<Result<Cached<List<CategoryNode>>>> categories({
    bool forceRefresh = false,
    RequestCancellation? cancel,
  }) => _load(
    key: categoriesKey,
    policy: CachePolicy.taxonomy,
    forceRefresh: forceRefresh,
    fetch: () => _remote.categories(cancel: cancel),
    parse: mapCategories,
    path: '/categories',
  );

  @override
  Future<Result<Cached<List<Brand>>>> brands({
    bool forceRefresh = false,
    RequestCancellation? cancel,
  }) => _load(
    key: brandsKey,
    policy: CachePolicy.taxonomy,
    forceRefresh: forceRefresh,
    fetch: () => _remote.brands(cancel: cancel),
    parse: mapBrands,
    path: '/brands',
  );

  @override
  Future<Result<Cached<BrandLanding>>> brandLanding(
    String slug, {
    bool forceRefresh = false,
    RequestCancellation? cancel,
  }) => _load(
    key: '$brandLandingKeyPrefix$slug',
    policy: CachePolicy.taxonomy,
    forceRefresh: forceRefresh,
    fetch: () => _remote.brandLanding(slug, cancel: cancel),
    parse: mapBrandLanding,
    path: '/brands/{slug}',
  );

  @override
  Future<Result<Cached<List<FilterDimension>>>> filters({
    String? categorySlug,
    bool forceRefresh = false,
    RequestCancellation? cancel,
  }) => _load(
    key: '$filtersKeyPrefix${categorySlug ?? '*'}',
    policy: CachePolicy.taxonomy,
    forceRefresh: forceRefresh,
    fetch: () => _remote.filters(categorySlug: categorySlug, cancel: cancel),
    parse: mapFilters,
    path: '/filters',
  );

  @override
  Future<Result<Cached<ProductPage>>> products(
    ProductQuery query, {
    bool forceRefresh = false,
    RequestCancellation? cancel,
  }) {
    final searching =
        query.scope.kind == ListKind.brand && query.filters.isSearching;
    final request = buildProductRequest(query);
    return _load(
      key: (query.page == 1 && !searching) ? _productsKey(request) : null,
      policy: CachePolicy.listing,
      forceRefresh: forceRefresh,
      fetch: () => _remote.products(query, cancel: cancel),
      parse: (body) => mapProductPage(body, requestedPage: query.page),
      path: request.path,
    );
  }

  /// Clave determinista de la página 1 de un listado: ruta + parámetros
  /// ordenados. No contiene texto del usuario (la búsqueda no se guarda).
  static String _productsKey(ApiRequest request) {
    final entries =
        (request.query ?? const <String, Object?>{}).entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));
    final params = entries.map((e) => '${e.key}=${e.value}').join('&');
    return '$productsKeyPrefix${request.path}?$params';
  }

  Future<Result<Cached<T>>> _load<T>({
    required String? key,
    required CachePolicy policy,
    required bool forceRefresh,
    required Future<Result<ApiResponse>> Function() fetch,
    required T Function(Object? body) parse,
    required String path,
  }) async {
    final cached = key == null ? null : await _readCache(key, policy);
    final cachedValue = cached == null ? null : _tryParse(cached.value, parse);

    if (cached != null &&
        cachedValue != null &&
        !forceRefresh &&
        !cached.isStale) {
      return Ok(Cached(cachedValue));
    }

    final response = await fetch();
    switch (response) {
      case Err<ApiResponse>(:final failure):
        // Dato guardado como respaldo solo si el fallo es transitorio.
        if (cachedValue != null && failure.retryable) {
          return Ok(Cached(cachedValue, stale: true));
        }
        return Err(failure);
      case Ok<ApiResponse>(:final value):
        if (value.notModified) {
          // No se envía If-None-Match; si llega 304, se conserva la caché.
          return cachedValue != null
              ? Ok(Cached(cachedValue))
              : Err(ContractFailure(detail: 'GET $path 304 sin caché'));
        }
        final T parsed;
        try {
          parsed = parse(value.data);
        } on Object {
          if (cachedValue != null) return Ok(Cached(cachedValue, stale: true));
          return Err(ContractFailure(detail: 'GET $path'));
        }
        if (key != null && !value.isStale) {
          await _writeCache(key, jsonEncode(value.data));
        }
        return Ok(Cached(parsed, stale: value.isStale));
    }
  }

  Future<CacheRead?> _readCache(String key, CachePolicy policy) async {
    try {
      return await _cache.read(key, policy);
    } on Object {
      return null; // la caché es un respaldo: nunca rompe la carga
    }
  }

  Future<void> _writeCache(String key, String value) async {
    try {
      await _cache.write(key, value);
    } on Object {
      // sin espacio o caché dañada: se sigue sin guardar
    }
  }

  T? _tryParse<T>(String raw, T Function(Object? body) parse) {
    try {
      return parse(jsonDecode(raw));
    } on Object {
      return null;
    }
  }
}
