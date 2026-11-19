import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/api_request.dart';
import 'package:ipr_mobile/core/session/session_gateway.dart';

import '../../../mocks/fake_http_adapter.dart';
import '../../../mocks/test_clients.dart';

final class FakeGateway implements SessionGateway {
  new({this.token, this.hasRefresh = false, List<RefreshOutcome>? outcomes})
    : outcomes = [...?outcomes];

  String? token;
  bool hasRefresh;
  final List<RefreshOutcome> outcomes;
  int refreshCalls = 0;
  int expireCalls = 0;
  String? tokenAfterRefresh;
  Completer<void>? gate;

  @override
  String? get accessToken => token;

  @override
  Future<bool> hasRefreshToken() async => hasRefresh;

  @override
  Future<RefreshOutcome> refresh() async {
    refreshCalls++;
    if (gate != null) await gate!.future;
    final outcome = outcomes.isEmpty
        ? RefreshOutcome.refreshed
        : outcomes.removeAt(0);
    if (outcome == RefreshOutcome.refreshed) {
      token = tokenAfterRefresh ?? 'ipra_new';
    }
    return outcome;
  }

  @override
  Future<void> expire() async => expireCalls++;
}

const _private = ApiRequest.get('/me', requiresAuth: true);

void main() {
  test('las rutas públicas no llevan Authorization', () async {
    final adapter = FakeHttpAdapter([(_) => FakeHttpAdapter.json({})]);
    final gateway = FakeGateway(token: 'ipra_a');
    await buildTestClient(
      adapter: adapter,
      gateway: gateway,
    ).client.send(const ApiRequest.get('/products'));
    expect(
      adapter.requests.single.headers.containsKey('Authorization'),
      isFalse,
    );
  });

  test('las rutas privadas llevan Bearer', () async {
    final adapter = FakeHttpAdapter([(_) => FakeHttpAdapter.json({})]);
    await buildTestClient(
      adapter: adapter,
      gateway: FakeGateway(token: 'ipra_a'),
    ).client.send(_private);
    expect(adapter.requests.single.headers['Authorization'], 'Bearer ipra_a');
  });

  test(
    'tras reiniciar (hay refresh pero no access) renueva antes de la petición',
    () async {
      final adapter = FakeHttpAdapter([(_) => FakeHttpAdapter.json({})]);
      final gateway = FakeGateway(hasRefresh: true)
        ..tokenAfterRefresh = 'ipra_fresh';
      await buildTestClient(
        adapter: adapter,
        gateway: gateway,
      ).client.send(_private);
      expect(gateway.refreshCalls, 1);
      expect(
        adapter.requests.single.headers['Authorization'],
        'Bearer ipra_fresh',
      );
    },
  );

  test(
    'sin sesión una ruta privada sale sin token y el servidor responde 401',
    () async {
      final adapter = FakeHttpAdapter([
        (_) => FakeHttpAdapter.problem(401, 'unauthorized'),
      ]);
      final gateway = FakeGateway(outcomes: [RefreshOutcome.expired]);
      final result = await buildTestClient(
        adapter: adapter,
        gateway: gateway,
      ).client.send(_private);
      expect(
        adapter.requests.single.headers.containsKey('Authorization'),
        isFalse,
      );
      expect(result.failureOrNull, isA<Unauthorized>());
    },
  );

  group('401 en rutas privadas', () {
    test('TC-020 · AC-044-3 · refresca y reintenta la petición original con el token nuevo', () async {
      final adapter = FakeHttpAdapter([
        (_) => FakeHttpAdapter.problem(401, 'unauthorized'),
        (_) => FakeHttpAdapter.json({'data': 'ok'}),
      ]);
      final gateway = FakeGateway(token: 'ipra_old')
        ..tokenAfterRefresh = 'ipra_new';
      final result = await buildTestClient(
        adapter: adapter,
        gateway: gateway,
      ).client.send(_private);
      expect(result.isOk, isTrue);
      expect(gateway.refreshCalls, 1);
      expect(adapter.requests, hasLength(2));
      expect(adapter.requests[0].headers['Authorization'], 'Bearer ipra_old');
      expect(adapter.requests[1].headers['Authorization'], 'Bearer ipra_new');
    });

    test(
      'TC-021 · AC-044-6 · cinco 401 simultáneos comparten un refresh',
      () async {
        final adapter = FakeHttpAdapter()
          ..fallback = (o) => o.headers['Authorization'] == 'Bearer ipra_old'
              ? FakeHttpAdapter.problem(401, 'unauthorized')
              : FakeHttpAdapter.json({'data': 'ok'});
        // Un solo refresh en vuelo: la puerta lo mantiene abierto hasta que los 5 llegan.
        final shared = Completer<RefreshOutcome>();
        final gateway = _SingleFlightGateway(shared.future);
        final built = buildTestClient(adapter: adapter, gateway: gateway);
        final calls = List.generate(5, (_) => built.client.send(_private));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        gateway.token = 'ipra_new';
        shared.complete(RefreshOutcome.refreshed);
        final results = await Future.wait(calls);
        expect(results.every((r) => r.isOk), isTrue);
        expect(gateway.underlyingRefreshes, 1);
      },
    );

    test('TC-022 · AC-044-5 · refresh rechazado: llega Unauthorized y no hay reintento', () async {
      final adapter = FakeHttpAdapter([
        (_) => FakeHttpAdapter.problem(401, 'unauthorized'),
      ]);
      final gateway = FakeGateway(
        token: 'ipra_old',
        outcomes: [RefreshOutcome.expired],
      );
      final result = await buildTestClient(
        adapter: adapter,
        gateway: gateway,
      ).client.send(_private);
      expect(result.failureOrNull, isA<Unauthorized>());
      expect(adapter.requests, hasLength(1));
    });

    test('TC-023 · AC-044-7 · fallo transitorio al renovar llega como NoConnection, no como sesión vencida', () async {
      final adapter = FakeHttpAdapter([
        (_) => FakeHttpAdapter.problem(401, 'unauthorized'),
      ]);
      final gateway = FakeGateway(
        token: 'ipra_old',
        outcomes: [RefreshOutcome.transientFailure],
      );
      final result = await buildTestClient(
        adapter: adapter,
        gateway: gateway,
      ).client.send(_private);
      expect(result.failureOrNull, isA<NoConnection>());
      expect(gateway.expireCalls, 0, reason: 'la sesión no se borra');
    });

    test(
      'un segundo 401 con el token recién renovado termina la sesión',
      () async {
        final adapter = FakeHttpAdapter()
          ..fallback = (_) => FakeHttpAdapter.problem(401, 'unauthorized');
        final gateway = FakeGateway(token: 'ipra_old');
        final result = await buildTestClient(
          adapter: adapter,
          gateway: gateway,
        ).client.send(_private);
        expect(result.failureOrNull, isA<Unauthorized>());
        expect(gateway.refreshCalls, 1);
        expect(gateway.expireCalls, 1);
        expect(adapter.requests, hasLength(2));
      },
    );

    test('el 401 de una ruta pública (login) no dispara refresh', () async {
      final adapter = FakeHttpAdapter([
        (_) => FakeHttpAdapter.problem(401, 'invalid_credentials'),
      ]);
      final gateway = FakeGateway();
      final result = await buildTestClient(
        adapter: adapter,
        gateway: gateway,
      ).client.send(const ApiRequest.post('/auth/login', body: {}));
      expect(
        (result.failureOrNull! as Unauthorized).code,
        'invalid_credentials',
      );
      expect(gateway.refreshCalls, 0);
    });

    test(
      'un error distinto de 401 en ruta privada no dispara refresh',
      () async {
        final adapter = FakeHttpAdapter([
          (_) => FakeHttpAdapter.problem(404, 'not_found'),
        ]);
        final gateway = FakeGateway(token: 'ipra_a');
        final result = await buildTestClient(
          adapter: adapter,
          gateway: gateway,
        ).client.send(_private);
        expect(result.failureOrNull, isA<NotFound>());
        expect(gateway.refreshCalls, 0);
      },
    );

    test(
      'si el reintento tras renovar falla con otro error, ese error llega',
      () async {
        final adapter = FakeHttpAdapter([
          (_) => FakeHttpAdapter.problem(401, 'unauthorized'),
          (_) => FakeHttpAdapter.problem(404, 'not_found'),
        ]);
        final result = await buildTestClient(
          adapter: adapter,
          gateway: FakeGateway(token: 'ipra_old'),
        ).client.send(_private);
        expect(result.failureOrNull, isA<NotFound>());
      },
    );
  });
}

/// Imita el refresh de vuelo único de `SessionController`: todas las llamadas
/// comparten el mismo `Future`.
final class _SingleFlightGateway extends FakeGateway {
  new(this._shared) : super(token: 'ipra_old');

  final Future<RefreshOutcome> _shared;
  int underlyingRefreshes = 0;
  Future<RefreshOutcome>? _inflight;

  @override
  Future<RefreshOutcome> refresh() {
    return _inflight ??= () {
      underlyingRefreshes++;
      return _shared;
    }();
  }
}
