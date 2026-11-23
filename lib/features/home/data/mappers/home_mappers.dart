import 'package:ipr_mobile/features/home/data/dtos/home_dtos.dart';
import 'package:ipr_mobile/features/home/domain/entities/home_brand.dart';
import 'package:ipr_mobile/features/home/domain/entities/home_category.dart';
import 'package:ipr_mobile/features/home/domain/entities/home_city.dart';
import 'package:ipr_mobile/shared/domain/image_ref.dart';
import 'package:ipr_mobile/shared/domain/money.dart';
import 'package:ipr_mobile/shared/domain/price_status.dart';
import 'package:ipr_mobile/shared/domain/product_summary.dart';
import 'package:ipr_mobile/shared/domain/stock_status.dart';

/// Extrae los elementos (objetos JSON) de `data`; `null` si `data` no es una
/// lista (contrato roto, no "lista vacía").
List<Map<String, dynamic>>? itemsOf(Object? data) {
  if (data is! List<dynamic>) return null;
  return data.whereType<Map<String, dynamic>>().toList();
}

/// Categorías raíz. `parentId` nulo o 0 = raíz (WooCommerce usa 0). Se
/// descartan los elementos sin `id`, `slug` o `name`.
List<HomeCategory> mapCategories(List<Map<String, dynamic>> items) => [
  for (final dto in items.map(CategoryDto.fromJson))
    if (dto.id != null &&
        (dto.slug?.isNotEmpty ?? false) &&
        (dto.name?.isNotEmpty ?? false) &&
        (dto.parentId == null || dto.parentId == 0))
      HomeCategory(id: dto.id!, slug: dto.slug!, name: dto.name!),
];

/// Marcas con página propia. `hasLanding = false` (o ausente) no se muestra:
/// qué debería abrir una marca sin página es DESCONOCIDO en el contrato.
List<HomeBrand> mapBrands(List<Map<String, dynamic>> items) => [
  for (final dto in items.map(BrandDto.fromJson))
    if ((dto.slug?.isNotEmpty ?? false) &&
        (dto.name?.isNotEmpty ?? false) &&
        (dto.hasLanding ?? false))
      HomeBrand(slug: dto.slug!, name: dto.name!),
];

/// Ciudades con sedes, agrupadas desde `/stores`. Se descartan las sedes sin
/// ciudad. Primero las ciudades con más sedes abiertas (empate: por nombre) y
/// al final las que solo tienen sedes por abrir.
List<HomeCity> mapCities(List<Map<String, dynamic>> items) {
  final open = <String, int>{};
  for (final dto in items.map(StoreCityDto.fromJson)) {
    final city = dto.city;
    if (city == null || city.isEmpty) continue;
    open[city] = (open[city] ?? 0) + ((dto.upcoming ?? false) ? 0 : 1);
  }
  return [
    for (final entry in open.entries)
      HomeCity(
        name: entry.key,
        branchCount: entry.value,
        upcoming: entry.value == 0,
      ),
  ]..sort((a, b) {
    if (a.upcoming != b.upcoming) return a.upcoming ? 1 : -1;
    final byCount = b.branchCount.compareTo(a.branchCount);
    return byCount != 0 ? byCount : a.name.compareTo(b.name);
  });
}

/// Productos. Mapeo tolerante: sin `id`, `slug` o `name` se descarta; precio
/// 0/ausente → [OnRequest] (nunca "$0"); disponibilidad desconocida →
/// [StockStatus.unknown].
List<ProductSummary> mapProducts(List<Map<String, dynamic>> items) => [
  for (final dto in items.map(ProductSummaryDto.fromJson))
    if (dto.id != null &&
        (dto.slug?.isNotEmpty ?? false) &&
        (dto.name?.isNotEmpty ?? false))
      _product(dto),
];

ProductSummary _product(ProductSummaryDto dto) {
  final price = PriceStatus.fromContract(
    status: dto.priceStatus,
    amount: dto.priceAmount,
  );
  return ProductSummary(
    id: dto.id!,
    slug: dto.slug!,
    name: dto.name!,
    sku: dto.sku ?? '',
    brandName: dto.brandName,
    brandSlug: dto.brandSlug,
    price: price,
    regularPrice: Money.tryFromJson(dto.regularAmount),
    onSale: dto.onSale ?? false,
    availability: StockStatus.fromContract(dto.availability),
    image: ImageRef.tryFromJson(dto.image),
    categorySlugs: dto.categorySlugs,
  );
}
