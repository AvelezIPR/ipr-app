import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/search/data/datasources/search_remote_datasource.dart';
import 'package:ipr_mobile/features/search/data/mappers/search_mapper.dart';
import 'package:ipr_mobile/features/search/data/repositories/api_search_repository.dart';
import 'package:ipr_mobile/features/search/domain/entities/search_suggestion.dart';
import 'package:ipr_mobile/features/search/search_providers.dart';
import 'package:ipr_mobile/shared/domain/image_ref.dart';
import 'package:ipr_mobile/shared/domain/money.dart';
import 'package:ipr_mobile/shared/domain/price_status.dart';
import 'package:ipr_mobile/shared/domain/quantity_range.dart';
import 'package:ipr_mobile/shared/domain/stock_status.dart';

import '../../../mocks/fake_http_adapter.dart';
import '../../../mocks/test_clients.dart';
import '../../../mocks/test_providers.dart';
import 'support/search_fakes.dart';

ApiSearchRepository repoWith(FakeHttpAdapter adapter) => ApiSearchRepository(
  SearchRemoteDataSource(buildTestClient(adapter: adapter).client),
);

/// Espera a que la petición llegue al adaptador (los interceptores son async).
Future<void> untilSent(FakeHttpAdapter adapter) async {
  for (var i = 0; i < 100 && adapter.requests.isEmpty; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  group('M1 · RF-020 · mapeo tolerante de /search', () {
    test('mapea los fixtures del contrato (precio, marca, stock, imagen)', () {
      final page = mapSearchPage(
        searchEnvelope(
          [
            fixture('ProductSummary.priced.json'),
            fixture('ProductSummary.on-request.json'),
          ],
          hasMore: true,
          total: 30,
        ),
        page: 1,
      );
      expect(page.items, hasLength(2));
      expect(page.hasMore, isTrue);
      expect(page.total, 30);
      final priced = page.items.first;
      expect(priced.slug, 'valvula-solenoide-1-4-qa-0001');
      expect(priced.brandName, 'Elitech');
      expect(priced.brandSlug, 'elitech');
      expect(priced.price, const Priced(Money(185000)));
      expect(priced.regularPrice, const Money(210000));
      expect(priced.onSale, isTrue);
      expect(priced.availability, StockStatus.inStock);
      expect(priced.image?.url, contains('qa-0001.jpg'));
      expect(priced.categorySlugs, ['refrigeracion', 'valvulas']);
      final onRequest = page.items.last;
      expect(onRequest.price, const OnRequest()); // nunca "$0"
      expect(onRequest.brandName, isNull);
      expect(onRequest.availability, StockStatus.outOfStock);
      expect(onRequest.image, isNull);
    });

    test('precio 0 aunque diga priced → OnRequest; enum nuevo → unknown', () {
      final item = fixture('ProductSummary.priced.json');
      final price = {...(item['price']! as Map<String, Object?>), 'amount': 0};
      final page = mapSearchPage(
        searchEnvelope([
          {...item, 'price': price, 'availability': 'preorder', 'extra': 1},
        ]),
        page: 1,
      );
      expect(page.items.single.price, const OnRequest());
      expect(page.items.single.onSale, isFalse);
      expect(page.items.single.regularPrice, isNull);
      expect(page.items.single.availability, StockStatus.unknown);
    });

    test('omite elementos ilegibles y conserva el resto', () {
      final page = mapSearchPage(
        searchEnvelope([
          fixture('ProductSummary.no-slug.json'),
          fixture('ProductSummary.priced.json'),
          {'id': 'x'},
        ]),
        page: 1,
      );
      expect(page.items.map((p) => p.id), [501]);
    });

    test('lista no vacía donde nada es legible → fallo de contrato', () {
      expect(
        () => mapSearchPage(
          searchEnvelope([fixture('ProductSummary.no-slug.json')]),
          page: 1,
        ),
        throwsFormatException,
      );
    });

    test('lista vacía es una página vacía (200 sin coincidencias)', () {
      final page = mapSearchPage(searchEnvelope([]), page: 1);
      expect(page.items, isEmpty);
      expect(page.hasMore, isFalse);
    });

    test('sin data, o data que no es lista → FormatException', () {
      expect(
        () => mapSearchPage(<String, Object?>{}, page: 1),
        throwsFormatException,
      );
      expect(() => mapSearchPage('html', page: 1), throwsFormatException);
      expect(
        () => mapSearchPage({'data': 'x'}, page: 1),
        throwsFormatException,
      );
    });

    test('sin meta válido: hasMore=false; la página 50 nunca tiene más', () {
      final noMeta = mapSearchPage({
        'data': [fixture('ProductSummary.priced.json')],
      }, page: 1);
      expect(noMeta.hasMore, isFalse);
      expect(noMeta.total, 1);
      final last = mapSearchPage(
        searchEnvelope(
          [fixture('ProductSummary.priced.json')],
          page: 50,
          hasMore: true,
        ),
        page: 50,
      );
      expect(last.hasMore, isFalse);
    });

    test('mapea sugerencias (máx. 6) y descarta las ilegibles', () {
      final item = fixture('Suggestion.valid.json');
      final json = {
        'data': {
          'query': 'val',
          'total': 40,
          'items': [
            for (var i = 0; i < 8; i++) {...item, 'id': i + 1},
            {'id': 99},
          ],
        },
      };
      final result = mapSearchSuggestions(json);
      expect(result.items, hasLength(6));
      expect(result.total, 40);
      expect(result.items.first.brandName, 'Elitech');
      expect(result.items.first.slug, 'valvula-solenoide-1-4-qa-0001');
    });

    test('sugerencias sin items → FormatException', () {
      expect(
        () => mapSearchSuggestions({'data': <String, Object?>{}}),
        throwsFormatException,
      );
    });

    test(
      'mapea hasVariants, priceFrom y quantityRange en productos de búsqueda',
      () {
        final base = fixture('ProductSummary.priced.json');
        final page = mapSearchPage(
          searchEnvelope([
            <String, dynamic>{
              ...base,
              'id': 601,
              'hasVariants': true,
              'priceFrom': 140000,
              'minQuantity': 2,
              'maxQuantity': 12,
            },
            <String, dynamic>{
              ...base,
              'id': 602,
              'hasVariants': true,
              'priceFrom': 0,
              'minQuantity': 10,
              'maxQuantity': 5,
            },
            <String, dynamic>{
              ...base,
              'id': 603,
              'hasVariants': false,
              'priceFrom': 95000,
              'minQuantity': 'invalido',
              'maxQuantity': 0,
            },
          ]),
          page: 1,
        );
        expect(page.items, hasLength(3));
        final variable = page.items[0];
        expect(variable.hasVariants, isTrue);
        expect(variable.priceFrom, const Money(140000));
        expect(variable.quantityRange, const QuantityRange(min: 2, max: 12));

        final zeroAndIncoherent = page.items[1];
        expect(zeroAndIncoherent.hasVariants, isTrue);
        expect(zeroAndIncoherent.priceFrom, isNull);
        expect(zeroAndIncoherent.quantityRange, QuantityRange.standard);

        final simpleWithInvalidLimits = page.items[2];
        expect(simpleWithInvalidLimits.hasVariants, isFalse);
        expect(simpleWithInvalidLimits.priceFrom, isNull);
        expect(simpleWithInvalidLimits.quantityRange, QuantityRange.standard);
      },
    );

    test('mapea image, price y availability en sugerencias (y casos ausentes/inválidos)', () {
      final base = fixture('Suggestion.valid.json');
      final result = mapSearchSuggestions(<String, dynamic>{
        'data': <String, dynamic>{
          'query': 'val',
          'total': 3,
          'items': [
            <String, dynamic>{
              ...base,
              'id': 1,
              'image': <String, dynamic>{
                'url': 'https://staging.invalid/img/s-1.jpg',
                'alt': 'Válvula',
                'width': 200,
                'height': 200,
              },
              'price': <String, dynamic>{'status': 'priced', 'amount': 185000},
              'availability': 'in_stock',
            },
            <String, dynamic>{
              ...base,
              'id': 2,
              'image': 'no-es-mapa',
              'price': <String, dynamic>{'status': 'priced', 'amount': 0},
              'availability': 'preorder',
            },
            <String, dynamic>{
              ...base,
              'id': 3,
              'image': null,
              'price': 'invalido',
              'availability': 123,
            },
          ],
        },
      });
      expect(result.items, hasLength(3));

      final enriched = result.items[0];
      expect(
        enriched.image,
        const ImageRef(
          url: 'https://staging.invalid/img/s-1.jpg',
          alt: 'Válvula',
          width: 200,
          height: 200,
        ),
      );
      expect(enriched.price, const Priced(Money(185000)));
      expect(enriched.availability, StockStatus.inStock);

      final zeroAndUnknown = result.items[1];
      expect(zeroAndUnknown.image, isNull);
      expect(zeroAndUnknown.price, const OnRequest());
      expect(zeroAndUnknown.availability, StockStatus.unknown);

      final absent = result.items[2];
      expect(absent.image, isNull);
      expect(absent.price, isNull);
      expect(absent.availability, isNull);
    });
  });

  group('M1 · RF-020/021 · ApiSearchRepository (FakeHttpAdapter)', () {
    test(
      'AC-020-4/7 · GET /search codifica el término y no exige sesión',
      () async {
        final adapter = FakeHttpAdapter([
          (o) => FakeHttpAdapter.json(searchEnvelope([])),
        ]);
        const term = '\' " < > % & # válvula';
        final result = await repoWith(adapter).search(term, page: 2);
        expect(result, isA<Ok<dynamic>>());
        final req = adapter.requests.single;
        expect(req.path, '/search');
        expect(req.queryParameters, {'q': term, 'page': 2, 'perPage': 24});
        // La URL final codifica los signos y se decodifica al término exacto.
        expect(req.uri.queryParameters['q'], term);
        expect(req.uri.toString(), isNot(contains('<')));
        expect(req.headers.containsKey('Authorization'), isFalse);
      },
    );

    test('RF-023 · 200 con lista vacía → Ok con página vacía', () async {
      final adapter = FakeHttpAdapter([
        (o) => FakeHttpAdapter.json(searchEnvelope([])),
      ]);
      final result = await repoWith(adapter).search('qa-sin-resultados');
      expect(result.valueOrNull!.items, isEmpty);
    });

    test(
      'AC-023-5 · sin red y timeout son fallos, nunca página vacía',
      () async {
        final noNet = FakeHttpAdapter()
          ..fallback = FakeHttpAdapter.connectionError;
        final slow = FakeHttpAdapter()..fallback = FakeHttpAdapter.timeout;
        expect(
          (await repoWith(noNet).search('a')).failureOrNull,
          isA<NoConnection>(),
        );
        expect(
          (await repoWith(slow).search('a')).failureOrNull,
          isA<RequestTimeout>(),
        );
      },
    );

    test('503 ≠ 404 (RF-009, TC-104)', () async {
      final a503 = FakeHttpAdapter()
        ..fallback = (o) =>
            FakeHttpAdapter.problem(503, 'catalog_index_warming');
      final a404 = FakeHttpAdapter()
        ..fallback = (o) => FakeHttpAdapter.problem(404, 'not_found');
      expect(
        (await repoWith(a503).search('x')).failureOrNull,
        isA<ServiceUnavailable>(),
      );
      expect((await repoWith(a404).search('x')).failureOrNull, isA<NotFound>());
    });

    test('JSON ilegible → ContractFailure', () async {
      final adapter = FakeHttpAdapter([
        (o) => FakeHttpAdapter.json({'otra': 'cosa'}),
      ]);
      expect(
        (await repoWith(adapter).search('x')).failureOrNull,
        isA<ContractFailure>(),
      );
    });

    test('la página se acota a 1..50', () async {
      final adapter = FakeHttpAdapter()
        ..fallback = (o) => FakeHttpAdapter.json(searchEnvelope([]));
      final repo = repoWith(adapter);
      await repo.search('x', page: 0);
      await repo.search('x', page: 99);
      expect(adapter.requests.map((r) => r.queryParameters['page']), [1, 50]);
    });

    test('GET /search/suggestions envía solo q', () async {
      final adapter = FakeHttpAdapter([
        (o) => FakeHttpAdapter.json({
          'data': {
            'query': 'val',
            'total': 1,
            'items': [fixture('Suggestion.valid.json')],
          },
        }),
      ]);
      final result = await repoWith(adapter)
          .suggestions('val', cancellation: RequestCancellation());
      expect(adapter.requests.single.path, '/search/suggestions');
      expect(adapter.requests.single.queryParameters, {'q': 'val'});
      expect(result.valueOrNull!.items.single.sku, 'QA-0001');
    });

    test(
      'cancelar la RequestCancellation aborta la petición de búsqueda',
      () async {
        final gate = Completer<void>();
        final adapter = FakeHttpAdapter([
          (o) async {
            await gate.future;
            return FakeHttpAdapter.json(searchEnvelope([]));
          },
        ]);
        final cancellation = RequestCancellation();
        final future = repoWith(adapter)
            .search('valvula', cancellation: cancellation);
        await untilSent(adapter);
        expect(adapter.requests, hasLength(1));
        expect(adapter.requests.single.cancelToken?.isCancelled, isFalse);

        cancellation.cancel();
        expect(adapter.requests.single.cancelToken?.isCancelled, isTrue);
        final result = await future.timeout(const Duration(seconds: 2));
        expect(result.isErr, isTrue); // nunca una página vacía
        gate.complete();
      },
    );

    test('cancelar aborta también la petición de sugerencias', () async {
      final gate = Completer<void>();
      final adapter = FakeHttpAdapter([
        (o) async {
          await gate.future;
          return FakeHttpAdapter.json({
            'data': {'items': <Object?>[]},
          });
        },
      ]);
      final cancellation = RequestCancellation();
      final future = repoWith(adapter)
          .suggestions('val', cancellation: cancellation);
      await untilSent(adapter);
      cancellation.cancel();
      expect(adapter.requests.single.cancelToken?.isCancelled, isTrue);
      expect((await future.timeout(const Duration(seconds: 2))).isErr, isTrue);
      gate.complete();
    });

    test('suggestions: fallo de red → Err', () async {
      final adapter = FakeHttpAdapter()
        ..fallback = FakeHttpAdapter.connectionError;
      expect(
        (await repoWith(adapter).suggestions('val')).failureOrNull,
        isA<NoConnection>(),
      );
    });
  });

  group('M1 · RF-020 · cableado', () {
    test(
      'searchRepositoryProvider construye el repositorio sobre apiClient',
      () {
        final container = ProviderContainer(overrides: testOverrides());
        addTearDown(container.dispose);
        expect(
          container.read(searchRepositoryProvider),
          isA<ApiSearchRepository>(),
        );
      },
    );

    test('SearchSuggestion se compara por id y slug', () {
      const a = SearchSuggestion(id: 1, slug: 'a', name: 'A', sku: 'S1');
      const b = SearchSuggestion(id: 1, slug: 'a', name: 'Otro', sku: 'S2');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(
        a,
        isNot(const SearchSuggestion(id: 2, slug: 'a', name: 'A', sku: 'S1')),
      );
      expect(SearchSuggestions.empty.items, isEmpty);
    });
  });
}
