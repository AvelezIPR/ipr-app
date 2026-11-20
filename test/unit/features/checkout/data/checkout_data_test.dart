import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/core/session/session_gateway.dart';
import 'package:ipr_mobile/core/storage/cache_store.dart';
import 'package:ipr_mobile/features/checkout/data/datasources/checkout_remote_datasource.dart';
import 'package:ipr_mobile/features/checkout/data/dtos/checkout_dtos.dart';
import 'package:ipr_mobile/features/checkout/data/mappers/checkout_mappers.dart';
import 'package:ipr_mobile/features/checkout/data/repositories/api_checkout_repository.dart';
import 'package:ipr_mobile/features/checkout/data/repositories/cache_pending_checkout_store.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/checkout_line.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/checkout_status.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/payment_state.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/pending_checkout.dart';

import '../../../../mocks/fake_http_adapter.dart';
import '../../../../mocks/test_clients.dart';
import '../support/checkout_fakes.dart';

const _token = 'ipra_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

final class _Gateway implements SessionGateway {
  @override
  String? get accessToken => _token;

  @override
  Future<bool> hasRefreshToken() async => true;

  @override
  Future<RefreshOutcome> refresh() async => RefreshOutcome.expired;

  @override
  Future<void> expire() async {}
}

Object _fixture(String name) =>
    jsonDecode(File('test/fixtures/checkout/$name').readAsStringSync())
        as Object;

const _lines = [
  CheckoutLine(productId: 1201, quantity: 2, name: 'Filtro de aire'),
  CheckoutLine(productId: 988, quantity: 1, name: 'Compresor'),
];

const _key = '11111111-1111-4111-8111-111111111111';

({ApiCheckoutRepository repo, FakeHttpAdapter adapter, List<Duration> sleeps})
_setup([List<Responder> responders = const []]) {
  final adapter = FakeHttpAdapter(responders);
  final built = buildTestClient(adapter: adapter, gateway: _Gateway());
  return (
    repo: ApiCheckoutRepository(CheckoutRemoteDataSource(built.client)),
    adapter: adapter,
    sleeps: built.sleeps,
  );
}

void main() {
  group(
    'TC-062 · AC-052-2 · AC-052-14 · POST /checkout solo envía {id, quantity}',
    () {
      test('cuerpo, cabeceras, ruta y tiempo de espera', () async {
        final h = _setup([
          (_) => FakeHttpAdapter.json(
            _fixture('CheckoutSession.valid.json'),
            status: 201,
          ),
        ]);
        final result = await h.repo.createCheckout(
          lines: _lines,
          idempotencyKey: _key,
        );

        expect(result.isOk, isTrue);
        final request = h.adapter.requests.single;
        expect(request.method, 'POST');
        expect(request.path, '/checkout');
        expect(request.headers['Idempotency-Key'], _key);
        expect(request.headers['Authorization'], 'Bearer $_token');
        expect(request.receiveTimeout, const Duration(seconds: 20));
        expect(request.queryParameters, isEmpty);
        expect(request.data, {
          'items': [
            {'id': 1201, 'quantity': 2},
            {'id': 988, 'quantity': 1},
          ],
        });
        // Ni precios, ni totales, ni usuario, ni rol, ni nombres, ni retorno.
        final sent = jsonEncode(request.data);
        for (final forbidden in [
          'price',
          'total',
          'customer',
          'role',
          'name',
          'return',
          'Filtro',
          'discount',
        ]) {
          expect(sent, isNot(contains(forbidden)), reason: forbidden);
        }
        expect((request.data as Map).keys, ['items']);
        for (final item in (request.data as Map)['items'] as List) {
          expect((item as Map).keys.toSet(), {'id', 'quantity'});
        }
      });

      test('el cuerpo cumple el contrato (fixture CartItemsRequest)', () {
        final body = checkoutRequestOf(const [
          CheckoutLine(productId: 1201, quantity: 2),
          CheckoutLine(productId: 988, quantity: 1),
        ]).toJson();
        expect(body, _fixture('CartItemsRequest.valid.json'));
      });

      test('un POST nunca se reintenta (503 → una sola petición)', () async {
        final h = _setup([
          (_) => FakeHttpAdapter.problem(503, 'upstream_unavailable'),
          (_) => FakeHttpAdapter.json(
            _fixture('CheckoutSession.valid.json'),
            status: 201,
          ),
        ]);
        final result = await h.repo.createCheckout(
          lines: _lines,
          idempotencyKey: _key,
        );
        expect(result.failureOrNull, isA<ServiceUnavailable>());
        expect(h.adapter.requests, hasLength(1));
        expect(h.sleeps, isEmpty);
      });

      test(
        'la misma clave viaja tal cual al repetir el MISMO intento',
        () async {
          final h = _setup([
            FakeHttpAdapter.connectionError,
            (_) => FakeHttpAdapter.problem(503, 'upstream_unavailable'),
          ]);
          await h.repo.createCheckout(lines: _lines, idempotencyKey: _key);
          await h.repo.createCheckout(lines: _lines, idempotencyKey: _key);
          expect(h.adapter.requests.map((r) => r.headers['Idempotency-Key']), [
            _key,
            _key,
          ]);
        },
      );
    },
  );

  group('TC-064 · AC-058-1 · AC-058-2 · errores de POST /checkout', () {
    Future<AppFailure?> failWith(Responder responder) async {
      final h = _setup([responder]);
      final result = await h.repo.createCheckout(
        lines: _lines,
        idempotencyKey: _key,
      );
      return result.failureOrNull;
    }

    test('400 → Validation', () async {
      expect(
        await failWith(
          (_) => FakeHttpAdapter.problem(400, 'validation_failed'),
        ),
        isA<Validation>(),
      );
    });

    test('401 → Unauthorized (sesión terminada)', () async {
      expect(
        await failWith((_) => FakeHttpAdapter.problem(401, 'unauthorized')),
        isA<Unauthorized>(),
      );
    });

    test('409 → Conflict con su código', () async {
      final failure = await failWith(
        (_) => FakeHttpAdapter.problem(409, 'idempotency_conflict'),
      );
      expect(failure, isA<Conflict>());
      expect((failure! as Conflict).code, 'idempotency_conflict');
    });

    test('429 → RateLimited con la espera', () async {
      final failure = await failWith(
        (_) => FakeHttpAdapter.problem(
          429,
          'rate_limited',
          retryAfter: 30,
          headers: const {
            'retry-after': ['30'],
          },
        ),
      );
      expect(failure, isA<RateLimited>());
      expect((failure! as RateLimited).retryAfterSeconds, 30);
    });

    test('502, 503 y 504 → ServiceUnavailable', () async {
      for (final status in [502, 503, 504]) {
        expect(
          await failWith((_) => FakeHttpAdapter.problem(status, 'upstream')),
          isA<ServiceUnavailable>(),
          reason: '$status',
        );
      }
    });

    test('tiempo agotado y sin red', () async {
      expect(await failWith(FakeHttpAdapter.timeout), isA<RequestTimeout>());
      expect(
        await failWith(FakeHttpAdapter.connectionError),
        isA<NoConnection>(),
      );
    });

    test('HTML del borde (403) no se vuelca: BlockedByEdge', () async {
      expect(
        await failWith((_) => FakeHttpAdapter.html(403)),
        isA<BlockedByEdge>(),
      );
    });

    test(
      'AC-058-3 · 201 sin checkoutUrl → ContractFailure sin la respuesta',
      () async {
        final failure = await failWith(
          (_) => FakeHttpAdapter.json(
            _fixture('CheckoutSession.no-url.json'),
            status: 201,
          ),
        );
        expect(failure, isA<ContractFailure>());
        expect((failure! as ContractFailure).detail, 'POST /checkout');
      },
    );

    test('checkoutRef que no es UUID v4 → ContractFailure', () async {
      final body = {
        'data': {
          'checkoutRef': 'no-es-un-uuid',
          'checkoutUrl': 'https://staging.invalid/?ipr_ticket=$ticketSecret',
          'allowedHosts': ['staging.invalid'],
        },
      };
      final failure = await failWith(
        (_) => FakeHttpAdapter.json(body, status: 201),
      );
      expect(failure, isA<ContractFailure>());
      expect(failure.toString(), isNot(contains(ticketSecret)));
    });

    test('checkoutUrl relativa o sin host → ContractFailure', () async {
      for (final url in ['/solo-ruta?ipr_ticket=$ticketSecret', 'https://']) {
        final body = {
          'data': {
            'checkoutRef': refA,
            'checkoutUrl': url,
            'allowedHosts': ['staging.invalid'],
          },
        };
        final failure = await failWith(
          (_) => FakeHttpAdapter.json(body, status: 201),
        );
        expect(failure, isA<ContractFailure>(), reason: url);
      }
    });
  });

  group('TC-066 · SC-023 · el ticket no sale en ningún toString', () {
    test('DTO y entidad ocultan la URL', () {
      final dto = CheckoutSessionDto.fromJson(
        _fixture('CheckoutSession.valid.json'),
      );
      expect(dto.toString(), isNot(contains(ticketSecret)));
      expect(dto.toString(), isNot(contains('ipr_ticket')));
      final ticket = mapCheckoutTicket(dto);
      expect(ticket.toString(), isNot(contains('ipr_ticket')));
      expect(ticket.toString(), isNot(contains('staging.invalid')));
      expect(ticket.checkoutUrl.queryParameters['ipr_ticket'], hasLength(32));
    });

    test('mapeo de la sesión del contrato', () {
      final ticket = mapCheckoutTicket(
        CheckoutSessionDto.fromJson(_fixture('CheckoutSession.valid.json')),
      );
      expect(ticket.checkoutRef, '3f2b8c1e-5a4d-4e6f-9b7a-1c2d3e4f5a6b');
      expect(ticket.allowedHosts, {'staging.invalid'});
      expect(ticket.expiresAt, DateTime.utc(2026, 11, 20, 15, 1));
      expect(ticket.checkoutUrl.scheme, 'https');
    });

    test('hosts y referencia se normalizan a minúsculas', () {
      final ticket = mapCheckoutTicket(
        const CheckoutSessionDto(
          checkoutRef: '3F2B8C1E-5A4D-4E6F-9B7A-1C2D3E4F5A6B',
          checkoutUrl: 'https://Staging.Invalid/?ipr_ticket=x',
          allowedHosts: ['Staging.INVALID'],
        ),
      );
      expect(ticket.checkoutRef, refA);
      expect(ticket.allowedHosts, {'staging.invalid'});
    });

    test('allowedHosts ausente o con basura: conjunto vacío / filtrado', () {
      final dto = CheckoutSessionDto.fromJson({
        'data': {
          'checkoutRef': refA,
          'checkoutUrl': 'https://staging.invalid/?t=1',
          'allowedHosts': ['staging.invalid', 3, '', null],
          'expiresAt': 'no-es-fecha',
        },
      });
      expect(dto.allowedHosts, ['staging.invalid']);
      expect(dto.expiresAt, isNull);
      final sinHosts = CheckoutSessionDto.fromJson({
        'data': {'checkoutRef': refA, 'checkoutUrl': 'https://x.invalid/'},
      });
      expect(sinHosts.allowedHosts, isEmpty);
    });

    test('respuestas que no son objetos fallan sin volcar nada', () {
      for (final bad in [
        null,
        'texto',
        3,
        <Object?>[],
        {'data': 'x'},
      ]) {
        expect(() => CheckoutSessionDto.fromJson(bad), throwsFormatException);
        expect(() => CheckoutStatusDto.fromJson(bad), throwsFormatException);
      }
    });
  });

  group('TC-079 · AC-056-1 · AC-056-8 · GET /checkout/{ref}', () {
    Future<Result<CheckoutStatus>> statusOf(Object body) {
      final h = _setup([(_) => FakeHttpAdapter.json(body)]);
      return h.repo.status(refA);
    }

    test('petición autenticada, sin cuerpo ni clave de idempotencia', () async {
      final h = _setup([
        (_) => FakeHttpAdapter.json(_fixture('CheckoutStatus.paid.valid.json')),
      ]);
      await h.repo.status(refA);
      final request = h.adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/checkout/$refA');
      expect(request.headers['Authorization'], 'Bearer $_token');
      expect(request.headers.containsKey('Idempotency-Key'), isFalse);
      expect(request.data, isNull);
    });

    test(
      'un GET sí se reintenta ante 503 (espera creciente de core)',
      () async {
        final h = _setup([
          (_) => FakeHttpAdapter.problem(503, 'upstream_unavailable'),
          (_) =>
              FakeHttpAdapter.json(_fixture('CheckoutStatus.paid.valid.json')),
        ]);
        final result = await h.repo.status(refA);
        expect(result.isOk, isTrue);
        expect(h.adapter.requests, hasLength(2));
      },
    );

    for (final state in PaymentState.values) {
      test('order_created con paymentState=${state.name}', () async {
        final result = await statusOf(
          _fixture('CheckoutStatus.${state.name}.valid.json'),
        );
        final status = result.valueOrNull!;
        expect(status.checkoutRef, refA);
        expect(status.order?.paymentState, state);
        expect(status.order?.number, '1001');
        expect(status.order?.statusLabel, 'Estado sintético ${state.name}');
      });
    }

    test('awaiting_order → sin pedido', () async {
      final status = (await statusOf(
        _fixture('CheckoutStatus.awaiting-order.valid.json'),
      )).valueOrNull!;
      expect(status.awaitingOrder, isTrue);
    });

    test('estado desconocido del servidor nunca es pagado', () async {
      final status = (await statusOf(_fixture('CheckoutStatus.bad-state.json')))
          .valueOrNull!;
      expect(status.awaitingOrder, isTrue);
    });

    test('paymentState nuevo (on-hold) → unknown, no pagado', () async {
      final body = {
        'data': {
          'checkoutRef': refA,
          'state': 'order_created',
          'order': {
            'id': 7,
            'number': 'A-7',
            'statusLabel': 'En espera',
            'paymentState': 'on-hold',
          },
        },
      };
      final status = (await statusOf(body)).valueOrNull!;
      expect(status.order?.paymentState, PaymentState.unknown);
      expect(status.order?.statusLabel, 'En espera');
    });

    test('order_created sin pedido utilizable → aún sin pedido', () async {
      for (final order in <Object?>[
        null,
        'texto',
        {'id': 'x', 'number': '1'},
        {'id': 1},
        {'id': 1, 'number': ''},
      ]) {
        final status = (await statusOf({
          'data': {
            'checkoutRef': refA,
            'state': 'order_created',
            'order': order,
          },
        })).valueOrNull!;
        expect(status.awaitingOrder, isTrue, reason: '$order');
      }
    });

    test('etiqueta ausente → cadena vacía', () async {
      final status = (await statusOf({
        'data': {
          'checkoutRef': refA,
          'state': 'order_created',
          'order': {'id': 1, 'number': '1', 'paymentState': 'paid'},
        },
      })).valueOrNull!;
      expect(status.order?.statusLabel, isEmpty);
    });

    test('checkoutRef que no es UUID v4 → ContractFailure', () async {
      final result = await statusOf({
        'data': {'checkoutRef': 'x', 'state': 'awaiting_order', 'order': null},
      });
      expect(result.failureOrNull, isA<ContractFailure>());
    });

    test('401 y 429 → fallos tipados', () async {
      for (final (status, code, type) in [
        (401, 'unauthorized', Unauthorized),
        (429, 'rate_limited', RateLimited),
      ]) {
        final h = _setup([
          (_) => FakeHttpAdapter.problem(
            status,
            code,
            // > 10 s: el GET no se reintenta y el fallo llega tal cual.
            retryAfter: status == 429 ? 60 : null,
            headers: status == 429
                ? const {
                    'retry-after': ['60'],
                  }
                : const {},
          ),
        ]);
        final failure = (await h.repo.status(refA)).failureOrNull!;
        expect(failure.runtimeType, type);
      }
    });
  });

  group('TC-071 · AC-057-8 · registro del intento en curso (sin PII)', () {
    late MemoryCacheStore cache;
    late DateTime now;
    late CachePendingCheckoutStore store;

    setUp(() {
      cache = MemoryCacheStore(now: () => now);
      now = DateTime.utc(2026, 11, 20, 15);
      store = CachePendingCheckoutStore(cache, now: () => now);
    });

    final pending = PendingCheckout(
      checkoutRef: refA,
      attemptId: '00000000-0000-4000-8000-000000000001',
      startedAt: DateTime.utc(2026, 11, 20, 15),
    );

    test('guarda y recupera {ref, intento, marca de tiempo}', () async {
      await store.save(pending);
      expect(await store.load(), pending);
    });

    test('lo guardado contiene solo tres campos opacos', () async {
      await store.save(pending);
      final raw = (await cache.read(
        CachePendingCheckoutStore.key,
        CachePolicy.listing,
      ))!.value;
      expect((jsonDecode(raw) as Map).keys.toSet(), {'ref', 'attempt', 'at'});
      for (final forbidden in ['ipr_ticket', 'https', 'email', 'token', '@']) {
        expect(raw, isNot(contains(forbidden)), reason: forbidden);
      }
    });

    test('sin registro → null', () async {
      expect(await store.load(), isNull);
    });

    test('caduca a los 30 minutos y se borra', () async {
      await store.save(pending);
      now = now.add(const Duration(minutes: 29));
      expect(await store.load(), pending);
      now = now.add(const Duration(minutes: 2));
      expect(await store.load(), isNull);
      expect(cache.length, 0);
    });

    test('clear lo borra', () async {
      await store.save(pending);
      await store.clear();
      expect(await store.load(), isNull);
    });

    test('un registro dañado o con datos raros se descarta', () async {
      for (final raw in [
        'no es json',
        '[]',
        jsonEncode({'ref': 'x', 'attempt': 'a', 'at': 1}),
        jsonEncode({'ref': refA, 'attempt': '', 'at': 1}),
        jsonEncode({'ref': refA, 'attempt': 'a' * 65, 'at': 1}),
        jsonEncode({'ref': refA, 'attempt': 'a', 'at': 'ayer'}),
        jsonEncode({'ref': refA, 'attempt': 'a'}),
      ]) {
        await cache.write(CachePendingCheckoutStore.key, raw);
        expect(await store.load(), isNull, reason: raw);
        expect(cache.length, 0, reason: 'se borra: $raw');
      }
    });

    test('la entidad no imprime más que el ref', () {
      expect(pending.toString(), 'PendingCheckout($refA)');
      expect(
        pending,
        equals(
          PendingCheckout(
            checkoutRef: refA,
            attemptId: pending.attemptId,
            startedAt: pending.startedAt,
          ),
        ),
      );
      expect(pending.hashCode, pending.hashCode);
    });
  });

  group('M3 · RF-052 · tipos de entidades', () {
    test('CheckoutTicket sin URL en toString', () {
      final ticket = makeTicket();
      expect(ticket.toString(), isNot(contains(ticketSecret)));
    });
  });
}
