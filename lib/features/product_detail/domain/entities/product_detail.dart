import 'package:ipr_mobile/shared/domain/image_ref.dart';
import 'package:ipr_mobile/shared/domain/price_status.dart';
import 'package:ipr_mobile/shared/domain/product_summary.dart';
import 'package:meta/meta.dart';

/// Atributo técnico de WooCommerce (`openapi.yaml` → `ProductAttribute`).
@immutable
final class ProductAttribute {
  const new({required this.name, required this.slug, required this.options});

  final String name;
  final String slug;
  final List<String> options;

  /// Valor listo para mostrar: las opciones separadas por coma. Siempre se
  /// presenta como **texto** (AC-028-3), nunca como HTML.
  String get displayValue => options.join(', ');

  @override
  bool operator ==(Object other) =>
      other is ProductAttribute &&
      other.name == name &&
      other.slug == slug &&
      _sameList(other.options, options);

  @override
  int get hashCode => Object.hash(name, slug, Object.hashAll(options));
}

/// Categoría a la que pertenece el producto (`CategoryRef`).
@immutable
final class ProductCategory {
  const new({required this.id, required this.slug, required this.name});

  final int id;
  final String slug;
  final String name;

  @override
  bool operator ==(Object other) =>
      other is ProductCategory &&
      other.id == id &&
      other.slug == slug &&
      other.name == name;

  @override
  int get hashCode => Object.hash(id, slug, name);
}

/// Ficha de producto (`openapi.yaml` → `ProductDetail`).
///
/// Reglas de negocio que viajan con el tipo (ADR-002, CR-017):
/// * Sin precio → "Más información" y nunca "$0".
/// * Solo en stock **con** precio es comprable; "bajo pedido" no.
/// * El servidor revalida siempre: el precio y la disponibilidad son
///   informativos.
@immutable
final class ProductDetail {
  const new({
    required this.summary,
    this.shortDescription = '',
    this.descriptionHtml = '',
    this.gallery = const [],
    this.attributes = const [],
    this.categories = const [],
    this.webUrl,
    this.serverPurchasable = true,
  });

  /// Datos comunes con las tarjetas (nombre, marca, SKU, precio, stock).
  final ProductSummary summary;

  /// Texto plano (el contrato no admite HTML aquí).
  final String shortDescription;

  /// HTML que entrega el servidor. La app **no** lo confía: se sanea otra vez
  /// antes de mostrarlo (AC-027-2).
  final String descriptionHtml;
  final List<ImageRef> gallery;
  final List<ProductAttribute> attributes;
  final List<ProductCategory> categories;
  final String? webUrl;

  /// `purchasable` del contrato. Si falta se asume `true` y manda la regla
  /// local; si el servidor dice `false`, nunca se ofrece la compra.
  final bool serverPurchasable;

  int get id => summary.id;
  String get slug => summary.slug;
  String get name => summary.name;
  String get sku => summary.sku;
  PriceStatus get price => summary.price;

  /// ¿Se puede ofrecer "Agregar al carrito"? Con precio y en stock, y siempre
  /// que el servidor no lo niegue (CR-017: bajo pedido no).
  bool get canAddToCart => summary.canAddToCart && serverPurchasable;

  @override
  bool operator ==(Object other) =>
      other is ProductDetail &&
      other.summary == summary &&
      other.shortDescription == shortDescription &&
      other.descriptionHtml == descriptionHtml &&
      _sameList(other.gallery, gallery) &&
      _sameList(other.attributes, attributes) &&
      other.serverPurchasable == serverPurchasable;

  @override
  int get hashCode => Object.hash(summary, shortDescription, descriptionHtml);
}

bool _sameList<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Resultado de cargar una ficha: el producto y si proviene de datos
/// guardados que pueden estar desactualizados (muestra `StaleBanner`).
@immutable
final class ProductDetailLoad {
  const new({required this.product, this.stale = false});

  final ProductDetail product;
  final bool stale;
}
