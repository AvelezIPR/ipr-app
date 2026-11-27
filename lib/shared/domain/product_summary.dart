import 'package:ipr_mobile/shared/domain/image_ref.dart';
import 'package:ipr_mobile/shared/domain/money.dart';
import 'package:ipr_mobile/shared/domain/price_status.dart';
import 'package:ipr_mobile/shared/domain/quantity_range.dart';
import 'package:ipr_mobile/shared/domain/stock_status.dart' as stock_rules;
import 'package:ipr_mobile/shared/domain/stock_status.dart' show StockStatus;
import 'package:meta/meta.dart';

/// Resumen de un producto para tarjetas y listas (`openapi.yaml` →
/// `ProductSummary`). Es una entidad de dominio: ningún DTO sale de `data/`
/// (D5); cada feature la construye con su propio mapeador tolerante.
///
/// **Reglas de negocio que viajan con el tipo** (ADR-002, CR-017):
/// * Sin precio ([OnRequest]) → "Más información" y nunca "$0".
/// * Solo [StockStatus.inStock] con precio se puede añadir al carrito; el
///   servidor revalida siempre.
@immutable
final class ProductSummary {
  const new({
    required this.id,
    required this.slug,
    required this.name,
    required this.sku,
    required this.price,
    required this.availability,
    this.brandName,
    this.brandSlug,
    this.regularPrice,
    this.onSale = false,
    this.image,
    this.categorySlugs = const [],
    this.hasVariants = false,
    this.priceFrom,
    this.quantityRange = QuantityRange.standard,
  });

  final int id;
  final String slug;
  final String name;
  final String sku;
  final String? brandName;
  final String? brandSlug;
  final PriceStatus price;

  /// Precio regular antes de la oferta; solo si [onSale] y hay precio.
  final Money? regularPrice;
  final bool onSale;
  final StockStatus availability;
  final ImageRef? image;
  final List<String> categorySlugs;

  /// Producto variable (medida, voltaje, volumen…): la tarjeta muestra "Desde"
  /// y "Ver opciones" y la compra se hace en la ficha (W1-01).
  final bool hasVariants;

  /// Precio mínimo entre las variaciones con precio; solo si [hasVariants].
  final Money? priceFrom;

  /// Cantidades que se pueden comprar por línea (W1-06).
  final QuantityRange quantityRange;

  /// ¿Se puede ofrecer "Añadir al carrito"? (CR-017: bajo pedido, no).
  bool get canAddToCart =>
      stock_rules.canAddToCart(price: price, stock: availability);

  /// Importe regular tachado solo cuando es una oferta real (mayor que el
  /// precio vigente).
  Money? get strikeThroughPrice {
    final current = price;
    final regular = regularPrice;
    if (!onSale || current is! Priced || regular == null) return null;
    return regular.pesos > current.amount.pesos ? regular : null;
  }

  @override
  bool operator ==(Object other) =>
      other is ProductSummary &&
      other.id == id &&
      other.slug == slug &&
      other.name == name &&
      other.sku == sku &&
      other.price == price &&
      other.availability == availability &&
      other.onSale == onSale &&
      other.regularPrice == regularPrice &&
      other.hasVariants == hasVariants &&
      other.priceFrom == priceFrom &&
      other.quantityRange == quantityRange;

  @override
  int get hashCode => Object.hash(id, slug, name, sku, price, availability);
}
