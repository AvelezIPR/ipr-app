import 'package:ipr_mobile/features/product_detail/data/dtos/product_detail_dto.dart';
import 'package:ipr_mobile/features/product_detail/domain/entities/product_detail.dart';
import 'package:ipr_mobile/shared/domain/image_ref.dart';
import 'package:ipr_mobile/shared/domain/money.dart';
import 'package:ipr_mobile/shared/domain/price_status.dart';
import 'package:ipr_mobile/shared/domain/product_summary.dart';
import 'package:ipr_mobile/shared/domain/stock_status.dart';

/// DTO → entidad. Los valores nuevos o ilegibles caen en el caso seguro:
/// precio ausente, 0 o ilegible → [OnRequest]; disponibilidad desconocida →
/// no comprable.
extension ProductDetailMapper on ProductDetailDto {
  ProductDetail toEntity() {
    final priceDto = price;
    final status = PriceStatus.fromContract(
      status: priceDto?.status,
      amount: priceDto?.amount,
    );
    final regular = Money.tryFromJson(priceDto?.regularAmount);
    final image = ImageRef.tryFromJson(this.image);
    final summary = ProductSummary(
      id: id,
      slug: slug,
      name: name,
      sku: sku ?? '',
      brandName: brand?.name,
      brandSlug: brand?.slug,
      price: status,
      regularPrice: regular,
      onSale: priceDto?.onSale ?? false,
      availability: StockStatus.fromContract(availability),
      image: image,
      categorySlugs: categorySlugs,
    );
    return ProductDetail(
      summary: summary,
      shortDescription: shortDescription ?? '',
      descriptionHtml: descriptionHtml ?? '',
      gallery: gallery.map(ImageRef.tryFromJson).whereType<ImageRef>().toList(),
      attributes: [
        for (final a in attributes)
          if (a.options.isNotEmpty)
            ProductAttribute(name: a.name, slug: a.slug, options: a.options),
      ],
      categories: [
        for (final c in categories)
          ProductCategory(id: c.id, slug: c.slug, name: c.name),
      ],
      webUrl: webUrl,
      serverPurchasable: purchasable ?? true,
    );
  }
}
