import 'package:ipr_mobile/shared/domain/product_summary.dart';
import 'package:meta/meta.dart';

/// Una página de un listado (`ProductPage` del contrato).
@immutable
final class ProductPage {
  const new({
    required this.items,
    required this.page,
    required this.hasMore,
    this.perPage,
    this.total,
    this.totalPages,
  });

  final List<ProductSummary> items;
  final int page;
  final int? perPage;

  /// Total de resultados del servidor (contador del listado, AC-013-1); `null`
  /// si el servidor no lo informó.
  final int? total;
  final int? totalPages;
  final bool hasMore;
}

/// Un valor y si proviene de datos guardados que pueden estar desactualizados
/// (`stale` → `StaleBanner`).
@immutable
final class Cached<T> {
  const new(this.value, {this.stale = false});

  final T value;
  final bool stale;
}
