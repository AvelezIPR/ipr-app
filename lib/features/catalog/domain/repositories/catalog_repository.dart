import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/brand.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/brand_landing.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/category_node.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/filter_dimension.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/product_page.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/product_query.dart';

/// Acceso al catálogo público de `/mobile/v1` (sin sesión, RF-037).
///
/// Todos los métodos devuelven [Result]: ninguna excepción de red llega a la
/// UI. `Err(NotFound())` (404) es distinto de `Err(ServiceUnavailable())`
/// (RF-009). Con `forceRefresh` se ignora el dato guardado vigente; si la red
/// falla y hay dato guardado, se devuelve marcado `stale`.
abstract interface class CatalogRepository {
  /// Árbol de categorías (`listCategories`, caché de taxonomía 1 h / 7 d).
  Future<Result<Cached<List<CategoryNode>>>> categories({
    bool forceRefresh = false,
    RequestCancellation? cancel,
  });

  /// Directorio de marcas (`listBrands`, caché de taxonomía).
  Future<Result<Cached<List<Brand>>>> brands({
    bool forceRefresh = false,
    RequestCancellation? cancel,
  });

  /// Contenido editorial de la landing de una marca (`getBrandLanding`,
  /// W3-01). Es opcional: una marca sin contenido responde `Err(NotFound())`.
  Future<Result<Cached<BrandLanding>>> brandLanding(
    String slug, {
    bool forceRefresh = false,
    RequestCancellation? cancel,
  });

  /// Dimensiones de filtro de una categoría (`listFilters`).
  Future<Result<Cached<List<FilterDimension>>>> filters({
    String? categorySlug,
    bool forceRefresh = false,
    RequestCancellation? cancel,
  });

  /// Una página de productos (`listProducts`, `listClearanceProducts` o la
  /// búsqueda interna de marca).
  Future<Result<Cached<ProductPage>>> products(
    ProductQuery query, {
    bool forceRefresh = false,
    RequestCancellation? cancel,
  });
}
