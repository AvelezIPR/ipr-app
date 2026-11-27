import 'package:ipr_mobile/shared/domain/image_ref.dart';
import 'package:ipr_mobile/shared/domain/price_status.dart';
import 'package:ipr_mobile/shared/domain/stock_status.dart';
import 'package:meta/meta.dart';

/// Sugerencia de autocompletado (`openapi.yaml` → `Suggestion`). Solo lo que
/// la interfaz muestra y necesita para abrir la ficha.
@immutable
final class SearchSuggestion {
  const new({
    required this.id,
    required this.slug,
    required this.name,
    required this.sku,
    this.brandName,
    this.image,
    this.price,
    this.availability,
  });

  final int id;
  final String slug;
  final String name;
  final String sku;
  final String? brandName;
  final ImageRef? image;
  final PriceStatus? price;
  final StockStatus? availability;

  @override
  bool operator ==(Object other) =>
      other is SearchSuggestion && other.id == id && other.slug == slug;

  @override
  int get hashCode => Object.hash(id, slug);
}

/// Respuesta de `searchSuggestions` (máx. 6 elementos).
@immutable
final class SearchSuggestions {
  const new({required this.items, required this.total});

  static const empty = SearchSuggestions(items: [], total: 0);

  final List<SearchSuggestion> items;
  final int total;
}
