import 'package:ipr_mobile/features/catalog/domain/entities/product_filters.dart';
import 'package:meta/meta.dart';

/// Qué se está listando.
enum ListKind {
  /// `GET /products?category=…`
  category,

  /// `GET /products?brand=…` (landing de marca).
  brand,

  /// `GET /liquidaciones`
  sale,
}

/// Contexto fijo de un listado: su clave en los proveedores (igualdad por
/// valor).
@immutable
final class ListScope {
  const new category(String value) : kind = ListKind.category, slug = value;
  const new brand(String value) : kind = ListKind.brand, slug = value;
  const new sale() : kind = ListKind.sale, slug = null;

  /// Sin categoría: el listado general de `/catalog/list` sin parámetro.
  const new all() : kind = ListKind.category, slug = null;

  final ListKind kind;

  /// Slug de la categoría o de la marca; `null` en liquidaciones o en el
  /// listado general.
  final String? slug;

  String? get categorySlug => kind == ListKind.category ? slug : null;
  String? get brandSlug => kind == ListKind.brand ? slug : null;

  @override
  bool operator ==(Object other) =>
      other is ListScope && other.kind == kind && other.slug == slug;

  @override
  int get hashCode => Object.hash(kind, slug);

  @override
  String toString() => 'ListScope($kind, $slug)';
}

/// Una página pedida de un listado.
@immutable
final class ProductQuery {
  const new({
    required this.scope,
    this.filters = ProductFilters.empty,
    this.page = 1,
    this.perPage = defaultPerPage,
  });

  /// Tamaño de página en la app: DESCONOCIDO (D-05/ADR-001). Se usa el valor
  /// por defecto del contrato (24; el contrato admite 12, 24 y 48).
  static const defaultPerPage = 24;

  /// Máximo de páginas que admite el contrato (`page` ≤ 50).
  static const maxPage = 50;

  final ListScope scope;
  final ProductFilters filters;
  final int page;
  final int perPage;

  ProductQuery forPage(int page) => ProductQuery(
    scope: scope,
    filters: filters,
    page: page,
    perPage: perPage,
  );
}
