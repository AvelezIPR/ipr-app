import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/storage/cache_store.dart';
import 'package:ipr_mobile/features/home/data/repositories/api_home_repository.dart';
import 'package:ipr_mobile/shared/domain/money.dart';
import 'package:ipr_mobile/shared/domain/price_status.dart';
import 'package:ipr_mobile/shared/domain/stock_status.dart';

import '../../../mocks/fake_http_adapter.dart';
import '../../../mocks/test_clients.dart';
import 'home_test_support.dart';

/// Caché que falla siempre (disco roto): el bloque no debe caerse.
final class _BrokenCache implements CacheStore {
  @override
  Future<CacheRead?> read(String key, CachePolicy policy) =>
      throw StateError('disco');
  @override
  Future<void> write(String key, String value) => throw StateError('disco');
  @override
  Future<void> remove(String key) => throw StateError('disco');
  @override
  Future<void> clear() => throw StateError('disco');
  @override
  int get length => 0;
}

void main() {
  late FakeHttpAdapter adapter;
  late MemoryCacheStore cache;
  late DateTime clock;
  late ApiHomeRepository repo;

  setUp(() {
    adapter = FakeHttpAdapter();
    clock = DateTime(2026, 11, 19, 10);
    cache = MemoryCacheStore(now: () => clock);
    repo = ApiHomeRepository(
      client: buildTestClient(adapter: adapter).client,
      cache: cache,
    );
  });

  Responder ok(Object? body, {bool stale = false}) =>
      (_) => FakeHttpAdapter.json(
        body,
        headers: {
          if (stale) 'x-ipr-data-state': ['stale'],
        },
      );

  group('M1 · RF-002 · categorías (listCategories)', () {
    test('pide GET /categories y deja solo las raíces válidas', () async {
      adapter.enqueue(
        ok(
          listBody([
            fixture('Category.valid.json'),
            fixture('Category.refrigeracion.json'),
            fixture('Category.missing-name.json'),
            // Un hijo suelto (parentId != null) no es raíz.
            {
              'id': 99,
              'slug': 'hijo',
              'name': 'Hijo',
              'parentId': 15,
              'children': <Object>[],
            },
            // WooCommerce usa 0 para "sin padre".
            {
              'id': 100,
              'slug': 'raiz-cero',
              'name': 'Raíz con padre 0',
              'parentId': 0,
              'children': <Object>[],
            },
          ]),
        ),
      );
      final result = await repo.categories();
      final data = result.valueOrNull!;
      expect(adapter.requests.single.path, '/categories');
      expect(adapter.requests.single.method, 'GET');
      expect(data.stale, isFalse);
      expect(data.value.map((c) => c.slug), [
        'aire-acondicionado',
        'refrigeracion',
        'raiz-cero',
      ]);
    });

    test(
      'un 200 con lista vacía es Ok vacío (no se guarda en caché)',
      () async {
        adapter.enqueue(ok(listBody([])));
        final result = await repo.categories();
        expect(result.valueOrNull!.value, isEmpty);
        expect(cache.length, 0);
      },
    );

    test('data que no es lista → ContractFailure', () async {
      adapter.enqueue(ok({'data': 'raro'}));
      final result = await repo.categories();
      expect(result.failureOrNull, isA<ContractFailure>());
    });

    test('X-IPR-Data-State: stale se refleja como obsoleto', () async {
      adapter.enqueue(
        ok(listBody([fixture('Category.valid.json')]), stale: true),
      );
      final result = await repo.categories();
      expect(result.valueOrNull!.stale, isTrue);
    });
  });

  group('M1 · RF-004 · marcas (listBrands)', () {
    test('solo marcas con página propia', () async {
      adapter.enqueue(
        ok(
          listBody([
            fixture('Brand.valid.json'),
            fixture('Brand.no-landing.json'),
            {'slug': 'sin-flag', 'name': 'Sin bandera'},
          ]),
        ),
      );
      final result = await repo.brands();
      expect(adapter.requests.single.path, '/brands');
      expect(result.valueOrNull!.value.map((b) => b.slug), ['elitech']);
      expect(result.valueOrNull!.value.single.name, 'Elitech');
    });
  });

  group('M1 · RF-003 · más vendidos (listProducts?sort=popularity)', () {
    test('envía sort=popularity y perPage=12; mapea precio y stock', () async {
      adapter.enqueue(
        ok(
          productPage([
            fixture('ProductSummary.priced.json'),
            fixture('ProductSummary.on-request.json'),
            fixture('ProductSummary.out-of-stock.json'),
            fixture('ProductSummary.unknown-availability.json'),
            {'id': 'x', 'slug': 'sin-id', 'name': 'Sin id numérico'},
          ]),
        ),
      );
      final result = await repo.featuredProducts();
      final request = adapter.requests.single;
      expect(request.path, '/products');
      expect(request.queryParameters['sort'], 'popularity');
      expect(request.queryParameters['perPage'], 12);
      expect(request.queryParameters['page'], 1);

      final items = result.valueOrNull!.value;
      expect(items, hasLength(4));
      expect(items[0].price, const Priced(Money(1445000)));
      expect(items[0].onSale, isTrue);
      expect(items[0].strikeThroughPrice, const Money(1600000));
      expect(items[0].brandName, 'Elitech');
      expect(items[0].canAddToCart, isTrue);
      // Sin precio → "Más información", nunca $0; no comprable.
      expect(items[1].price, isA<OnRequest>());
      expect(items[1].canAddToCart, isFalse);
      expect(items[1].image, isNull);
      expect(items[2].availability, StockStatus.outOfStock);
      expect(items[2].canAddToCart, isFalse);
      // Valor nuevo del servidor y precio 0: tolerado.
      expect(items[3].availability, StockStatus.unknown);
      expect(items[3].price, isA<OnRequest>());
    });
  });

  group('M1 · RNF-022 · caché SWR (taxonomía 1 h / 7 d)', () {
    test('dato vigente: no vuelve a la red', () async {
      adapter.enqueue(ok(listBody([fixture('Category.valid.json')])));
      await repo.categories();
      clock = clock.add(const Duration(minutes: 30));
      final second = await repo.categories();
      expect(adapter.requests, hasLength(1));
      expect(second.valueOrNull!.stale, isFalse);
      expect(second.valueOrNull!.value, hasLength(1));
    });

    test('forceRefresh ignora la caché vigente', () async {
      adapter
        ..enqueue(ok(listBody([fixture('Category.valid.json')])))
        ..enqueue(
          ok(
            listBody([
              fixture('Category.valid.json'),
              fixture('Category.refrigeracion.json'),
            ]),
          ),
        );
      await repo.categories();
      final refreshed = await repo.categories(forceRefresh: true);
      expect(adapter.requests, hasLength(2));
      expect(refreshed.valueOrNull!.value, hasLength(2));
    });

    test('dato caducado + red caída: devuelve lo guardado como obsoleto y '
        'no lo borra', () async {
      adapter.enqueue(ok(listBody([fixture('Category.valid.json')])));
      await repo.categories();
      clock = clock.add(const Duration(hours: 3));
      adapter.fallback = FakeHttpAdapter.connectionError;
      final first = await repo.categories();
      expect(first.valueOrNull!.stale, isTrue);
      expect(first.valueOrNull!.value.single.slug, 'aire-acondicionado');
      // Un fallo de red nunca borra la caché: el siguiente intento la ve igual.
      final second = await repo.categories();
      expect(second.valueOrNull!.stale, isTrue);
      expect(cache.length, 1);
    });

    test('dato caducado + red OK: refresca y deja de ser obsoleto', () async {
      adapter
        ..enqueue(ok(listBody([fixture('Category.valid.json')])))
        ..enqueue(ok(listBody([fixture('Category.refrigeracion.json')])));
      await repo.categories();
      clock = clock.add(const Duration(hours: 3));
      final result = await repo.categories();
      expect(result.valueOrNull!.stale, isFalse);
      expect(result.valueOrNull!.value.single.slug, 'refrigeracion');
    });

    test('listado: 5 min vigente, después se pide de nuevo', () async {
      adapter
        ..enqueue(ok(productPage([fixture('ProductSummary.priced.json')])))
        ..enqueue(ok(productPage([fixture('ProductSummary.on-request.json')])));
      await repo.featuredProducts();
      clock = clock.add(const Duration(minutes: 4));
      await repo.featuredProducts();
      expect(adapter.requests, hasLength(1));
      clock = clock.add(const Duration(minutes: 2));
      final third = await repo.featuredProducts();
      expect(adapter.requests, hasLength(2));
      expect(third.valueOrNull!.value.single.slug, 'compresor-sin-precio');
    });

    test('contrato roto con caché: muestra la caché obsoleta', () async {
      adapter
        ..enqueue(ok(listBody([fixture('Brand.valid.json')])))
        ..enqueue(ok({'data': 7}));
      await repo.brands();
      final result = await repo.brands(forceRefresh: true);
      expect(result.valueOrNull!.stale, isTrue);
      expect(result.valueOrNull!.value.single.slug, 'elitech');
    });

    test('426 nunca se disfraza con la caché', () async {
      adapter
        ..enqueue(ok(listBody([fixture('Brand.valid.json')])))
        ..enqueue(
          (_) => FakeHttpAdapter.problem(426, 'app_version_unsupported'),
        );
      await repo.brands();
      final result = await repo.brands(forceRefresh: true);
      expect(result.failureOrNull, isA<UpgradeRequired>());
    });

    test('caché ilegible: se descarta y se pide a la red', () async {
      await cache.write(ApiHomeRepository.brandsKey, 'no es json');
      adapter.enqueue(ok(listBody([fixture('Brand.valid.json')])));
      final result = await repo.brands();
      expect(result.valueOrNull!.value, hasLength(1));
      expect(adapter.requests, hasLength(1));
    });

    test('caché con forma inesperada se elimina y se pide a la red', () async {
      await cache.write(ApiHomeRepository.brandsKey, '{"a":1}');
      adapter.enqueue(ok(listBody([fixture('Brand.valid.json')])));
      await repo.brands();
      expect(adapter.requests, hasLength(1));
    });

    test('disco roto: la red sigue sirviendo el bloque', () async {
      adapter.enqueue(ok(listBody([fixture('Brand.valid.json')])));
      final broken = ApiHomeRepository(
        client: buildTestClient(adapter: adapter).client,
        cache: _BrokenCache(),
      );
      final result = await broken.brands();
      expect(result.valueOrNull!.value, hasLength(1));
    });
  });

  group('TC-104 · RF-009 · 404 ≠ 503 y sin caché el error llega', () {
    test('503 sin caché → ServiceUnavailable (no lista vacía)', () async {
      adapter.fallback = (_) =>
          FakeHttpAdapter.problem(503, 'upstream_unavailable');
      final result = await repo.featuredProducts();
      expect(result.failureOrNull, isA<ServiceUnavailable>());
    });

    test('404 → NotFound', () async {
      adapter.enqueue((_) => FakeHttpAdapter.problem(404, 'not_found'));
      final result = await repo.categories();
      expect(result.failureOrNull, isA<NotFound>());
    });

    test('sin red → NoConnection', () async {
      adapter.fallback = FakeHttpAdapter.connectionError;
      final result = await repo.brands();
      expect(result.failureOrNull, isA<NoConnection>());
    });
  });
}
