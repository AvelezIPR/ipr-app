import 'package:ipr_mobile/core/config/home_content.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/brand.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/brand_landing.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/category_node.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/filter_dimension.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/product_page.dart';
import 'package:ipr_mobile/shared/domain/image_ref.dart';
import 'package:ipr_mobile/shared/domain/money.dart';
import 'package:ipr_mobile/shared/domain/price_status.dart';
import 'package:ipr_mobile/shared/domain/product_summary.dart';
import 'package:ipr_mobile/shared/domain/quantity_range.dart';
import 'package:ipr_mobile/shared/domain/stock_status.dart';

/// Mapeo tolerante del contrato `/mobile/v1` a entidades. Una estructura
/// irreconocible (el cuerpo no es `{data: [...]}`) lanza [FormatException]
/// (el repositorio la convierte en `ContractFailure`); un elemento suelto
/// ilegible se omite sin romper el resto.

List<Object?> _dataList(Object? body) {
  if (body is Map<String, dynamic>) {
    final data = body['data'];
    if (data is List<Object?>) return data;
  }
  throw const FormatException('se esperaba {data: [...]}');
}

String? _string(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

/// `GET /categories` → raíces con hijos anidados (orden del servidor).
List<CategoryNode> mapCategories(Object? body) => [
  for (final item in _dataList(body)) ?_category(item),
];

CategoryNode? _category(Object? json) {
  if (json is! Map<String, dynamic>) return null;
  final id = json['id'];
  final slug = _string(json['slug']);
  final name = _string(json['name']);
  if (id is! int || slug == null || name == null) return null;
  final parent = json['parentId'];
  final children = json['children'];
  return CategoryNode(
    id: id,
    slug: slug,
    name: name,
    parentId: parent is int ? parent : null,
    children: children is List<Object?>
        ? [for (final child in children) ?_category(child)]
        : const [],
  );
}

/// `GET /brands`.
List<Brand> mapBrands(Object? body) => [
  for (final item in _dataList(body)) ?_brand(item),
];

Brand? _brand(Object? json) {
  if (json is! Map<String, dynamic>) return null;
  final slug = _string(json['slug']);
  final name = _string(json['name']);
  if (slug == null || name == null) return null;
  return Brand(
    slug: slug,
    name: name,
    logoUrl: _string(json['logoUrl']),
    hasLanding: json['hasLanding'] == true,
  );
}

/// `GET /filters`. Se descartan las dimensiones cuya clave no es un parámetro
/// de `/products` (no se podría aplicar) y las que no traen opciones
/// (AC-014-2: nunca una sección vacía). Los valores nuevos de `type` se
/// tratan como `multi`.
List<FilterDimension> mapFilters(Object? body) => [
  for (final item in _dataList(body)) ?_dimension(item),
];

FilterDimension? _dimension(Object? json) {
  if (json is! Map<String, dynamic>) return null;
  final key = _string(json['key']);
  final label = _string(json['label']);
  if (key == null || label == null || !FilterKeys.isSupported(key)) {
    return null;
  }
  final rawOptions = json['options'];
  final options = <FilterOption>[
    if (rawOptions is List<Object?>)
      for (final o in rawOptions)
        if (o is Map<String, dynamic> &&
            _string(o['value']) != null &&
            _string(o['label']) != null)
          FilterOption(
            value: o['value']! as String,
            label: o['label']! as String,
          ),
  ];
  if (options.isEmpty) return null;
  return FilterDimension(
    key: key,
    label: label,
    type: json['type'] == 'boolean'
        ? FilterDimensionType.boolean
        : FilterDimensionType.multi,
    options: options,
  );
}

/// `ProductPage` (`{data: [...], meta: {...}}`) de `listProducts`,
/// `listClearanceProducts` y la búsqueda interna de marca.
ProductPage mapProductPage(Object? body, {required int requestedPage}) {
  final items = [for (final item in _dataList(body)) ?mapProductSummary(item)];
  final meta = (body! as Map<String, dynamic>)['meta'];
  final m = meta is Map<String, dynamic> ? meta : const <String, dynamic>{};
  final page = m['page'] is int ? m['page']! as int : requestedPage;
  final totalPages = m['totalPages'] is int ? m['totalPages'] as int : null;
  final hasMore = m['hasMore'] is bool
      ? m['hasMore']! as bool
      : (totalPages != null && page < totalPages);
  return ProductPage(
    items: items,
    page: page,
    hasMore: hasMore,
    perPage: m['perPage'] is int ? m['perPage'] as int : null,
    total: m['total'] is int ? m['total'] as int : null,
    totalPages: totalPages,
  );
}

/// `ProductSummary`. Precio 0/ausente/no entero → [OnRequest] (nunca "$0",
/// RF-012); disponibilidad nueva → [StockStatus.unknown].
ProductSummary? mapProductSummary(Object? json) {
  if (json is! Map<String, dynamic>) return null;
  final id = json['id'];
  final slug = _string(json['slug']);
  final name = _string(json['name']);
  if (id is! int || id < 1 || slug == null || name == null) return null;

  final price = json['price'];
  final priceMap = price is Map<String, dynamic>
      ? price
      : const <String, Object?>{};
  final brand = json['brand'];
  final categories = json['categorySlugs'];

  return ProductSummary(
    id: id,
    slug: slug,
    name: name,
    sku: json['sku'] is String ? json['sku']! as String : '',
    brandName: brand is Map<String, dynamic> ? _string(brand['name']) : null,
    brandSlug: brand is Map<String, dynamic> ? _string(brand['slug']) : null,
    price: PriceStatus.fromContract(
      status: priceMap['status'] is String
          ? priceMap['status']! as String
          : null,
      amount: priceMap['amount'],
    ),
    regularPrice: Money.tryFromJson(priceMap['regularAmount']),
    onSale: priceMap['onSale'] == true,
    availability: StockStatus.fromContract(
      json['availability'] is String ? json['availability']! as String : null,
    ),
    image: ImageRef.tryFromJson(json['image']),
    categorySlugs: categories is List<Object?>
        ? [
            for (final c in categories)
              if (c is String) c,
          ]
        : const [],
    hasVariants: json['hasVariants'] == true,
    priceFrom: json['hasVariants'] == true
        ? _nonZero(Money.tryFromJson(json['priceFrom']))
        : null,
    quantityRange: QuantityRange.fromContract(
      min: json['minQuantity'],
      max: json['maxQuantity'],
    ),
  );
}

/// Un precio 0 nunca se muestra (RF-012): se trata como ausente.
Money? _nonZero(Money? money) => money == null || money.isZero ? null : money;

/// `GET /brands/{slug}` → contenido editorial de la landing (W3-01).
///
/// Lectura **tolerante**: un bloque de un tipo desconocido, sin lo mínimo para
/// pintarse o con un destino inválido se omite sin romper el resto; el texto
/// es plano y los destinos solo los que la app sabe abrir (`HomeTarget`). Un
/// cuerpo que no es `{data: {...}}` lanza [FormatException].
BrandLanding mapBrandLanding(Object? body) {
  final data = body is Map<String, dynamic> ? body['data'] : null;
  if (data is! Map<String, dynamic>) {
    throw const FormatException('se esperaba {data: {...}}');
  }
  final slug = _string(data['slug']);
  if (slug == null) throw const FormatException('landing sin slug');
  final raw = data['blocks'];
  final blocks = <BrandBlock>[];
  if (raw is List<Object?>) {
    for (final item in raw) {
      if (blocks.length >= _maxBrandBlocks) break;
      if (item is! Map<String, dynamic>) continue;
      final block = _brandBlock(item);
      if (block != null) blocks.add(block);
    }
  }
  return BrandLanding(slug: slug, blocks: List.unmodifiable(blocks));
}

const _maxBrandBlocks = 12;
const _maxBrandItems = 12;

String? _plain(Object? value, {int max = 2000}) {
  if (value is! String) return null;
  final text = value.trim();
  return text.isEmpty || text.length > max ? null : text;
}

String? _httpsImage(Object? image) {
  if (image is! Map<String, dynamic>) return null;
  final url = image['url'];
  if (url is! String) return null;
  final uri = Uri.tryParse(url);
  if (uri == null ||
      uri.scheme.toLowerCase() != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return url;
}

List<BrandBlockItem> _brandItems(Object? raw) {
  if (raw is! List<Object?>) return const [];
  final out = <BrandBlockItem>[];
  for (final item in raw) {
    if (out.length >= _maxBrandItems) break;
    if (item is! Map<String, dynamic>) continue;
    final title = _plain(item['title'], max: 200);
    final body = _plain(item['body']);
    if (title != null && body != null) {
      out.add(BrandBlockItem(title: title, body: body));
    }
  }
  return List.unmodifiable(out);
}

BrandBlock? _brandBlock(Map<String, dynamic> json) {
  final type = BrandBlockType.tryParse(json['type']);
  if (type == null) return null;
  final title = _plain(json['title'], max: 200);
  final subtitle = _plain(json['subtitle'], max: 400);
  final body = _plain(json['body']);
  final ctaLabel = _plain(json['ctaLabel'], max: 60);
  final target = HomeTarget.tryFromJson(json['target']);
  // Un destino a medias no se ofrece: el botón necesita etiqueta y destino.
  final cta = ctaLabel != null && target != null;

  switch (type) {
    case BrandBlockType.hero:
      if (title == null) return null;
      return BrandBlock(
        type: type,
        title: title,
        subtitle: subtitle,
        imageUrl: _httpsImage(json['image']),
        accentArgb: BrandAccent.tryParse(
          json['accentColor'] is String ? json['accentColor']! as String : null,
        ),
        ctaLabel: cta ? ctaLabel : null,
        target: cta ? target : null,
      );
    case BrandBlockType.text:
      if (body == null) return null;
      return BrandBlock(type: type, title: title, body: body);
    case BrandBlockType.highlights:
    case BrandBlockType.faq:
      final items = _brandItems(json['items']);
      if (items.isEmpty) return null;
      return BrandBlock(type: type, title: title, items: items);
    case BrandBlockType.cta:
      if (title == null || !cta) return null;
      return BrandBlock(
        type: type,
        title: title,
        body: body,
        ctaLabel: ctaLabel,
        target: target,
      );
  }
}
