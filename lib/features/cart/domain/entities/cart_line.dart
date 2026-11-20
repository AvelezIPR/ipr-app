import 'package:ipr_mobile/shared/domain/image_ref.dart';
import 'package:ipr_mobile/shared/domain/price_status.dart';
import 'package:ipr_mobile/shared/domain/product_summary.dart';
import 'package:ipr_mobile/shared/domain/stock_status.dart' as stock_rules;
import 'package:ipr_mobile/shared/domain/stock_status.dart' show StockStatus;
import 'package:meta/meta.dart';

/// Instantánea **visual** de un producto en el carrito (RF-049): lo mínimo
/// para pintar la línea sin red. Sin datos personales. El precio y la
/// disponibilidad guardados son solo de presentación: la autoridad es la
/// última revalidación del servidor (AC-029-8, AC-050-8).
@immutable
final class CartLineSnapshot {
  const new({
    required this.name,
    required this.sku,
    required this.price,
    required this.availability,
    this.brandName,
    this.image,
  });

  /// Instantánea tomada de un [ProductSummary] (ficha, listados o respuesta
  /// de `/cart/validate`).
  factory fromProduct(ProductSummary product) {
    final image = product.image;
    return CartLineSnapshot(
      name: product.name,
      sku: product.sku,
      brandName: product.brandName,
      price: product.price,
      availability: product.availability,
      image: image == null ? null : ImageRef(url: image.url, alt: image.alt),
    );
  }

  final String name;
  final String sku;
  final String? brandName;
  final PriceStatus price;
  final StockStatus availability;
  final ImageRef? image;

  /// Elegible para comprar según lo último que se supo: precio con valor y
  /// "en stock" (IR-02, CR-017).
  bool get isPurchasable =>
      stock_rules.canAddToCart(price: price, stock: availability);

  @override
  bool operator ==(Object other) =>
      other is CartLineSnapshot &&
      other.name == name &&
      other.sku == sku &&
      other.brandName == brandName &&
      other.price == price &&
      other.availability == availability &&
      other.image == image;

  @override
  int get hashCode =>
      Object.hash(name, sku, brandName, price, availability, image);
}

/// Una línea del carrito: producto y cantidad (E37). La instantánea es
/// opcional (un producto añadido sin ella se muestra por referencia hasta la
/// primera revalidación).
@immutable
final class CartLine {
  const new({required this.productId, required this.quantity, this.snapshot});

  final int productId;
  final int quantity;
  final CartLineSnapshot? snapshot;

  CartLine copyWith({int? quantity, CartLineSnapshot? snapshot}) => CartLine(
    productId: productId,
    quantity: quantity ?? this.quantity,
    snapshot: snapshot ?? this.snapshot,
  );

  @override
  bool operator ==(Object other) =>
      other is CartLine &&
      other.productId == productId &&
      other.quantity == quantity &&
      other.snapshot == snapshot;

  @override
  int get hashCode => Object.hash(productId, quantity, snapshot);

  @override
  String toString() => 'CartLine($productId x$quantity)';
}
