import 'package:ipr_mobile/features/search/domain/entities/search_page.dart';
import 'package:ipr_mobile/features/search/domain/entities/search_suggestion.dart';
import 'package:ipr_mobile/shared/domain/image_ref.dart';
import 'package:ipr_mobile/shared/domain/money.dart';
import 'package:ipr_mobile/shared/domain/price_status.dart';
import 'package:ipr_mobile/shared/domain/product_ref.dart';
import 'package:ipr_mobile/shared/domain/product_summary.dart';
import 'package:ipr_mobile/shared/domain/stock_status.dart';

/// Última página que admite el contrato (`Page.maximum: 50`).
const searchMaxPage = 50;

/// Mapeo tolerante de `searchProducts` → [SearchPage].
///
/// * Campos nuevos o ausentes no rompen; un valor de enum desconocido pasa a
///   `unknown`; precio 0/ilegible → "Más información" (nunca "$0").
/// * Un elemento sin `id`, `slug` válido o `name` se omite. Si TODOS los
///   elementos de una lista no vacía son ilegibles es un fallo de contrato
///   (se lanza [FormatException]; el cliente lo convierte en `ContractFailure`),
///   nunca un "sin resultados" falso.
SearchPage mapSearchPage(Object? json, {required int page}) {
  final root = _map(json);
  final data = root?['data'];
  if (data is! List<Object?>) {
    throw const FormatException('search: falta data');
  }
  final items = [for (final raw in data) ?_product(raw)];
  if (data.isNotEmpty && items.isEmpty) {
    throw const FormatException('search: ningún elemento legible');
  }
  final meta = _map(root?['meta']);
  final hasMore = meta?['hasMore'] == true && page < searchMaxPage;
  final total = meta?['total'];
  return SearchPage(
    items: items,
    page: page,
    hasMore: hasMore,
    total: total is int && total >= items.length ? total : items.length,
  );
}

/// Mapeo tolerante de `searchSuggestions` → [SearchSuggestions] (máx. 6).
SearchSuggestions mapSearchSuggestions(Object? json) {
  final data = _map(_map(json)?['data']);
  final raw = data?['items'];
  if (raw is! List<Object?>) {
    throw const FormatException('suggestions: falta data.items');
  }
  final items = [for (final entry in raw) ?_suggestion(entry)].take(6).toList();
  final total = data?['total'];
  return SearchSuggestions(
    items: items,
    total: total is int && total >= items.length ? total : items.length,
  );
}

ProductSummary? _product(Object? raw) {
  final m = _map(raw);
  if (m == null) return null;
  final id = m['id'];
  final slug = m['slug'];
  final name = m['name'];
  if (id is! int || slug is! String || name is! String) return null;
  if (name.trim().isEmpty || !ProductRef.isValidSlug(slug)) return null;

  final priceJson = _map(m['price']);
  final status = priceJson?['status'];
  final price = PriceStatus.fromContract(
    status: status is String ? status : null,
    amount: priceJson?['amount'],
  );
  final regular = Money.tryFromJson(priceJson?['regularAmount']);
  final brand = _map(m['brand']);
  final brandName = brand?['name'];
  final brandSlug = brand?['slug'];
  final sku = m['sku'];
  final availability = m['availability'];
  final categories = m['categorySlugs'];
  return ProductSummary(
    id: id,
    slug: slug,
    name: name,
    sku: sku is String ? sku : '',
    brandName: brandName is String && brandName.isNotEmpty ? brandName : null,
    brandSlug: brandSlug is String && brandSlug.isNotEmpty ? brandSlug : null,
    price: price,
    regularPrice: price.hasPrice ? regular : null,
    onSale: price.hasPrice && priceJson?['onSale'] == true,
    availability: StockStatus.fromContract(
      availability is String ? availability : null,
    ),
    image: ImageRef.tryFromJson(m['image']),
    categorySlugs: categories is List<Object?>
        ? [
            for (final c in categories)
              if (c is String) c,
          ]
        : const [],
  );
}

SearchSuggestion? _suggestion(Object? raw) {
  final m = _map(raw);
  if (m == null) return null;
  final id = m['id'];
  final slug = m['slug'];
  final name = m['name'];
  if (id is! int || slug is! String || name is! String) return null;
  if (name.trim().isEmpty || !ProductRef.isValidSlug(slug)) return null;
  final sku = m['sku'];
  final brand = m['brandName'];
  return SearchSuggestion(
    id: id,
    slug: slug,
    name: name,
    sku: sku is String ? sku : '',
    brandName: brand is String && brand.isNotEmpty ? brand : null,
  );
}

Map<String, Object?>? _map(Object? value) =>
    value is Map<String, dynamic> ? value : null;
