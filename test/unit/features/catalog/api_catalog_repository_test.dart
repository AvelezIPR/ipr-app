import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/storage/cache_store.dart';
import 'package:ipr_mobile/features/catalog/data/datasources/catalog_remote_datasource.dart';
import 'package:ipr_mobile/features/catalog/data/repositories/api_catalog_repository.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/product_filters.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/product_query.dart';

import '../../../fixtures/catalog/catalog_fixtures.dart';
import '../../../fixtures/catalog/fake_catalog_bff.dart';
import '../../../mocks/fake_http_adapter.dart';
import '../../../mocks/test_clients.dart';

/// Caché que falla al leer o escribir (disco dañado).
final class BrokenCacheStore implements CacheStore {
  @override
  Future<CacheRead?> read(String key, CachePolicy policy) =>
      throw StateError('lectura rota');
  @override
  Future<void> write(String key, String value) =>
      throw StateError('escritura rota');
  @override
  Future<void> remove(String key) async {}
  @override
  Future<void> clear() async {}
  @override
  int get length => 0;
}

void main() {
  late FakeCatalogBff bff;
  late DateTime now;
  late MemoryCacheStore cache;
  late ApiCatalogRepository repo;

  ApiCatalogRepository build(CacheStore store) => ApiCatalogRepository(
    remote: CatalogRemoteDataSource(
      buildTestClient(adapter: bff.adapter).client,
    ),
    cache: store,
  );

  setUp(() {
    bff = FakeCatalogBff();
    now = DateTime(2026, 11, 19, 10);
    cache = MemoryCacheStore(now: () => now);
    repo = build(cache);
  });

  group('M1 · RF-010 · categorías (caché de taxonomía 1 h / 7 d)', () {
    test(
      'carga el árbol y lo guarda; sin Authorization (AC-010-4, RF-037)',
      () async {
        final result = await repo.categories();
        final value = result.valueOrNull!;
        expect(value.stale, isFalse);
        expect(value.value.first.slug, 'aire-acondicionado');
        final request = bff.to('/categories').single;
        expect(request.headers.containsKey('Authorization'), isFalse);
        expect(cache.length, 1);
      },
    );

    test('dato vigente (< 1 h): no toca la red', () async {
      await repo.categories();
      now = now.add(const Duration(minutes: 59));
      final again = await repo.categories();
      expect(again.isOk, isTrue);
      expect(bff.to('/categories'), hasLength(1));
    });

    test('forceRefresh ignora el dato vigente', () async {
      await repo.categories();
      await repo.categories(forceRefresh: true);
      expect(bff.to('/categories'), hasLength(2));
    });

    test('caducado y la red falla → caché marcada stale (AC-010-6)', () async {
      await repo.categories();
      now = now.add(const Duration(hours: 2));
      bff.on('/categories', FakeHttpAdapter.connectionError);
      final result = await repo.categories();
      final value = result.valueOrNull!;
      expect(value.stale, isTrue);
      expect(value.value, isNotEmpty);
    });

    test('un fallo de red no borra la caché', () async {
      await repo.categories();
      now = now.add(const Duration(hours: 2));
      bff.on('/categories', FakeHttpAdapter.connectionError);
      await repo.categories();
      expect(cache.length, 1);
      // Y se recupera al volver la red.
      bff.on('/categories', (_) => FakeHttpAdapter.json(categoriesBody()));
      expect((await repo.categories()).valueOrNull!.stale, isFalse);
    });

    test('sin caché y con fallo → Err (no se finge una lista vacía)', () async {
      bff.on(
        '/categories',
        (_) => FakeHttpAdapter.problem(503, 'service_unavailable'),
      );
      final result = await repo.categories();
      expect(result.failureOrNull, isA<ServiceUnavailable>());
    });

    test('expira a los 7 días: ya no sirve de respaldo', () async {
      await repo.categories();
      now = now.add(const Duration(days: 8));
      bff.on('/categories', FakeHttpAdapter.connectionError);
      expect((await repo.categories()).failureOrNull, isA<NoConnection>());
    });

    test(
      'cuerpo irreconocible → ContractFailure (sin volcar el cuerpo)',
      () async {
        bff.on('/categories', (_) => FakeHttpAdapter.json({'oops': true}));
        final failure = (await repo.categories()).failureOrNull;
        expect(failure, isA<ContractFailure>());
        expect((failure! as ContractFailure).detail, 'GET /categories');
      },
    );

    test('cuerpo ilegible pero con caché → caché stale', () async {
      await repo.categories();
      bff.on('/categories', (_) => FakeHttpAdapter.json({'oops': true}));
      final result = await repo.categories(forceRefresh: true);
      expect(result.valueOrNull!.stale, isTrue);
    });

    test(
      'el servidor sirve datos obsoletos (X-IPR-Data-State: stale)',
      () async {
        bff.on(
          '/categories',
          (_) => FakeHttpAdapter.json(
            categoriesBody(),
            headers: {
              'x-ipr-data-state': ['stale'],
            },
          ),
        );
        final value = (await repo.categories()).valueOrNull!;
        expect(value.stale, isTrue);
        // No se guarda: la siguiente apertura vuelve a pedirlo.
        expect(cache.length, 0);
        await repo.categories();
        expect(bff.to('/categories'), hasLength(2));
      },
    );

    test(
      'un 304 sin caché es un fallo de contrato; con caché la conserva',
      () async {
        bff.on('/categories', (_) => FakeHttpAdapter.json(null, status: 304));
        expect((await repo.categories()).failureOrNull, isA<ContractFailure>());
        bff.on('/categories', (_) => FakeHttpAdapter.json(categoriesBody()));
        await repo.categories();
        bff.on('/categories', (_) => FakeHttpAdapter.json(null, status: 304));
        final again = await repo.categories(forceRefresh: true);
        expect(again.valueOrNull!.stale, isFalse);
      },
    );

    test('una caché dañada no rompe la carga', () async {
      final result = await build(BrokenCacheStore()).categories();
      expect(result.isOk, isTrue);
    });

    test('una caché guardada ilegible se ignora', () async {
      await cache.write(ApiCatalogRepository.categoriesKey, 'no es json');
      final result = await repo.categories();
      expect(result.isOk, isTrue);
      expect(bff.to('/categories'), hasLength(1));
    });
  });

  group('M1 · RF-009 · 404 ≠ 503 (TC-104)', () {
    test('404 de un listado es NotFound y nunca usa la caché', () async {
      const query = ProductQuery(scope: ListScope.category('minisplit'));
      bff.on(
        '/products',
        (_) => FakeHttpAdapter.json(productPage(products(2))),
      );
      await repo.products(query);
      now = now.add(const Duration(hours: 1));
      bff.on('/products', (_) => FakeHttpAdapter.problem(404, 'not_found'));
      final result = await repo.products(query);
      expect(result.failureOrNull, isA<NotFound>());
    });

    test(
      '503 del mismo listado es ServiceUnavailable (reintentable)',
      () async {
        bff.on(
          '/products',
          (_) => FakeHttpAdapter.problem(503, 'service_unavailable'),
        );
        final failure = (await repo.products(
          const ProductQuery(scope: ListScope.category('minisplit')),
        )).failureOrNull;
        expect(failure, isA<ServiceUnavailable>());
        expect(failure!.retryable, isTrue);
        expect(const NotFound().retryable, isFalse);
      },
    );

    test('404 de marca en /products y de filtros', () async {
      bff
        ..on('/products', (_) => FakeHttpAdapter.problem(404, 'not_found'))
        ..on('/filters', (_) => FakeHttpAdapter.problem(404, 'not_found'));
      expect(
        (await repo.products(
          const ProductQuery(scope: ListScope.brand('no-existe')),
        )).failureOrNull,
        isA<NotFound>(),
      );
      expect(
        (await repo.filters(categorySlug: 'x')).failureOrNull,
        isA<NotFound>(),
      );
    });
  });

  group('M1 · RF-011 · listados (5 min / 24 h, solo página 1)', () {
    test(
      'la página 1 se guarda y se reutiliza mientras esté vigente',
      () async {
        bff.on(
          '/products',
          (_) => FakeHttpAdapter.json(productPage(products(3))),
        );
        const query = ProductQuery(scope: ListScope.category('minisplit'));
        await repo.products(query);
        now = now.add(const Duration(minutes: 4));
        final again = await repo.products(query);
        expect(again.valueOrNull!.value.items, hasLength(3));
        expect(bff.to('/products'), hasLength(1));
      },
    );

    test('caducada y la red falla → página 1 guardada, stale', () async {
      bff.on(
        '/products',
        (_) => FakeHttpAdapter.json(productPage(products(3))),
      );
      const query = ProductQuery(scope: ListScope.category('minisplit'));
      await repo.products(query);
      now = now.add(const Duration(minutes: 6));
      bff.on('/products', FakeHttpAdapter.timeout);
      final value = (await repo.products(query)).valueOrNull!;
      expect(value.stale, isTrue);
      expect(value.value.items, hasLength(3));
    });

    test('las páginas siguientes nunca se guardan', () async {
      bff.on(
        '/products',
        (_) => FakeHttpAdapter.json(productPage(products(3), page: 2)),
      );
      const query = ProductQuery(
        scope: ListScope.category('minisplit'),
        page: 2,
      );
      await repo.products(query);
      await repo.products(query);
      expect(bff.to('/products'), hasLength(2));
      expect(cache.length, 0);
    });

    test('filtros distintos usan claves distintas', () async {
      bff.on(
        '/products',
        (_) => FakeHttpAdapter.json(productPage(products(1))),
      );
      const base = ProductQuery(scope: ListScope.category('minisplit'));
      await repo.products(base);
      await repo.products(
        ProductQuery(
          scope: const ListScope.category('minisplit'),
          filters: ProductFilters.empty
              .withSearch(null)
              .copyWith(
                category: const CategoryChoice(slug: 'cassette', name: 'C'),
              ),
        ),
      );
      expect(cache.length, 2);
    });

    test(
      'la búsqueda interna no se guarda en caché ni va en una clave',
      () async {
        bff.on(
          '/search',
          (_) => FakeHttpAdapter.json(productPage(products(2))),
        );
        final query = ProductQuery(
          scope: const ListScope.brand('elitech'),
          filters: ProductFilters.empty.withSearch('manómetro secreto'),
        );
        await repo.products(query);
        await repo.products(query);
        expect(cache.length, 0);
        expect(bff.to('/search'), hasLength(2));
        expect(bff.to('/search').first.queryParameters['brand'], 'elitech');
      },
    );

    test('liquidaciones pide /liquidaciones', () async {
      bff.on(
        '/liquidaciones',
        (_) => FakeHttpAdapter.json(
          productPage([product(1, base: 'ProductSummary.on-sale.json')]),
        ),
      );
      final value = (await repo.products(
        const ProductQuery(scope: ListScope.sale()),
      )).valueOrNull!;
      expect(value.value.items.single.onSale, isTrue);
      expect(bff.to('/liquidaciones'), hasLength(1));
    });

    test('cancelar antes de enviar no llega a la red', () async {
      bff.on(
        '/products',
        (_) => FakeHttpAdapter.json(productPage(products(1))),
      );
      final cancel = RequestCancellation()..cancel();
      final result = await repo.products(
        const ProductQuery(scope: ListScope.all()),
        cancel: cancel,
      );
      expect(result.isErr, isTrue);
      expect(bff.to('/products'), isEmpty);
    });

    test(
      'cancelar con la petición en vuelo la aborta (Err, sin caché)',
      () async {
        final gate = Completer<void>();
        bff.on('/products', (_) async {
          await gate.future;
          return FakeHttpAdapter.json(productPage(products(1)));
        });
        final cancel = RequestCancellation();
        final pending = repo.products(
          const ProductQuery(scope: ListScope.all()),
          cancel: cancel,
        );
        await Future<void>.delayed(Duration.zero);
        cancel.cancel();
        gate.complete();
        final result = await pending;
        expect(result.isErr, isTrue);
        expect(cache.length, 0);
      },
    );
  });

  group('M1 · RF-014/016 · filtros y marcas', () {
    test(
      'filtros por categoría y sin categoría usan claves distintas',
      () async {
        await repo.filters(categorySlug: 'minisplit');
        await repo.filters();
        expect(bff.to('/filters'), hasLength(2));
        expect(
          bff.to('/filters').first.queryParameters['category'],
          'minisplit',
        );
        expect(
          bff.to('/filters').last.queryParameters.containsKey('category'),
          isFalse,
        );
        expect(cache.length, 2);
      },
    );

    test('marcas: carga y reutiliza la caché', () async {
      final first = (await repo.brands()).valueOrNull!;
      expect(first.value, hasLength(2));
      await repo.brands();
      expect(bff.to('/brands'), hasLength(1));
    });
  });
}
