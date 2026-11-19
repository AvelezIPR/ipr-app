import 'package:ipr_mobile/core/network/api_client.dart';
import 'package:ipr_mobile/core/network/api_request.dart';
import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/filter_dimension.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/product_query.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/product_sort.dart';

/// Construye los parámetros de `GET /products`, `/liquidaciones` o `/search`
/// **solo con lo que el contrato admite** (`openapi.yaml`): `category`,
/// `brand`, `tag`, `onSale`, `attr[pa_…]`, `sort`, `page`, `perPage`.
///
/// Todas las rutas son públicas: nunca llevan `Authorization` (RF-037).
ApiRequest buildProductRequest(ProductQuery query) {
  final filters = query.filters;
  final base = <String, Object?>{'page': query.page, 'perPage': query.perPage};

  // Liquidaciones: solo orden y paginación (no hay filtros en el contrato).
  if (query.scope.kind == ListKind.sale) {
    return ApiRequest.get(
      '/liquidaciones',
      query: {
        ...base,
        if (filters.sort != ProductSort.defaultSort) 'sort': filters.sort.value,
      },
    );
  }

  // Búsqueda interna de marca (RF-016): `/search?q=…&brand=…`.
  final term = filters.searchTerm;
  if (query.scope.kind == ListKind.brand && term != null) {
    return ApiRequest.get(
      '/search',
      query: {'q': term, 'brand': query.scope.slug, ...base},
    );
  }

  final params = <String, Object?>{...base};
  final category = filters.category?.slug ?? query.scope.categorySlug;
  if (category != null) params['category'] = category;
  if (query.scope.kind == ListKind.brand) params['brand'] = query.scope.slug;
  if (filters.sort != ProductSort.defaultSort) {
    params['sort'] = filters.sort.value;
  }

  // Opciones elegidas agrupadas por clave (en el orden elegido), con los
  // máximos del contrato (5 valores por clave, 5 atributos).
  final byKey = <String, List<String>>{};
  for (final choice in filters.choices) {
    if (!FilterKeys.isSupported(choice.key)) continue;
    if (query.scope.kind == ListKind.brand && choice.key == FilterKeys.brand) {
      continue; // la marca ya está fijada por la landing
    }
    byKey.putIfAbsent(choice.key, () => []).add(choice.value);
  }
  var attributes = 0;
  for (final entry in byKey.entries) {
    if (FilterKeys.isAttribute(entry.key)) {
      if (attributes >= FilterKeys.maxAttributes) continue;
      attributes++;
    }
    if (entry.key == FilterKeys.onSale) {
      params[FilterKeys.onSale] = 'true';
      continue;
    }
    final values = entry.value.take(FilterKeys.maxValuesPerKey).join(',');
    params[entry.key] = values;
  }
  return ApiRequest.get('/products', query: params);
}

/// Peticiones de catálogo sobre [ApiClient]. Sin caché ni mapeo: eso es del
/// repositorio.
final class CatalogRemoteDataSource {
  new(this._client);

  final ApiClient _client;

  Future<Result<ApiResponse>> categories({RequestCancellation? cancel}) =>
      _send(const ApiRequest.get('/categories'), cancel);

  Future<Result<ApiResponse>> brands({RequestCancellation? cancel}) =>
      _send(const ApiRequest.get('/brands'), cancel);

  Future<Result<ApiResponse>> filters({
    String? categorySlug,
    RequestCancellation? cancel,
  }) => _send(
    ApiRequest.get(
      '/filters',
      query: categorySlug == null ? null : {'category': categorySlug},
    ),
    cancel,
  );

  Future<Result<ApiResponse>> products(
    ProductQuery query, {
    RequestCancellation? cancel,
  }) => _send(buildProductRequest(query), cancel);

  Future<Result<ApiResponse>> _send(
    ApiRequest request,
    RequestCancellation? cancel,
  ) => _client.send(request, cancellation: cancel);
}
