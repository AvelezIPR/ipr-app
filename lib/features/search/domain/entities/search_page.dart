import 'package:ipr_mobile/shared/domain/product_summary.dart';
import 'package:meta/meta.dart';

/// Una página de resultados de `searchProducts`.
@immutable
final class SearchPage {
  const new({
    required this.items,
    required this.page,
    required this.hasMore,
    required this.total,
  });

  final List<ProductSummary> items;

  /// Página solicitada (1..50).
  final int page;

  /// El servidor indica que hay más páginas (`meta.hasMore`).
  final bool hasMore;

  /// Total de coincidencias informado por el servidor.
  final int total;
}
