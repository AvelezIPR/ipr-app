import 'dart:convert';
import 'dart:io';

/// Lee un fixture de contrato de `test/fixtures/catalog/` (las pruebas corren
/// desde la raíz del proyecto).
Map<String, dynamic> fixture(String name) =>
    jsonDecode(File('test/fixtures/catalog/$name').readAsStringSync())
        as Map<String, dynamic>;

/// Un `ProductSummary` válido derivado de `ProductSummary.priced.json` con
/// id, slug, nombre y SKU únicos (para armar páginas sin repetir ids).
Map<String, dynamic> product(
  int id, {
  String? name,
  String base = 'ProductSummary.priced.json',
}) {
  final json = fixture(base);
  return {
    ...json,
    'id': id,
    'slug': 'producto-$id',
    'name': name ?? 'Producto de prueba $id',
    'sku': 'SKU-$id',
  };
}

/// `ProductPage`: `{data: [...], meta: {...}}`.
Map<String, dynamic> productPage(
  List<Map<String, dynamic>> items, {
  int page = 1,
  int perPage = 24,
  int? total,
  bool hasMore = false,
}) => {
  'data': items,
  'meta': {
    'page': page,
    'perPage': perPage,
    'total': total ?? items.length,
    'totalPages': hasMore ? page + 1 : page,
    'hasMore': hasMore,
  },
};

/// `n` productos con ids consecutivos desde [from].
List<Map<String, dynamic>> products(int n, {int from = 1}) => [
  for (var i = 0; i < n; i++) product(from + i),
];

Map<String, dynamic> categoriesBody() => {
  'data': [fixture('Category.root.json'), fixture('Category.leaf.json')],
};

Map<String, dynamic> brandsBody() => {
  'data': [fixture('Brand.valid.json'), fixture('Brand.no-logo.json')],
};

Map<String, dynamic> filtersBody() => {
  'data': [
    fixture('FilterDimension.brand.json'),
    fixture('FilterDimension.btu.json'),
    fixture('FilterDimension.on-sale.json'),
  ],
};
