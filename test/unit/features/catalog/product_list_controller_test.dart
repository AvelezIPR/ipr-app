import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/brand.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/filter_dimension.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/product_filters.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/product_query.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/product_sort.dart';
import 'package:ipr_mobile/features/catalog/presentation/controllers/product_list_controller.dart';
import 'package:ipr_mobile/features/catalog/presentation/controllers/taxonomy_controllers.dart';
import 'package:ipr_mobile/shared/widgets/ui_state.dart';

import '../../../fixtures/catalog/catalog_fixtures.dart';
import '../../../fixtures/catalog/fake_catalog_bff.dart';
import '../../../mocks/fake_http_adapter.dart';

const scope = ListScope.category('minisplit');

FilterChoice brandChoice(String slug) => FilterChoice(
  key: 'brand',
  value: slug,
  keyLabel: 'Marca',
  valueLabel: slug,
);

/// Espera a que el estado deje de ser `UiLoading` (y a que no haya trabajo
/// pendiente en la cola de eventos).
Future<void> settle(ProviderContainer container, [int turns = 20]) async {
  for (var i = 0; i < turns; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

ProductListData dataOf(ProviderContainer c) {
  final state = c.read(productListProvider(scope));
  expect(state, isA<UiData<ProductListData>>(), reason: '$state');
  return (state as UiData<ProductListData>).value;
}

void main() {
  late FakeCatalogBff bff;
  late ProviderContainer container;

  ProviderContainer build() {
    final c = ProviderContainer(overrides: bff.overrides());
    addTearDown(c.dispose);
    // Mantiene vivo el proveedor autoDispose durante la prueba.
    c.listen(productListProvider(scope), (_, _) {});
    return c;
  }

  setUp(() {
    bff = FakeCatalogBff();
  });

  ProductListController notifier() =>
      container.read(productListProvider(scope).notifier);

  group('M1 · RF-011 · paginación infinita', () {
    setUp(() {
      // 3 páginas de 12 (60 en total declarado, como TC-118).
      bff.on('/products', (o) {
        final page = o.queryParameters['page'] as int;
        return FakeHttpAdapter.json(
          productPage(
            products(12, from: (page - 1) * 12 + 1),
            page: page,
            total: 36,
            hasMore: page < 3,
          ),
        );
      });
      container = build();
    });

    test('carga la página 1 y expone el contador del servidor', () async {
      expect(
        container.read(productListProvider(scope)),
        isA<UiLoading<ProductListData>>(),
      );
      await settle(container);
      final data = dataOf(container);
      expect(data.items, hasLength(12));
      expect(data.total, 36);
      expect(data.resultCount, 36);
      expect(data.hasMore, isTrue);
      expect(bff.to('/products'), hasLength(1));
      expect(
        bff.to('/products').single.queryParameters['category'],
        'minisplit',
      );
    });

    test(
      'AC-011-2 · una sola solicitud por página aunque se pida varias veces',
      () async {
        await settle(container);
        final calls = [
          notifier().loadMore(),
          notifier().loadMore(),
          notifier().loadMore(),
        ];
        await Future.wait(calls);
        await settle(container);
        expect(bff.to('/products'), hasLength(2));
        expect(dataOf(container).items, hasLength(24));
        expect(dataOf(container).items.map((p) => p.id).toSet(), hasLength(24));
      },
    );

    test('AC-011-3 · tras la última página no hay más solicitudes', () async {
      await settle(container);
      await notifier().loadMore();
      await notifier().loadMore();
      expect(dataOf(container).hasMore, isFalse);
      expect(dataOf(container).items, hasLength(36));
      final before = bff.to('/products').length;
      await notifier().loadMore();
      await notifier().loadMore();
      expect(bff.to('/products'), hasLength(before));
      expect(before, 3);
    });

    test(
      'AC-011-8 · ids repetidos del servidor no duplican tarjetas',
      () async {
        bff.on('/products', (o) {
          final page = o.queryParameters['page'] as int;
          // La página 2 repite los ids 11 y 12 de la página 1.
          return FakeHttpAdapter.json(
            productPage(
              products(12, from: page == 1 ? 1 : 11),
              page: page,
              hasMore: page < 2,
            ),
          );
        });
        container = build();
        await settle(container);
        await notifier().loadMore();
        final ids = dataOf(container).items.map((p) => p.id).toList();
        expect(ids, hasLength(22));
        expect(ids.toSet(), hasLength(22));
      },
    );

    test(
      'AC-011-8 · una página solo con repetidos pide la siguiente',
      () async {
        bff.on('/products', (o) {
          final page = o.queryParameters['page'] as int;
          final items = switch (page) {
            1 => products(3),
            2 => products(3),
            _ => products(2, from: 4),
          };
          return FakeHttpAdapter.json(
            productPage(items, page: page, hasMore: page < 3),
          );
        });
        container = build();
        await settle(container);
        await notifier().loadMore();
        await settle(container);
        expect(dataOf(container).items.map((p) => p.id), [1, 2, 3, 4, 5]);
        expect(dataOf(container).hasMore, isFalse);
      },
    );

    test('una página vacía final con hasMore=true cierra la lista', () async {
      bff.on('/products', (o) {
        final page = o.queryParameters['page'] as int;
        return FakeHttpAdapter.json(
          productPage(page == 1 ? products(2) : [], page: page, hasMore: true),
        );
      });
      container = build();
      await settle(container);
      await notifier().loadMore();
      expect(dataOf(container).hasMore, isFalse);
      expect(dataOf(container).items, hasLength(2));
    });

    test('el contrato limita a 50 páginas', () async {
      bff.on('/products', (o) {
        final page = o.queryParameters['page'] as int;
        return FakeHttpAdapter.json(
          productPage(products(1, from: page), page: page, hasMore: true),
        );
      });
      container = build();
      await settle(container);
      for (var i = 0; i < 60; i++) {
        await notifier().loadMore();
      }
      final pages = bff
          .to('/products')
          .map((r) => r.queryParameters['page']! as int);
      expect(pages.reduce((a, b) => a > b ? a : b), ProductQuery.maxPage);
      expect(dataOf(container).hasMore, isFalse);
    });
  });

  group('M1 · RF-009 · fallos de página (TC-101)', () {
    var failPage3 = true;

    setUp(() {
      failPage3 = true;
      bff.on('/products', (o) {
        final page = o.queryParameters['page'] as int;
        if (page == 3 && failPage3) {
          return FakeHttpAdapter.problem(503, 'service_unavailable');
        }
        return FakeHttpAdapter.json(
          productPage(
            products(12, from: (page - 1) * 12 + 1),
            page: page,
            hasMore: page < 3,
          ),
        );
      });
      container = build();
    });

    test('AC-009-5 · falla la página 3: se conservan las 2 anteriores y se reintenta solo esa', () async {
      await settle(container);
      await notifier().loadMore();
      await notifier().loadMore(); // página 3 → 503 (con sus reintentos)
      var data = dataOf(container);
      expect(data.items, hasLength(24));
      expect(data.pageFailure, isA<ServiceUnavailable>());
      expect(data.loadingMore, isFalse);

      // Sin reintento explícito no se vuelve a pedir sola.
      final before = bff.to('/products').length;
      await notifier().loadMore();
      expect(bff.to('/products'), hasLength(before));

      failPage3 = false;
      await notifier().loadMore(retry: true);
      data = dataOf(container);
      expect(data.items, hasLength(36));
      expect(data.items.map((p) => p.id).toSet(), hasLength(36));
      expect(data.pageFailure, isNull);
      expect(data.hasMore, isFalse);
      // La página 3 fue la única repetida.
      expect(
        bff.to('/products').where((r) => r.queryParameters['page'] == 1),
        hasLength(1),
      );
    });
  });

  group('M1 · RF-013/015 · filtros y orden', () {
    setUp(() {
      bff.on('/products', (o) {
        final q = o.queryParameters;
        final brand = q['brand'] as String?;
        // 5 productos con filtro de marca, 12 sin él.
        final n = brand == null ? 12 : 5;
        return FakeHttpAdapter.json(
          productPage(
            products(n, from: brand == null ? 1 : 100),
            page: q['page'] as int,
            total: n,
          ),
        );
      });
      container = build();
    });

    test(
      'AC-013-1/6 · aplicar marca recarga desde la página 1 con el contador',
      () async {
        await settle(container);
        await notifier().applyFilters(
          notifier().filters.toggled(brandChoice('elitech')),
        );
        final data = dataOf(container);
        expect(data.items, hasLength(5));
        expect(data.resultCount, 5);
        expect(data.filters.choices.single.value, 'elitech');
        final last = bff.to('/products').last.queryParameters;
        expect(last['brand'], 'elitech');
        expect(last['page'], 1);
      },
    );

    test(
      'AC-015-2 · cambiar el orden conserva filtros y vuelve a la página 1',
      () async {
        await settle(container);
        await notifier().applyFilters(
          notifier().filters.toggled(brandChoice('elitech')),
        );
        await notifier().setSort(ProductSort.priceAsc);
        final data = dataOf(container);
        expect(data.filters.sort, ProductSort.priceAsc);
        expect(data.filters.choices, hasLength(1));
        final last = bff.to('/products').last.queryParameters;
        expect(last['sort'], 'price-asc');
        expect(last['brand'], 'elitech');
        expect(last['page'], 1);
      },
    );

    test('quitar un filtro y "Limpiar filtros" restauran el listado', () async {
      await settle(container);
      final f = notifier().filters.toggled(brandChoice('elitech'));
      await notifier().applyFilters(f);
      await notifier().removeChoice(brandChoice('elitech'));
      expect(dataOf(container).filters.hasActive, isFalse);
      expect(dataOf(container).items, hasLength(12));

      await notifier().applyFilters(f);
      await notifier().clearFilters();
      expect(dataOf(container).filters.hasActive, isFalse);

      await notifier().applyFilters(
        f.withCategory(const CategoryChoice(slug: 'cassette', name: 'C')),
      );
      await notifier().removeCategory();
      expect(dataOf(container).filters.category, isNull);
    });

    test('AC-013-5 · si falla aplicar, se conserva el listado y los filtros previos', () async {
      await settle(container);
      final before = dataOf(container);
      final pending = notifier().filters.toggled(brandChoice('elitech'));
      var fail = true;
      bff.on('/products', (o) {
        if (fail) return FakeHttpAdapter.problem(503, 'service_unavailable');
        return FakeHttpAdapter.json(productPage(products(5, from: 100)));
      });
      await notifier().applyFilters(pending);
      var data = dataOf(container);
      // No es "vacío": el listado anterior sigue y hay un fallo visible.
      expect(data.items.map((p) => p.id), before.items.map((p) => p.id));
      expect(data.filters.hasActive, isFalse);
      expect(data.applyFailure, isA<ServiceUnavailable>());
      expect(data.pendingFilters, pending);
      expect(data.refreshing, isFalse);

      fail = false;
      await notifier().retryApply();
      data = dataOf(container);
      expect(data.applyFailure, isNull);
      expect(data.filters.choices.single.value, 'elitech');
      expect(data.items, hasLength(5));
    });

    test('refresh vuelve a pedir la página 1 sin cambiar filtros', () async {
      await settle(container);
      await notifier().refresh();
      expect(bff.to('/products'), hasLength(2));
      expect(dataOf(container).items, hasLength(12));
    });

    test('una respuesta obsoleta se descarta (última petición gana)', () async {
      await settle(container);
      final slow = Completer<void>();
      bff.on('/products', (o) async {
        if (o.queryParameters['brand'] == 'lento') {
          await slow.future;
          return FakeHttpAdapter.json(productPage(products(3, from: 500)));
        }
        return FakeHttpAdapter.json(productPage(products(7, from: 200)));
      });
      final first = notifier().applyFilters(
        notifier().filters.toggled(brandChoice('lento')),
      );
      await Future<void>.delayed(Duration.zero);
      await notifier().applyFilters(
        ProductFilters.empty.toggled(brandChoice('rapido')),
      );
      slow.complete();
      await first;
      await settle(container);
      expect(dataOf(container).items, hasLength(7));
      expect(dataOf(container).filters.choices.single.value, 'rapido');
    });
  });

  group('M1 · RF-009/012 · primera carga', () {
    test(
      'error de red sin caché es UiFailure, nunca vacío; reload recupera',
      () async {
        var online = false;
        bff.on('/products', (o) {
          if (!online) return FakeHttpAdapter.connectionError(o);
          return FakeHttpAdapter.json(productPage(products(2)));
        });
        container = build();
        await settle(container, 100);
        final state = container.read(productListProvider(scope));
        expect(state, isA<UiFailure<ProductListData>>());
        expect(
          (state as UiFailure<ProductListData>).failure,
          isA<NoConnection>(),
        );

        online = true;
        await notifier().reload();
        expect(dataOf(container).items, hasLength(2));
      },
    );

    test('AC-009 · 404 es NotFound y 503 es ServiceUnavailable', () async {
      AppFailure? failureOf() {
        final state = container.read(productListProvider(scope));
        return state is UiFailure<ProductListData> ? state.failure : null;
      }

      bff.on('/products', (_) => FakeHttpAdapter.problem(404, 'not_found'));
      container = build();
      await settle(container);
      expect(failureOf(), isA<NotFound>());

      bff.on('/products', (_) => FakeHttpAdapter.problem(503, 'x'));
      await notifier().reload();
      expect(failureOf(), isA<ServiceUnavailable>());
    });

    test(
      '200 con lista vacía es datos vacíos (vacío real) y cuenta 0',
      () async {
        bff.on('/products', (_) => FakeHttpAdapter.json(productPage([])));
        container = build();
        await settle(container);
        final data = dataOf(container);
        expect(data.items, isEmpty);
        expect(data.resultCount, 0);
        expect(data.hasMore, isFalse);
      },
    );

    test('con filtros aplicados antes de cargar, aplica y carga', () async {
      bff.on(
        '/products',
        (_) => FakeHttpAdapter.json(productPage(products(1))),
      );
      container = build();
      // Aún UiLoading: applyFilters recarga con los filtros nuevos.
      await notifier().applyFilters(
        ProductFilters.empty.toggled(brandChoice('elitech')),
      );
      await settle(container);
      expect(dataOf(container).filters.choices.single.value, 'elitech');
    });

    test('AC-009 · dato guardado caducado + red caída → stale', () async {
      bff.on(
        '/products',
        (_) => FakeHttpAdapter.json(productPage(products(3))),
      );
      container = build();
      await settle(container);
      expect(
        (container.read(productListProvider(scope)) as UiData).stale,
        isFalse,
      );
      // Nueva sesión con la misma caché y sin red: forceRefresh (reload) usa la caché.
      bff.on('/products', FakeHttpAdapter.connectionError);
      await notifier().reload();
      final state = container.read(productListProvider(scope));
      expect(state, isA<UiData<ProductListData>>());
      expect((state as UiData<ProductListData>).stale, isTrue);
    });
  });

  group('M1 · RF-016 · búsqueda interna de marca', () {
    test(
      'search consulta /search?q&brand y limpiar vuelve a /products',
      () async {
        const brand = ListScope.brand('elitech');
        bff
          ..on(
            '/products',
            (_) => FakeHttpAdapter.json(productPage(products(4))),
          )
          ..on(
            '/search',
            (_) => FakeHttpAdapter.json(productPage(products(1, from: 50))),
          );
        final c = ProviderContainer(overrides: bff.overrides());
        addTearDown(c.dispose);
        c.listen(productListProvider(brand), (_, _) {});
        await settle(c);
        final n = c.read(productListProvider(brand).notifier);
        await n.search('  manómetro ');
        final state =
            c.read(productListProvider(brand)) as UiData<ProductListData>;
        expect(state.value.items.single.id, 50);
        expect(state.value.filters.searchTerm, 'manómetro');
        expect(bff.to('/search').single.queryParameters['q'], 'manómetro');
        expect(bff.to('/search').single.queryParameters['brand'], 'elitech');
        await n.search('   ');
        final back =
            c.read(productListProvider(brand)) as UiData<ProductListData>;
        expect(back.value.filters.isSearching, isFalse);
        expect(back.value.items, hasLength(4));
      },
    );
  });

  group('M1 · RF-010/014/016 · controladores de taxonomía', () {
    test('categorías: fallo sin caché es UiFailure, retry recupera y 200 vacío es UiEmpty', () async {
      var mode = 'down';
      bff.on('/categories', (o) {
        return switch (mode) {
          'ok' => FakeHttpAdapter.json(categoriesBody()),
          'empty' => FakeHttpAdapter.json({'data': <Object?>[]}),
          _ => FakeHttpAdapter.problem(503, 'x'),
        };
      });
      container = build()..listen(categoriesProvider, (_, _) {});
      await settle(container, 100);
      // Sin caché y con el servidor caído: fallo, no vacío.
      expect(container.read(categoriesProvider), isA<UiFailure<dynamic>>());

      mode = 'ok';
      await container.read(categoriesProvider.notifier).retry();
      expect(container.read(categoriesProvider), isA<UiData<dynamic>>());

      mode = 'empty';
      await container
          .read(categoriesProvider.notifier)
          .load(forceRefresh: true);
      expect(container.read(categoriesProvider), isA<UiEmpty<dynamic>>());
    });

    test('marcas y filtros por categoría cargan del servidor', () async {
      container = build()
        ..listen(brandsProvider, (_, _) {})
        ..listen(filterDimensionsProvider('minisplit'), (_, _) {});
      await settle(container);
      final brands = container.read(brandsProvider) as UiData<List<Brand>>;
      expect(brands.value, hasLength(2));
      final dims = container.read(
        filterDimensionsProvider('minisplit'),
      ) as UiData<List<FilterDimension>>;
      expect(dims.value, hasLength(3));
      expect(
        bff.to('/filters').single.queryParameters['category'],
        'minisplit',
      );
    });
  });
}
