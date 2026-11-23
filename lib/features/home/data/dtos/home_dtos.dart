/// DTO de `Category` (`openapi.yaml`). Lectura tolerante: lo que falta o
/// tiene otro tipo queda en `null` y el mapeador descarta el elemento.
final class CategoryDto {
  const new({this.id, this.slug, this.name, this.parentId});

  factory fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final slug = json['slug'];
    final name = json['name'];
    final parentId = json['parentId'];
    return CategoryDto(
      id: id is int ? id : null,
      slug: slug is String ? slug : null,
      name: name is String ? name : null,
      parentId: parentId is int ? parentId : null,
    );
  }

  final int? id;
  final String? slug;
  final String? name;
  final int? parentId;
}

/// DTO de `Brand` (`openapi.yaml`).
final class BrandDto {
  const new({this.slug, this.name, this.hasLanding});

  factory fromJson(Map<String, dynamic> json) {
    final slug = json['slug'];
    final name = json['name'];
    final hasLanding = json['hasLanding'];
    return BrandDto(
      slug: slug is String ? slug : null,
      name: name is String ? name : null,
      hasLanding: hasLanding is bool ? hasLanding : null,
    );
  }

  final String? slug;
  final String? name;
  final bool? hasLanding;
}

/// DTO mínimo de `Store` (`openapi.yaml`): el inicio solo necesita la ciudad y
/// si la sede aún no abre.
final class StoreCityDto {
  const new({this.city, this.upcoming});

  factory fromJson(Map<String, dynamic> json) {
    final city = json['city'];
    final upcoming = json['upcoming'];
    return StoreCityDto(
      city: city is String ? city.trim() : null,
      upcoming: upcoming is bool ? upcoming : null,
    );
  }

  final String? city;
  final bool? upcoming;
}

/// DTO de `ProductSummary` (`openapi.yaml`). Conserva los valores crudos de
/// precio y disponibilidad: la interpretación (precio 0 → "Más información",
/// disponibilidad desconocida) la hace el mapeador con las reglas de `shared`.
final class ProductSummaryDto {
  const new({
    this.id,
    this.slug,
    this.name,
    this.sku,
    this.brandName,
    this.brandSlug,
    this.priceStatus,
    this.priceAmount,
    this.regularAmount,
    this.onSale,
    this.availability,
    this.image,
    this.categorySlugs = const [],
  });

  factory fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final slug = json['slug'];
    final name = json['name'];
    final sku = json['sku'];
    final brand = json['brand'];
    final price = json['price'];
    final onSale = price is Map<String, dynamic> ? price['onSale'] : null;
    final availability = json['availability'];
    final categories = json['categorySlugs'];
    final priceMap = price is Map<String, dynamic> ? price : null;
    final brandMap = brand is Map<String, dynamic> ? brand : null;
    final brandName = brandMap?['name'];
    final brandSlug = brandMap?['slug'];
    final priceStatus = priceMap?['status'];
    return ProductSummaryDto(
      id: id is int ? id : null,
      slug: slug is String ? slug : null,
      name: name is String ? name : null,
      sku: sku is String ? sku : null,
      brandName: brandName is String ? brandName : null,
      brandSlug: brandSlug is String ? brandSlug : null,
      priceStatus: priceStatus is String ? priceStatus : null,
      priceAmount: priceMap?['amount'],
      regularAmount: priceMap?['regularAmount'],
      onSale: onSale is bool ? onSale : null,
      availability: availability is String ? availability : null,
      image: json['image'],
      categorySlugs: categories is List<dynamic>
          ? categories.whereType<String>().toList()
          : const [],
    );
  }

  final int? id;
  final String? slug;
  final String? name;
  final String? sku;
  final String? brandName;
  final String? brandSlug;
  final String? priceStatus;
  final Object? priceAmount;
  final Object? regularAmount;
  final bool? onSale;
  final String? availability;
  final Object? image;
  final List<String> categorySlugs;
}
