import 'package:ipr_mobile/shared/domain/image_ref.dart';
import 'package:ipr_mobile/shared/domain/money.dart';
import 'package:ipr_mobile/shared/domain/price_status.dart';
import 'package:ipr_mobile/shared/domain/quantity_range.dart';
import 'package:ipr_mobile/shared/domain/stock_status.dart' as stock_rules;
import 'package:ipr_mobile/shared/domain/stock_status.dart' show StockStatus;
import 'package:meta/meta.dart';

/// Una opción de un eje de elección (`openapi.yaml` → `ProductVariantAxis`):
/// el [value] que usa el contrato y la [label] que ve la persona.
@immutable
final class ProductVariantOption {
  const new({required this.value, required this.label});

  final String value;
  final String label;

  @override
  bool operator ==(Object other) =>
      other is ProductVariantOption &&
      other.value == value &&
      other.label == label;

  @override
  int get hashCode => Object.hash(value, label);
}

/// Un eje de elección de un producto variable (medida, voltaje, volumen…).
@immutable
final class ProductVariantAxis {
  const new({required this.slug, required this.name, required this.options});

  final String slug;
  final String name;
  final List<ProductVariantOption> options;

  /// Etiqueta de la opción [value]; si no existe, el propio valor.
  String labelOf(String value) {
    for (final option in options) {
      if (option.value == value) return option.label;
    }
    return value;
  }

  @override
  bool operator ==(Object other) =>
      other is ProductVariantAxis &&
      other.slug == slug &&
      other.name == name &&
      _sameOptions(other.options, options);

  @override
  int get hashCode => Object.hash(slug, name, options.length);
}

bool _sameOptions(List<ProductVariantOption> a, List<ProductVariantOption> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Una variación de un producto variable (`ProductVariant`). Su [id] es el que
/// viaja al carrito y al pago: WooCommerce lo convierte en padre + variación.
@immutable
final class ProductVariant {
  const new({
    required this.id,
    required this.sku,
    required this.price,
    required this.availability,
    required this.selection,
    this.regularPrice,
    this.onSale = false,
    this.image,
    this.serverPurchasable = true,
    this.quantityRange = QuantityRange.standard,
  });

  final int id;
  final String sku;
  final PriceStatus price;
  final Money? regularPrice;
  final bool onSale;
  final StockStatus availability;
  final ImageRef? image;

  /// Opción de cada eje que define la variación (eje → valor). Un eje que no
  /// figura significa "cualquiera" (atributo vacío en WooCommerce).
  final Map<String, String> selection;

  /// `purchasable` del contrato: si el servidor lo niega nunca se ofrece.
  final bool serverPurchasable;

  /// Cantidades que se pueden comprar por línea de esta variación (W1-06).
  final QuantityRange quantityRange;

  /// Solo con precio y en stock (CR-017), y si el servidor no lo niega.
  bool get canAddToCart =>
      stock_rules.canAddToCart(price: price, stock: availability) &&
      serverPurchasable;

  @override
  bool operator ==(Object other) =>
      other is ProductVariant &&
      other.id == id &&
      other.sku == sku &&
      other.price == price &&
      other.regularPrice == regularPrice &&
      other.onSale == onSale &&
      other.availability == availability &&
      other.image == image &&
      other.serverPurchasable == serverPurchasable &&
      other.quantityRange == quantityRange &&
      _sameSelection(other.selection, selection);

  @override
  int get hashCode => Object.hash(id, sku, price, availability);
}

bool _sameSelection(Map<String, String> a, Map<String, String> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}
