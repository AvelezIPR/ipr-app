import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/features/catalog/data/datasources/catalog_remote_datasource.dart';
import 'package:ipr_mobile/features/catalog/data/mappers/catalog_mappers.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/filter_dimension.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/product_filters.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/product_query.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/product_sort.dart';
import 'package:ipr_mobile/shared/domain/money.dart';
import 'package:ipr_mobile/shared/domain/price_status.dart';
import 'package:ipr_mobile/shared/domain/stock_status.dart';

import '../../../fixtures/catalog/catalog_fixtures.dart';

FilterChoice choice(String key, String value, {bool boolean = false}) =>
    FilterChoice(
      key: key,
      value: value,
      keyLabel: key,
      valueLabel: value,
      boolean: boolean,
    );

void main() {
  group('M1 · RF-010 · mapCategories', () {
    test('conserva jerarquía y orden del servidor', () {
      final roots = mapCategories(categoriesBody());
      expect(roots.map((r) => r.slug), ['aire-acondicionado', 'herramientas']);
      final aire = roots.first;
      expect(aire.children.map((c) => c.slug), ['minisplit', 'cassette']);
      expect(aire.children.last.children.single.slug, 'cassette-inverter');
      expect(aire.children.first.isLeaf, isTrue);
      expect(roots.last.isLeaf, isTrue);
      expect(aire.children.first.parentId, 15);
    });

    test('omite elementos ilegibles sin romper el resto', () {
      final roots = mapCategories({
        'data': [
          'texto',
          {'id': 'x', 'slug': 'a', 'name': 'A'},
          {'id': 1, 'slug': '', 'name': 'sin slug'},
          {
            'id': 2,
            'slug': 'ok',
            'name': 'OK',
            'children': [
              {'id': 3},
              {'id': 4, 'slug': 'hijo', 'name': 'Hijo'},
            ],
          },
        ],
      });
      expect(roots.single.slug, 'ok');
      expect(roots.single.children.single.slug, 'hijo');
    });

    test('un cuerpo que no es {data: [...]} lanza FormatException', () {
      expect(() => mapCategories(<String, dynamic>{}), throwsFormatException);
      expect(() => mapCategories('<html>'), throwsFormatException);
      expect(() => mapCategories({'data': 3}), throwsFormatException);
    });
  });

  group('M1 · RF-016 · mapBrands', () {
    test('mapea logo y landing; sin logo es null', () {
      final brands = mapBrands(brandsBody());
      expect(brands, hasLength(2));
      expect(brands.first.logoUrl, 'https://staging.invalid/logos/elitech.png');
      expect(brands.first.hasLanding, isTrue);
      expect(brands.last.logoUrl, isNull);
      expect(brands.last.hasLanding, isFalse);
    });

    test('omite marcas sin slug o nombre', () {
      expect(
        mapBrands({
          'data': [
            {'slug': 'a'},
            {'name': 'B'},
            7,
            {'slug': 'c', 'name': 'C'},
          ],
        }).single.slug,
        'c',
      );
    });
  });

  group('M1 · RF-014 · mapFilters (nunca inventa dimensiones)', () {
    test('mapea las dimensiones del contrato', () {
      final dims = mapFilters(filtersBody());
      expect(dims.map((d) => d.key), [
        'brand',
        'attr[pa_capacidad-btu]',
        'onSale',
      ]);
      expect(dims[1].options.map((o) => o.label), [
        '9.000',
        '12.000',
        '18.000',
      ]);
      expect(dims[2].type, FilterDimensionType.boolean);
      expect(dims[0].type, FilterDimensionType.multi);
    });

    test(
      'descarta claves que /products no acepta y dimensiones sin opciones',
      () {
        final dims = mapFilters({
          'data': [
            {
              'key': 'precio',
              'label': 'Precio',
              'type': 'multi',
              'options': [
                {'value': 'a', 'label': 'A'},
              ],
            },
            {
              'key': 'brand',
              'label': 'Marca',
              'type': 'multi',
              'options': <Object?>[],
            },
            {
              'key': 'tag',
              'label': 'Etiqueta',
              'type': 'rango-futuro',
              'options': [
                {'value': 'x', 'label': 'X'},
                {'value': '', 'label': 'vacío'},
                {'label': 'sin valor'},
              ],
            },
          ],
        });
        expect(dims.single.key, 'tag');
        // Tipo nuevo → multi; opciones inválidas fuera.
        expect(dims.single.type, FilterDimensionType.multi);
        expect(dims.single.options.single.value, 'x');
      },
    );
  });

  group('M1 · RF-011/012 · mapProductSummary', () {
    test('precio con cifra, marca, stock e imagen', () {
      final p = mapProductSummary(fixture('ProductSummary.priced.json'))!;
      expect(p.id, 101);
      expect(p.brandName, 'Elitech');
      expect(p.brandSlug, 'elitech');
      expect(p.price, const Priced(Money(1445000)));
      expect(p.availability, StockStatus.inStock);
      expect(p.image?.url, 'https://staging.invalid/img/detector.jpg');
      expect(p.categorySlugs, ['herramientas']);
      expect(p.strikeThroughPrice, isNull);
    });

    test(r'TC-052 · AC-012-1 · sin precio → OnRequest, nunca "$0"', () {
      final p = mapProductSummary(fixture('ProductSummary.on-request.json'))!;
      expect(p.price, isA<OnRequest>());
      expect(p.canAddToCart, isFalse);
      expect(p.image, isNull);
    });

    test(
      'AC-012-4 · precio 0, negativo, ausente o no numérico → OnRequest',
      () {
        for (final amount in <Object?>[0, -5, null, 'mil', 1500.5, <int>[]]) {
          final json = fixture('ProductSummary.priced.json');
          (json['price'] as Map<String, dynamic>)['amount'] = amount;
          expect(
            mapProductSummary(json)!.price,
            isA<OnRequest>(),
            reason: 'amount=$amount',
          );
        }
        final json = fixture('ProductSummary.priced.json')..remove('price');
        expect(mapProductSummary(json)!.price, isA<OnRequest>());
      },
    );

    test('AC-018-1 · oferta real conserva el precio regular tachado', () {
      final p = mapProductSummary(fixture('ProductSummary.on-sale.json'))!;
      expect(p.onSale, isTrue);
      expect(p.price, const Priced(Money(1890000)));
      expect(p.regularPrice, const Money(2350000));
      expect(p.strikeThroughPrice, const Money(2350000));
    });

    test('disponibilidad nueva → unknown; sin marca ni imagen no rompe', () {
      final p = mapProductSummary(
        fixture('ProductSummary.unknown-availability.json'),
      )!;
      expect(p.availability, StockStatus.unknown);
      expect(p.brandName, isNull);
      final agotado = mapProductSummary(
        fixture('ProductSummary.no-image.json'),
      )!;
      expect(agotado.availability, StockStatus.outOfStock);
    });

    test('sin id, slug o nombre válidos → se omite (null)', () {
      expect(mapProductSummary(null), isNull);
      expect(mapProductSummary({'id': 0, 'slug': 'a', 'name': 'A'}), isNull);
      expect(mapProductSummary({'id': 1, 'name': 'A'}), isNull);
      expect(mapProductSummary({'id': 1, 'slug': 'a'}), isNull);
      // SKU ausente: se tolera como vacío.
      expect(
        mapProductSummary({'id': 1, 'slug': 'a', 'name': 'A'})!.sku,
        isEmpty,
      );
    });
  });

  group('M1 · RF-011 · mapProductPage', () {
    test('lee meta y omite productos ilegibles', () {
      final page = mapProductPage({
        'data': [
          product(1),
          {'id': 'roto'},
          product(2),
        ],
        'meta': {
          'page': 1,
          'perPage': 24,
          'total': 60,
          'totalPages': 3,
          'hasMore': true,
        },
      }, requestedPage: 1);
      expect(page.items.map((p) => p.id), [1, 2]);
      expect(page.total, 60);
      expect(page.totalPages, 3);
      expect(page.perPage, 24);
      expect(page.hasMore, isTrue);
    });

    test('sin meta: hasMore es falso y la página es la pedida', () {
      final page = mapProductPage({
        'data': [product(1)],
      }, requestedPage: 4);
      expect(page.page, 4);
      expect(page.total, isNull);
      expect(page.hasMore, isFalse);
    });

    test('sin hasMore pero con totalPages, se deduce', () {
      final page = mapProductPage({
        'data': [product(1)],
        'meta': {'page': 1, 'totalPages': 2},
      }, requestedPage: 1);
      expect(page.hasMore, isTrue);
    });

    test('un cuerpo irreconocible lanza FormatException', () {
      expect(
        () => mapProductPage('x', requestedPage: 1),
        throwsFormatException,
      );
    });
  });

  group(
    'M1 · contrato · buildProductRequest (solo parámetros del contrato)',
    () {
      ProductQuery q(
        ListScope scope, {
        ProductFilters filters = ProductFilters.empty,
        int page = 1,
      }) => ProductQuery(scope: scope, filters: filters, page: page);

      test(
        'categoría: category, page y perPage; sin sort si es el de contrato',
        () {
          final r = buildProductRequest(
            q(const ListScope.category('minisplit')),
          );
          expect(r.path, '/products');
          expect(r.query, {'page': 1, 'perPage': 24, 'category': 'minisplit'});
          expect(r.requiresAuth, isFalse);
          expect(r.method, 'GET');
        },
      );

      test('listado general sin categoría', () {
        expect(buildProductRequest(q(const ListScope.all())).query, {
          'page': 1,
          'perPage': 24,
        });
      });

      test('AC-013-2 · marca + categoría + atributo a la vez', () {
        final filters = ProductFilters.empty
            .toggled(choice('brand', 'elitech'))
            .toggled(choice('brand', 'refco'))
            .toggled(choice('attr[pa_capacidad-btu]', '12-000-btu'))
            .toggled(choice('onSale', 'true', boolean: true))
            .withSort(ProductSort.priceAsc);
        final r = buildProductRequest(
          q(const ListScope.category('minisplit'), filters: filters, page: 2),
        );
        expect(r.query, {
          'page': 2,
          'perPage': 24,
          'category': 'minisplit',
          'sort': 'price-asc',
          'brand': 'elitech,refco',
          'attr[pa_capacidad-btu]': '12-000-btu',
          'onSale': 'true',
        });
      });

      test('la categoría elegida en el filtro sustituye a la del contexto', () {
        final r = buildProductRequest(
          q(
            const ListScope.category('aire-acondicionado'),
            filters: ProductFilters.empty.withCategory(
              const CategoryChoice(slug: 'cassette', name: 'Cassette'),
            ),
          ),
        );
        expect(r.query!['category'], 'cassette');
      });

      test(
        'landing de marca: brand fijo; el filtro de marca no se duplica',
        () {
          final r = buildProductRequest(
            q(
              const ListScope.brand('elitech'),
              filters: ProductFilters.empty
                  .toggled(choice('brand', 'otra'))
                  .toggled(choice('attr[pa_capacidad-btu]', '9-000-btu')),
            ),
          );
          expect(r.path, '/products');
          expect(r.query!['brand'], 'elitech');
          expect(r.query!['attr[pa_capacidad-btu]'], '9-000-btu');
        },
      );

      test('RF-016 · búsqueda interna de marca usa /search?q&brand', () {
        final r = buildProductRequest(
          q(
            const ListScope.brand('elitech'),
            filters: ProductFilters.empty.withSearch('manómetro'),
          ),
        );
        expect(r.path, '/search');
        expect(r.query, {
          'q': 'manómetro',
          'brand': 'elitech',
          'page': 1,
          'perPage': 24,
        });
      });

      test('RF-018 · liquidaciones: solo sort, page y perPage', () {
        final r = buildProductRequest(
          q(
            const ListScope.sale(),
            filters: ProductFilters.empty
                .toggled(choice('brand', 'x'))
                .withSort(ProductSort.priceDesc),
          ),
        );
        expect(r.path, '/liquidaciones');
        expect(r.query, {'page': 1, 'perPage': 24, 'sort': 'price-desc'});
      });

      test('descarta claves no admitidas y respeta los máximos', () {
        // Se arma el filtro a mano para saltar las guardas de `toggled`.
        final many = ProductFilters(
          choices: [
            choice('precio', '1'),
            for (var i = 0; i < 8; i++) choice('brand', 'm$i'),
            for (var i = 0; i < 7; i++) choice('attr[pa_a$i]', 'v'),
          ],
        );
        final r = buildProductRequest(q(const ListScope.all(), filters: many));
        expect(r.query!.containsKey('precio'), isFalse);
        expect((r.query!['brand']! as String).split(','), hasLength(5));
        final attrs = r.query!.keys.where((k) => k.startsWith('attr['));
        expect(attrs, hasLength(5));
      });
    },
  );
}
