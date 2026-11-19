import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/api_request.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/core/network/uuid_v4.dart';

import '../../../mocks/fake_http_adapter.dart';
import '../../../mocks/test_clients.dart';

void main() {
  group('Cabeceras (interceptor 1)', () {
    test(
      'M0 · SC-031/RNF-099 · envía versión, plataforma, device id y es-CO',
      () async {
        final adapter = FakeHttpAdapter([
          (_) => FakeHttpAdapter.json({'data': 1}),
        ]);
        final built = buildTestClient(adapter: adapter);
        await built.client.send(const ApiRequest.get('/config'));
        final headers = adapter.requests.single.headers;
        expect(headers['X-App-Version'], '1.2.3');
        expect(headers['X-App-Platform'], 'android');
        expect(headers['X-Device-Id'], testDeviceId);
        expect(headers['X-Request-Id'], isNotEmpty);
        expect(headers['Accept-Language'], 'es-CO');
        expect(headers.containsKey('Authorization'), isFalse);
      },
    );

    test('RNF-041 · ningún token ni dato personal en la URL', () async {
      final adapter = FakeHttpAdapter([(_) => FakeHttpAdapter.json({})]);
      final built = buildTestClient(adapter: adapter);
      await built.client.send(
        const ApiRequest.get('/products', query: {'page': 1}),
      );
      final uri = adapter.requests.single.uri.toString();
      expect(uri, isNot(contains('token')));
      expect(uri, startsWith('https://staging.invalid/mobile/v1/products'));
    });
  });

  group('TC-104 · RNF-022 · 404 frente a 503 (nunca un 200 vacío)', () {
    test('404 llega como NotFound', () async {
      final adapter = FakeHttpAdapter([
        (_) => FakeHttpAdapter.problem(404, 'not_found'),
      ]);
      final result = await buildTestClient(adapter: adapter).client
          .send(const ApiRequest.get('/products/x'));
      expect(result.failureOrNull, isA<NotFound>());
    });

    test('503 agota los reintentos y llega como ServiceUnavailable', () async {
      final adapter = FakeHttpAdapter()
        ..fallback = (_) =>
            FakeHttpAdapter.problem(503, 'upstream_unavailable');
      final built = buildTestClient(adapter: adapter);
      final result = await built.client.send(const ApiRequest.get('/products'));
      expect(result.failureOrNull, isA<ServiceUnavailable>());
      expect(
        adapter.requests,
        hasLength(3),
        reason: '1 intento + 2 reintentos',
      );
      expect(built.sleeps, hasLength(2));
    });

    test('403 de Cloudflare (HTML) llega como BlockedByEdge', () async {
      final adapter = FakeHttpAdapter([(_) => FakeHttpAdapter.html(403)]);
      final result = await buildTestClient(adapter: adapter).client
          .send(const ApiRequest.get('/products'));
      expect(result.failureOrNull, isA<BlockedByEdge>());
    });
  });

  group('Reintentos (interceptor 3)', () {
    test('GET se reintenta ante 503 y se recupera', () async {
      final adapter = FakeHttpAdapter([
        (_) => FakeHttpAdapter.problem(503, 'upstream_unavailable'),
        (_) => FakeHttpAdapter.json({'data': 'ok'}),
      ]);
      final built = buildTestClient(adapter: adapter);
      final result = await built.client.send(const ApiRequest.get('/products'));
      expect(result.isOk, isTrue);
      expect(adapter.requests, hasLength(2));
    });

    test('GET se reintenta ante error de red y ante tiempo agotado', () async {
      final adapter = FakeHttpAdapter([
        FakeHttpAdapter.connectionError,
        FakeHttpAdapter.timeout,
        (_) => FakeHttpAdapter.json({'data': 'ok'}),
      ]);
      final result = await buildTestClient(adapter: adapter).client
          .send(const ApiRequest.get('/products'));
      expect(result.isOk, isTrue);
      expect(adapter.requests, hasLength(3));
    });

    test('M0 · RNF-021/RNF-024 · POST NUNCA se reintenta', () async {
      final adapter = FakeHttpAdapter()
        ..fallback = (_) =>
            FakeHttpAdapter.problem(503, 'upstream_unavailable');
      final built = buildTestClient(adapter: adapter);
      final result = await built.client.send(
        const ApiRequest.post(
          '/pqrs',
          body: {},
          requiresIdempotency: true,
          idempotencyKey: 'k',
        ),
      );
      expect(result.failureOrNull, isA<ServiceUnavailable>());
      expect(adapter.requests, hasLength(1));
    });

    test('POST con error de red tampoco se reintenta', () async {
      final adapter = FakeHttpAdapter([FakeHttpAdapter.connectionError]);
      final built = buildTestClient(adapter: adapter);
      final result = await built.client.send(
        const ApiRequest.post('/auth/login', body: {}),
      );
      expect(result.failureOrNull, isA<NoConnection>());
      expect(adapter.requests, hasLength(1));
    });

    test('respeta Retry-After si es ≤ 10 s', () async {
      final adapter = FakeHttpAdapter([
        (_) => FakeHttpAdapter.problem(
          429,
          'rate_limited',
          headers: {
            'retry-after': ['4'],
          },
        ),
        (_) => FakeHttpAdapter.json({}),
      ]);
      final built = buildTestClient(adapter: adapter);
      final result = await built.client.send(const ApiRequest.get('/search'));
      expect(result.isOk, isTrue);
      expect(built.sleeps.single, const Duration(seconds: 4));
    });

    test(
      'Retry-After > 10 s no se reintenta y llega el valor al llamador',
      () async {
        final adapter = FakeHttpAdapter([
          (_) => FakeHttpAdapter.problem(
            429,
            'rate_limited',
            headers: {
              'retry-after': ['60'],
            },
          ),
        ]);
        final built = buildTestClient(adapter: adapter);
        final result = await built.client.send(const ApiRequest.get('/search'));
        final failure = result.failureOrNull;
        expect(failure, isA<RateLimited>());
        expect(failure!.retryAfterSeconds, 60);
        expect(adapter.requests, hasLength(1));
        expect(built.sleeps, isEmpty);
      },
    );

    test('el retroceso crece y lleva jitter', () async {
      final adapter = FakeHttpAdapter()
        ..fallback = (_) =>
            FakeHttpAdapter.problem(503, 'upstream_unavailable');
      final built = buildTestClient(adapter: adapter);
      await built.client.send(const ApiRequest.get('/products'));
      expect(built.sleeps[0].inMilliseconds, inInclusiveRange(400, 600));
      expect(built.sleeps[1].inMilliseconds, inInclusiveRange(1200, 1400));
    });

    test('no reintenta un 404 ni un 400', () async {
      final adapter = FakeHttpAdapter([
        (_) => FakeHttpAdapter.problem(400, 'validation_failed'),
      ]);
      final result = await buildTestClient(adapter: adapter).client
          .send(const ApiRequest.get('/products'));
      expect(result.failureOrNull, isA<Validation>());
      expect(adapter.requests, hasLength(1));
    });
  });

  group('Idempotencia, 304 y decodificación', () {
    test(
      'CR-005 · una petición que exige Idempotency-Key sin clave lanza',
      () async {
        final built = buildTestClient(adapter: FakeHttpAdapter());
        expect(
          () => built.client.send(
            const ApiRequest.post(
              '/checkout',
              body: {},
              requiresIdempotency: true,
            ),
          ),
          throwsArgumentError,
        );
      },
    );

    test('CR-005 · la clave viaja en la cabecera Idempotency-Key', () async {
      final adapter = FakeHttpAdapter([
        (_) => FakeHttpAdapter.json({'data': <String, Object?>{}}, status: 201),
      ]);
      final built = buildTestClient(adapter: adapter);
      final key = uuidV4();
      await built.client.send(
        ApiRequest.post(
          '/checkout',
          body: const {},
          requiresIdempotency: true,
          idempotencyKey: key,
        ),
      );
      expect(adapter.requests.single.headers['Idempotency-Key'], key);
    });

    test('304 es éxito y expone notModified', () async {
      final adapter = FakeHttpAdapter([
        (_) => ResponseBody.fromString(
          '',
          304,
          headers: {
            'etag': ['"abc"'],
          },
        ),
      ]);
      final result = await buildTestClient(adapter: adapter).client
          .send(const ApiRequest.get('/config'));
      final response = (result as Ok<ApiResponse>).value;
      expect(response.notModified, isTrue);
      expect(response.etag, '"abc"');
    });

    test('X-IPR-Data-State: stale se expone como isStale', () async {
      final adapter = FakeHttpAdapter([
        (_) => FakeHttpAdapter.json(
          {},
          headers: {
            'x-ipr-data-state': ['stale'],
          },
        ),
      ]);
      final result = await buildTestClient(adapter: adapter).client
          .send(const ApiRequest.get('/products'));
      expect((result as Ok<ApiResponse>).value.isStale, isTrue);
    });

    test(
      'sendDecoded convierte un fallo de mapeo en ContractFailure',
      () async {
        final adapter = FakeHttpAdapter([
          (_) => FakeHttpAdapter.json({'data': 'no es mapa'}),
        ]);
        final result = await buildTestClient(adapter: adapter).client
            .sendDecoded(
              const ApiRequest.get('/config'),
              (json) =>
                  (json! as Map<String, dynamic>)['data']
                      as Map<String, dynamic>,
            );
        final failure = result.failureOrNull;
        expect(failure, isA<ContractFailure>());
        expect((failure! as ContractFailure).detail, 'GET /config');
      },
    );

    test('sendDecoded devuelve el valor decodificado', () async {
      final adapter = FakeHttpAdapter([
        (_) => FakeHttpAdapter.json({'n': 3}),
      ]);
      final result = await buildTestClient(adapter: adapter).client.sendDecoded(
        const ApiRequest.get('/x'),
        (json) => (json! as Map<String, dynamic>)['n'] as int,
      );
      expect(result.valueOrNull, 3);
    });

    test('un 426 se notifica al observador de fallos', () async {
      final seen = <Object>[];
      final adapter = FakeHttpAdapter([
        (_) => FakeHttpAdapter.problem(426, 'app_version_unsupported'),
      ]);
      final built = buildTestClient(adapter: adapter, onFailure: seen.add);
      final result = await built.client.send(const ApiRequest.get('/config'));
      expect(result.failureOrNull, isA<UpgradeRequired>());
      expect(seen.single, isA<UpgradeRequired>());
    });

    test('Result.when, map y accesores', () {
      const ok = Ok<int>(2);
      const err = Err<int>(NotFound());
      expect(ok.when(ok: (v) => v * 2, err: (_) => -1), 4);
      expect(err.when(ok: (v) => v, err: (_) => -1), -1);
      expect(ok.map((v) => v + 1).valueOrNull, 3);
      expect(err.map((v) => v + 1).failureOrNull, isA<NotFound>());
      expect(ok.failureOrNull, isNull);
      expect(err.valueOrNull, isNull);
      expect(ok.isOk && err.isErr, isTrue);
    });
  });

  group('M0 · SC-031 · identificadores', () {
    test('uuidV4 genera UUID v4 válidos y distintos', () {
      final ids = {for (var i = 0; i < 200; i++) uuidV4()};
      expect(ids, hasLength(200));
      expect(ids.every(isUuidV4), isTrue);
    });

    test('isUuidV4 rechaza otros formatos', () {
      expect(isUuidV4('no-es-uuid'), isFalse);
      expect(
        isUuidV4('3F2B8C1E-5A4D-4E6F-9B7A-1C2D3E4F5A6B'),
        isFalse,
        reason: 'solo minúsculas',
      );
      expect(
        isUuidV4('3f2b8c1e-5a4d-1e6f-9b7a-1c2d3e4f5a6b'),
        isFalse,
        reason: 'versión 1, no 4',
      );
    });
  });
}
