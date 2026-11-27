/// Contrato de `GET /products/{slug}` (`openapi.yaml` → `ProductDetail`).
///
/// Lectura **tolerante**: un campo ausente o de tipo inesperado nunca rompe la
/// ficha; solo `id`, `slug` y `name` son imprescindibles (sin ellos no hay
/// producto que mostrar y se lanza [FormatException], que el cliente convierte
/// en `ContractFailure`). Los DTO no salen de `data/` (D5).
final class ProductDetailDto {
  const new({
    required this.id,
    required this.slug,
    required this.name,
    this.sku,
    this.brand,
    this.price,
    this.availability,
    this.purchasable,
    this.image,
    this.categorySlugs = const [],
    this.shortDescription,
    this.descriptionHtml,
    this.gallery = const [],
    this.attributes = const [],
    this.categories = const [],
    this.webUrl,
    this.variantAxes = const [],
    this.variants = const [],
    this.minQuantity,
    this.maxQuantity,
  });

  factory fromJson(Map<String, dynamic> json) {
    final id = _asInt(json['id']);
    final slug = json['slug'];
    final name = json['name'];
    if (id == null || id < 1 || slug is! String || slug.isEmpty) {
      throw const FormatException('ProductDetail sin id o slug');
    }
    if (name is! String || name.trim().isEmpty) {
      throw const FormatException('ProductDetail sin nombre');
    }
    return ProductDetailDto(
      id: id,
      slug: slug,
      name: name,
      sku: _asString(json['sku']),
      brand: BrandDto.tryFromJson(json['brand']),
      price: PriceDto.tryFromJson(json['price']),
      availability: _asString(json['availability']),
      purchasable: json['purchasable'] is bool
          ? json['purchasable'] as bool
          : null,
      image: json['image'],
      categorySlugs: _strings(json['categorySlugs']),
      shortDescription: _asString(json['shortDescription']),
      descriptionHtml: _asString(json['descriptionHtml']),
      gallery: _list(json['gallery']),
      attributes: _list(json['attributes'])
          .map(AttributeDto.tryFromJson)
          .whereType<AttributeDto>()
          .toList(),
      categories: _list(json['categories'])
          .map(CategoryDto.tryFromJson)
          .whereType<CategoryDto>()
          .toList(),
      webUrl: _asString(json['webUrl']),
      variantAxes: _list(json['variantAxes'])
          .map(VariantAxisDto.tryFromJson)
          .whereType<VariantAxisDto>()
          .toList(),
      variants: _list(json['variants'])
          .map(VariantDto.tryFromJson)
          .whereType<VariantDto>()
          .toList(),
      minQuantity: json['minQuantity'],
      maxQuantity: json['maxQuantity'],
    );
  }

  final int id;
  final String slug;
  final String name;
  final String? sku;
  final BrandDto? brand;
  final PriceDto? price;
  final String? availability;
  final bool? purchasable;

  /// Objeto de imagen tal cual (se interpreta con `ImageRef.tryFromJson`).
  final Object? image;
  final List<String> categorySlugs;
  final String? shortDescription;
  final String? descriptionHtml;

  /// Objetos de imagen tal cual.
  final List<Object?> gallery;
  final List<AttributeDto> attributes;
  final List<CategoryDto> categories;
  final String? webUrl;

  /// Productos variables (W1-01); vacíos en un producto simple.
  final List<VariantAxisDto> variantAxes;
  final List<VariantDto> variants;

  /// Límites de cantidad tal cual llegan (W1-06); se interpretan con
  /// `QuantityRange.fromContract`.
  final Object? minQuantity;
  final Object? maxQuantity;
}

final class VariantOptionDto {
  const new({required this.value, required this.label});

  static VariantOptionDto? tryFromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final value = _asString(json['value']);
    if (value == null || value.isEmpty) return null;
    final label = _asString(json['label']);
    return VariantOptionDto(
      value: value,
      label: label == null || label.trim().isEmpty ? value : label,
    );
  }

  final String value;
  final String label;
}

final class VariantAxisDto {
  const new({required this.slug, required this.name, required this.options});

  static VariantAxisDto? tryFromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final slug = _asString(json['slug']);
    final name = _asString(json['name']);
    if (slug == null || slug.isEmpty || name == null || name.trim().isEmpty) {
      return null;
    }
    final options = _list(json['options'])
        .map(VariantOptionDto.tryFromJson)
        .whereType<VariantOptionDto>()
        .toList();
    if (options.isEmpty) return null;
    return VariantAxisDto(slug: slug, name: name, options: options);
  }

  final String slug;
  final String name;
  final List<VariantOptionDto> options;
}

final class VariantDto {
  const new({
    required this.id,
    required this.selection,
    this.sku,
    this.price,
    this.availability,
    this.purchasable,
    this.image,
    this.minQuantity,
    this.maxQuantity,
  });

  static VariantDto? tryFromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final id = _asInt(json['id']);
    if (id == null || id < 1) return null;
    final selection = <String, String>{};
    for (final item in _list(json['selection'])) {
      if (item is! Map<String, dynamic>) continue;
      final axis = _asString(item['axis']);
      final value = _asString(item['value']);
      if (axis != null &&
          axis.isNotEmpty &&
          value != null &&
          value.isNotEmpty) {
        selection[axis] = value;
      }
    }
    return VariantDto(
      id: id,
      sku: _asString(json['sku']),
      price: PriceDto.tryFromJson(json['price']),
      availability: _asString(json['availability']),
      purchasable: json['purchasable'] is bool
          ? json['purchasable'] as bool
          : null,
      image: json['image'],
      selection: selection,
      minQuantity: json['minQuantity'],
      maxQuantity: json['maxQuantity'],
    );
  }

  final int id;
  final String? sku;
  final PriceDto? price;
  final String? availability;
  final bool? purchasable;
  final Object? image;
  final Map<String, String> selection;
  final Object? minQuantity;
  final Object? maxQuantity;
}

final class BrandDto {
  const new({required this.name, this.slug});

  static BrandDto? tryFromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final name = _asString(json['name']);
    if (name == null || name.trim().isEmpty) return null;
    return BrandDto(name: name, slug: _asString(json['slug']));
  }

  final String name;
  final String? slug;
}

final class PriceDto {
  const new({this.status, this.amount, this.regularAmount, this.onSale});

  static PriceDto? tryFromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    return PriceDto(
      status: _asString(json['status']),
      amount: json['amount'],
      regularAmount: json['regularAmount'],
      onSale: json['onSale'] is bool ? json['onSale'] as bool : null,
    );
  }

  final String? status;

  /// Número JSON tal cual (se interpreta con `Money.tryFromJson`).
  final Object? amount;
  final Object? regularAmount;
  final bool? onSale;
}

final class AttributeDto {
  const new({required this.name, required this.slug, required this.options});

  static AttributeDto? tryFromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final name = _asString(json['name']);
    if (name == null || name.trim().isEmpty) return null;
    return AttributeDto(
      name: name,
      slug: _asString(json['slug']) ?? '',
      options: _strings(json['options']),
    );
  }

  final String name;
  final String slug;
  final List<String> options;
}

final class CategoryDto {
  const new({required this.id, required this.slug, required this.name});

  static CategoryDto? tryFromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final id = _asInt(json['id']);
    final slug = _asString(json['slug']);
    final name = _asString(json['name']);
    if (id == null || slug == null || name == null) return null;
    return CategoryDto(id: id, slug: slug, name: name);
  }

  final int id;
  final String slug;
  final String name;
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is double && value == value.truncateToDouble()) {
    return value.toInt();
  }
  return null;
}

String? _asString(Object? value) => value is String ? value : null;

List<String> _strings(Object? value) =>
    value is List ? value.whereType<String>().toList() : const [];

List<Object?> _list(Object? value) => value is List ? value : const [];
