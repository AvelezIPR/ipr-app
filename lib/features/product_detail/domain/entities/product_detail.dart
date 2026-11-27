import 'package:ipr_mobile/features/product_detail/domain/entities/product_variant.dart';
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
    this.variantAxes = const [],
    this.variants = const [],
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

  /// Ejes de elección y variaciones de un producto variable (W1-01); vacíos
  /// en un producto simple.
  final List<ProductVariantAxis> variantAxes;
  final List<ProductVariant> variants;

  /// ¿Es un producto variable? Solo si hay ejes **y** variaciones que elegir.
  bool get isVariable => variantAxes.isNotEmpty && variants.isNotEmpty;

  int get id => summary.id;
  String get slug => summary.slug;
  String get name => summary.name;
  String get sku => summary.sku;
  PriceStatus get price => summary.price;

  /// ¿Se puede ofrecer "Agregar al carrito"? Con precio y en stock, y siempre
  /// que el servidor no lo niegue (CR-017: bajo pedido no). Un producto
  /// variable **nunca** se compra sin elegir una variación ([withVariant]).
  bool get canAddToCart =>
      !isVariable && summary.canAddToCart && serverPurchasable;

  /// La ficha tal como se ve al elegir [variant] ([label] = sus opciones): su
  /// id, SKU, precio, stock e imagen, y el nombre con la opción. Es un
  /// producto **simple** (sin ejes), así que el resto de la pantalla y el
  /// carrito lo tratan como cualquier otro. El id es el de la variación.
  ProductDetail withVariant(ProductVariant variant, {required String label}) {
    final base = summary;
    return ProductDetail(
      summary: ProductSummary(
        id: variant.id,
        slug: base.slug,
        name: label.isEmpty ? base.name : '${base.name} · $label',
        sku: variant.sku,
        brandName: base.brandName,
        brandSlug: base.brandSlug,
        price: variant.price,
        regularPrice: variant.regularPrice,
        onSale: variant.onSale,
        availability: variant.availability,
        image: variant.image ?? base.image,
        categorySlugs: base.categorySlugs,
        quantityRange: variant.quantityRange,
      ),
      shortDescription: shortDescription,
      descriptionHtml: descriptionHtml,
      gallery: [
        if (variant.image != null) variant.image!,
        ...gallery.where((image) => image != variant.image),
      ],
      attributes: attributes,
      categories: categories,
      webUrl: webUrl,
      serverPurchasable: variant.serverPurchasable,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ProductDetail &&
      other.summary == summary &&
      other.shortDescription == shortDescription &&
      other.descriptionHtml == descriptionHtml &&
      _sameList(other.gallery, gallery) &&
      _sameList(other.attributes, attributes) &&
      _sameList(other.variantAxes, variantAxes) &&
      _sameList(other.variants, variants) &&
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
