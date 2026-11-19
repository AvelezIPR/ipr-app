import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/core/storage/cache_store.dart';
import 'package:ipr_mobile/features/product_detail/data/repositories/api_product_detail_repository.dart';
import 'package:ipr_mobile/features/product_detail/domain/entities/product_detail.dart';
import 'package:ipr_mobile/shared/domain/price_status.dart';
import 'package:ipr_mobile/shared/domain/stock_status.dart';

import '../../../mocks/fake_http_adapter.dart';
import '../../../mocks/test_clients.dart';
import 'product_detail_test_support.dart';

const _slug = 'compresor-scroll-24000-btu';

void main() {
  late FakeHttpAdapter adapter;
  late MemoryCacheStore cache;
  late DateTime clock;
  late ApiProductDetailRepository repository;

  setUp(() {
    adapter = FakeHttpAdapter();
    clock = DateTime(2026, 11, 19, 10);
    cache = MemoryCacheStore(now: () => clock);
    repository = ApiProductDetailRepository(
      client: buildTestClient(adapter: adapter).client,
      cache: cache,
    );
  });

  ProductDetail productOf(Result<ProductDetailLoad> result) =>
      (result as Ok<ProductDetailLoad>).value.product;

  void respondWith(
    Object body, {
    Map<String, List<String>> headers = const {},
  }) => adapter.enqueue((_) => FakeHttpAdapter.json(body, headers: headers));

  group('M1 · RF-026 · getProduct', () {
    test('200: pide /products/{slug}, mapea y guarda en caché', () async {
      respondWith(fixtureBody('ProductDetail.priced.json'));
      final result = await repository.load(_slug);

      expect(adapter.requests.single.path, '/products/$_slug');
      expect(adapter.requests.single.method, 'GET');
      final load = (result as Ok<ProductDetailLoad>).value;
      expect(load.stale, isFalse);
      expect(load.product.id, 4521);
      expect(load.product.name, 'Compresor scroll 24.000 BTU R410A');
      expect(load.product.summary.brandName, 'Copeland');
      expect(load.product.gallery, hasLength(3));
      expect(load.product.attributes.first.displayValue, '24.000 BTU');
      expect(load.product.attributes.last.displayValue, 'R410A, R32');
      expect(
        (load.product.price as Priced).amount.pesos,
        1234567,
        reason: 'AC-026-5: el precio es exactamente el del servidor',
      );
      expect(load.product.summary.strikeThroughPrice?.pesos, 1500000);
      expect(load.product.canAddToCart, isTrue);
      expect(
        await cache.read(
          ApiProductDetailRepository.cacheKey(_slug),
          CachePolicy.listing,
        ),
        isNotNull,
      );
    });

    test('un slug que el contrato rechazaría ni se pide: NotFound', () async {
      for (final slug in ['', 'Mayusculas', '../etc', 'a b', '-x', 'x' * 201]) {
        final result = await repository.load(slug);
        expect(result.failureOrNull, isA<NotFound>(), reason: slug);
      }
      expect(adapter.requests, isEmpty);
    });
  });

  group('TC-103 · TC-104 · RF-009 · 404 frente a caída', () {
    test('404 → NotFound (no reintentable)', () async {
      adapter.enqueue((_) => FakeHttpAdapter.problem(404, 'not_found'));
      final result = await repository.load(_slug);
      expect(result.failureOrNull, isA<NotFound>());
      expect(result.failureOrNull!.retryable, isFalse);
    });

    for (final status in [502, 503, 504]) {
      test('$status → ServiceUnavailable, nunca NotFound', () async {
        adapter.fallback = (_) => FakeHttpAdapter.problem(status, 'upstream');
        final result = await repository.load(_slug);
        expect(result.failureOrNull, isA<ServiceUnavailable>());
        expect(result.failureOrNull, isNot(isA<NotFound>()));
        expect(result.failureOrNull!.retryable, isTrue);
      });
    }

    test('sin red → NoConnection; tiempo agotado → RequestTimeout', () async {
      adapter.fallback = FakeHttpAdapter.connectionError;
      expect((await repository.load(_slug)).failureOrNull, isA<NoConnection>());
      adapter.fallback = FakeHttpAdapter.timeout;
      expect(
        (await repository.load(_slug)).failureOrNull,
        isA<RequestTimeout>(),
      );
    });

    test('JSON inesperado → ContractFailure sin volcar el cuerpo', () async {
      respondWith({'data': 'no es un objeto'});
      final failure = (await repository.load(_slug)).failureOrNull;
      expect(failure, isA<ContractFailure>());
      expect((failure! as ContractFailure).detail, 'GET /products/{slug}');
    });

    test(
      'un producto sin nombre es ContractFailure, no una ficha vacía',
      () async {
        final body = fixtureBody('ProductDetail.priced.json');
        (body['data'] as Map<String, dynamic>)['name'] = '   ';
        respondWith(body);
        expect(
          (await repository.load(_slug)).failureOrNull,
          isA<ContractFailure>(),
        );
      },
    );
  });

  group('RNF-022 · caché SWR 5 min / 24 h', () {
    test('vigente (< 5 min): se sirve sin pedir a la red', () async {
      respondWith(fixtureBody('ProductDetail.priced.json'));
      await repository.load(_slug);
      clock = clock.add(const Duration(minutes: 4));
      final result = await repository.load(_slug);
      expect(adapter.requests, hasLength(1));
      expect((result as Ok<ProductDetailLoad>).value.stale, isFalse);
      expect(productOf(result).name, contains('Compresor'));
    });

    test('forceRefresh ignora la caché vigente', () async {
      respondWith(fixtureBody('ProductDetail.priced.json'));
      respondWith(fixtureBody('ProductDetail.out-of-stock.json'));
      await repository.load(_slug);
      final result = await repository.load(_slug, forceRefresh: true);
      expect(adapter.requests, hasLength(2));
      expect(productOf(result).summary.availability, StockStatus.outOfStock);
    });

    test(
      'obsoleta (> 5 min) y red caída: se muestra la copia con aviso',
      () async {
        respondWith(fixtureBody('ProductDetail.priced.json'));
        await repository.load(_slug);
        clock = clock.add(const Duration(hours: 3));
        adapter.fallback = (_) => FakeHttpAdapter.problem(503, 'upstream');
        final result = await repository.load(_slug);
        final load = (result as Ok<ProductDetailLoad>).value;
        expect(load.stale, isTrue);
        expect(load.product.id, 4521);
      },
    );

    test(
      'obsoleta y sin red: la copia sigue ahí (un fallo no borra la caché)',
      () async {
        respondWith(fixtureBody('ProductDetail.priced.json'));
        await repository.load(_slug);
        clock = clock.add(const Duration(hours: 3));
        adapter.fallback = FakeHttpAdapter.connectionError;
        await repository.load(_slug);
        final again = await repository.load(_slug);
        expect((again as Ok<ProductDetailLoad>).value.stale, isTrue);
      },
    );

    test('obsoleta y el servidor responde: datos nuevos, sin aviso', () async {
      respondWith(fixtureBody('ProductDetail.priced.json'));
      await repository.load(_slug);
      clock = clock.add(const Duration(hours: 3));
      respondWith(fixtureBody('ProductDetail.out-of-stock.json'));
      final load =
          (await repository.load(_slug) as Ok<ProductDetailLoad>).value;
      expect(load.stale, isFalse);
      expect(load.product.summary.availability, StockStatus.outOfStock);
    });

    test('más de 24 h: la copia caducó; sin red, error', () async {
      respondWith(fixtureBody('ProductDetail.priced.json'));
      await repository.load(_slug);
      clock = clock.add(const Duration(hours: 25));
      adapter.fallback = FakeHttpAdapter.connectionError;
      expect((await repository.load(_slug)).failureOrNull, isA<NoConnection>());
    });

    test('sin copia y sin red: el fallo llega a la UI', () async {
      adapter.fallback = (_) => FakeHttpAdapter.problem(503, 'upstream');
      expect(
        (await repository.load(_slug)).failureOrNull,
        isA<ServiceUnavailable>(),
      );
    });

    test(
      '404 con copia: el producto ya no existe, se borra la copia',
      () async {
        respondWith(fixtureBody('ProductDetail.priced.json'));
        await repository.load(_slug);
        adapter.enqueue((_) => FakeHttpAdapter.problem(404, 'not_found'));
        final result = await repository.load(_slug, forceRefresh: true);
        expect(result.failureOrNull, isA<NotFound>());
        expect(
          await cache.read(
            ApiProductDetailRepository.cacheKey(_slug),
            CachePolicy.listing,
          ),
          isNull,
        );
      },
    );

    test(
      'X-IPR-Data-State: stale del servidor se propaga como aviso',
      () async {
        respondWith(
          fixtureBody('ProductDetail.priced.json'),
          headers: {
            'x-ipr-data-state': ['stale'],
          },
        );
        final load =
            (await repository.load(_slug) as Ok<ProductDetailLoad>).value;
        expect(load.stale, isTrue);
      },
    );

    test('copia corrupta: se descarta y se pide a la red', () async {
      await cache.write(ApiProductDetailRepository.cacheKey(_slug), '{no json');
      respondWith(fixtureBody('ProductDetail.priced.json'));
      final load =
          (await repository.load(_slug) as Ok<ProductDetailLoad>).value;
      expect(load.stale, isFalse);
      expect(adapter.requests, hasLength(1));
    });

    test(
      'la caché solo contiene la ficha pública (sin datos personales)',
      () async {
        respondWith(fixtureBody('ProductDetail.priced.json'));
        await repository.load(_slug);
        final raw = (await cache.read(
          ApiProductDetailRepository.cacheKey(_slug),
          CachePolicy.listing,
        ))!.value;
        final json = jsonDecode(raw) as Map<String, dynamic>;
        expect(json.keys, isNot(contains('email')));
        expect(json['slug'], _slug);
      },
    );
  });

  group('Mapeo tolerante (CR-017, ADR-002)', () {
    test(r'sin precio: OnRequest, nunca $0, no comprable', () async {
      respondWith(fixtureBody('ProductDetail.on-request.json'));
      final p = productOf(
        await repository.load('unidad-condensadora-especial'),
      );
      expect(p.price, isA<OnRequest>());
      expect(p.canAddToCart, isFalse);
      expect(p.summary.image, isNull);
      expect(p.gallery, isEmpty);
      expect(p.summary.brandSlug, isNull);
    });

    test('precio 0 con status priced se trata como sin precio', () async {
      respondWith(fixtureBody('ProductDetail.unknown-availability.json'));
      final p = productOf(
        await repository.load('producto-disponibilidad-nueva'),
      );
      expect(p.price, isA<OnRequest>());
      expect(p.summary.availability, StockStatus.unknown);
      expect(p.canAddToCart, isFalse);
    });

    test('bajo pedido: con precio pero NO comprable (CR-017)', () async {
      respondWith(fixtureBody('ProductDetail.backorder.json'));
      final p = productOf(await repository.load('valvula-bajo-pedido'));
      expect(p.price, isA<Priced>());
      expect(p.summary.availability, StockStatus.onBackorder);
      expect(p.canAddToCart, isFalse);
    });

    test(
      'purchasable=false del servidor gana aunque la regla local diga sí',
      () async {
        final body = fixtureBody('ProductDetail.priced.json');
        (body['data'] as Map<String, dynamic>)['purchasable'] = false;
        respondWith(body);
        expect(productOf(await repository.load(_slug)).canAddToCart, isFalse);
      },
    );

    test('campos ausentes o con tipo raro no rompen la ficha', () async {
      respondWith({
        'data': {
          'id': 9,
          'slug': 'minimo',
          'name': 'Mínimo',
          'price': 'raro',
          'availability': 42,
          'gallery': [
            null,
            3,
            {'url': ''},
            {'url': 'https://staging.invalid/a.jpg'},
          ],
          'attributes': [
            {'name': 'Sin opciones', 'slug': 'x', 'options': <String>[]},
            {
              'name': 'Con opciones',
              'slug': 'y',
              'options': ['a', 7, 'b'],
            },
            'basura',
          ],
          'categories': [
            {'id': 'x'},
          ],
          'campoFuturo': true,
        },
      });
      final p = productOf(await repository.load('minimo'));
      expect(p.sku, '');
      expect(p.price, isA<OnRequest>());
      expect(p.gallery.map((i) => i.url), ['https://staging.invalid/a.jpg']);
      expect(p.attributes.map((a) => a.displayValue), ['a, b']);
      expect(p.categories, isEmpty);
      expect(p.serverPurchasable, isTrue);
    });

    test('un precio regular mayor solo se tacha si es oferta real', () async {
      final body = fixtureBody('ProductDetail.priced.json');
      final price =
          (body['data'] as Map<String, dynamic>)['price']
              as Map<String, dynamic>;
      price['onSale'] = false;
      respondWith(body);
      expect(
        productOf(await repository.load(_slug)).summary.strikeThroughPrice,
        isNull,
      );
    });
  });

  group('Entidades', () {
    test('ProductDetail y ProductAttribute comparan por valor', () {
      final a = fixtureProduct('ProductDetail.priced.json');
      final b = fixtureProduct('ProductDetail.priced.json');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.attributes.first, b.attributes.first);
      expect(a.attributes.first.hashCode, b.attributes.first.hashCode);
      expect(a.categories.first, b.categories.first);
      expect(a.categories.first.hashCode, b.categories.first.hashCode);
      expect(a, isNot(fixtureProduct('ProductDetail.on-request.json')));
    });
  });
}
