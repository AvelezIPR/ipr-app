import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/config/app_config.dart';
import 'package:ipr_mobile/core/config/remote_config_controller.dart';
import 'package:ipr_mobile/core/config/remote_config_repository.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/api_client.dart';
import 'package:ipr_mobile/core/network/api_request.dart';
import 'package:ipr_mobile/core/network/interceptors/app_headers_interceptor.dart';
import 'package:ipr_mobile/core/network/interceptors/error_mapping_interceptor.dart';
import 'package:ipr_mobile/core/network/interceptors/retry_interceptor.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/core/network/uuid_v4.dart';
import 'package:ipr_mobile/core/session/auth_interceptor.dart';
import 'package:ipr_mobile/core/session/session_controller.dart';
import 'package:ipr_mobile/core/session/session_remote.dart';
import 'package:ipr_mobile/core/session/session_state.dart';
import 'package:ipr_mobile/core/session/token_store.dart';
import 'package:ipr_mobile/core/storage/cache_store.dart';
import 'package:ipr_mobile/features/authentication/data/datasources/auth_remote_datasource.dart';
import 'package:ipr_mobile/features/authentication/data/repositories/api_auth_repository.dart';
import 'package:ipr_mobile/features/authentication/domain/entities/authenticated_session.dart';
import 'package:ipr_mobile/features/authentication/domain/entities/login_credentials.dart';
import 'package:ipr_mobile/features/branches/data/datasources/branches_remote_datasource.dart';
import 'package:ipr_mobile/features/branches/data/repositories/api_branches_repository.dart';
import 'package:ipr_mobile/features/branches/domain/repositories/branches_repository.dart';
import 'package:ipr_mobile/features/catalog/data/datasources/catalog_remote_datasource.dart';
import 'package:ipr_mobile/features/catalog/data/repositories/api_catalog_repository.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/brand.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/category_node.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/filter_dimension.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/product_page.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/product_query.dart';
import 'package:ipr_mobile/features/checkout/data/datasources/checkout_remote_datasource.dart';
import 'package:ipr_mobile/features/checkout/data/repositories/api_checkout_repository.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/checkout_line.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/checkout_ticket.dart';
import 'package:ipr_mobile/features/orders/data/datasources/orders_remote_datasource.dart';
import 'package:ipr_mobile/features/orders/data/repositories/api_orders_repository.dart';
import 'package:ipr_mobile/features/orders/domain/entities/order_entities.dart';
import 'package:ipr_mobile/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:ipr_mobile/features/profile/data/repositories/api_profile_repository.dart';
import 'package:ipr_mobile/features/profile/domain/entities/profile_entities.dart';
import 'package:ipr_mobile/features/search/data/datasources/search_remote_datasource.dart';
import 'package:ipr_mobile/features/search/data/repositories/api_search_repository.dart';
import 'package:ipr_mobile/features/search/domain/entities/search_page.dart';
import 'package:ipr_mobile/features/support/data/datasources/pqrs_remote_datasource.dart';
import 'package:ipr_mobile/features/support/data/repositories/api_pqrs_repository.dart';
import 'package:ipr_mobile/features/support/domain/entities/pqrs.dart';

import '../../../tool/mock_bff/mock_bff.dart';
import '../../../tool/preview/main.dart';

typedef _RecordedRequest = ({
  String method,
  String path,
  Map<String, Object?> queryParameters,
  Map<String, Object?> headers,
});

/// Observa los encabezados exactos que salen al cable sin alterar la petición.
final class _RecordingInterceptor extends Interceptor {
  new(this.requests);

  final List<_RecordedRequest> requests;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    requests.add((
      method: options.method,
      path: options.path,
      queryParameters: Map<String, Object?>.of(options.queryParameters),
      headers: Map<String, Object?>.of(options.headers),
    ));
    handler.next(options);
  }
}

final class _E2eHarness {
  new({
    required this.baseUrl,
    required this.secure,
    required this.tokenStore,
    required this.container,
    required this.session,
    required this.client,
    required this.requests,
    required this.sleeps,
    required this.failures,
  });

  final Uri baseUrl;
  final MemorySecure secure;
  final TokenStore tokenStore;
  final ProviderContainer container;
  final SessionController session;
  final ApiClient client;
  final List<_RecordedRequest> requests;
  final List<Duration> sleeps;
  final List<AppFailure> failures;

  List<_RecordedRequest> requestsFor(String method, String path) => [
    for (final r in requests)
      if (r.method == method && r.path == path) r,
  ];
}

Future<_E2eHarness> _startHarness() async {
  final server = await startMockBff(); // puerto efímero (port: 0 por defecto)
  addTearDown(() => server.close(force: true));

  final baseUrl = Uri.parse('http://127.0.0.1:${server.port}/mobile/v1');
  final config = AppConfig.fromMap({
    'environment': 'dev',
    'apiBaseUrl': baseUrl.toString(),
    'deepLinkHost': 'dev.invalid',
    'checkoutAllowedHosts': 'dev.invalid',
    'mediaHosts': 'dev.invalid',
    'supportWhatsApp': '573000000000',
  });

  final secure = MemorySecure();
  final tokenStore = TokenStore(secure);
  final bareClient = ApiClient.build(
    config: config,
    interceptors: (dio) => [
      AppHeadersInterceptor(
        appVersion: '1.0.0',
        platform: 'android',
        deviceId: tokenStore.deviceId,
      ),
      RetryInterceptor(dio: dio, sleep: (_) async {}),
      ErrorMappingInterceptor(),
    ],
  );

  final container = ProviderContainer(
    overrides: [
      sessionDependenciesProvider.overrideWithValue(
        SessionDependencies(
          tokenStore: tokenStore,
          remote: ApiSessionRemote(bareClient),
          sleep: (_) async {},
        ),
      ),
    ],
  );
  addTearDown(container.dispose);

  final session = container.read(sessionControllerProvider.notifier);
  final requests = <_RecordedRequest>[];
  final sleeps = <Duration>[];
  final failures = <AppFailure>[];

  final client = ApiClient.build(
    config: config,
    interceptors: (dio) => [
      AppHeadersInterceptor(
        appVersion: '1.0.0',
        platform: 'android',
        deviceId: tokenStore.deviceId,
      ),
      AuthInterceptor(gateway: session, dio: dio),
      RetryInterceptor(dio: dio, sleep: (d) async => sleeps.add(d)),
      ErrorMappingInterceptor(onFailure: failures.add),
      _RecordingInterceptor(requests),
    ],
  );

  return _E2eHarness(
    baseUrl: baseUrl,
    secure: secure,
    tokenStore: tokenStore,
    container: container,
    session: session,
    client: client,
    requests: requests,
    sleeps: sleeps,
    failures: failures,
  );
}

void main() {
  group('TC-144 · Flujo público M1/M5 por HTTP real', () {
    test('TC-144 · GET /config, /categories, /brands, /products, /filters, /search?q=ab y /stores responden OK sin Authorization incluso con sesión activa', () async {
      final h = await _startHarness();
      await h.session.restore();

      // Autenticamos primero para demostrar que AuthInterceptor nunca filtra
      // Authorization a las rutas públicas (RF-037).
      final authRepo = ApiAuthRepository(AuthRemoteDataSource(h.client));
      final loginRes = await authRepo.login(
        const LoginCredentials(
          login: 'cliente@example.invalid',
          password: 'QaPassword123!',
        ),
      );
      final auth = (loginRes as Ok<AuthenticatedSession>).value;
      await h.session.setSession(auth.tokens, userId: auth.userId);
      h.requests.clear();

      final cache = MemoryCacheStore();
      final configRepo = RemoteConfigRepository(
        client: h.client,
        cache: cache,
        platform: 'android',
      );
      final catalogRepo = ApiCatalogRepository(
        remote: CatalogRemoteDataSource(h.client),
        cache: cache,
      );
      final searchRepo = ApiSearchRepository(SearchRemoteDataSource(h.client));
      final branchesRepo = ApiBranchesRepository(
        remote: BranchesRemoteDataSource(h.client),
        cache: cache,
      );

      final cfgRes = await configRepo.fetch();
      expect(cfgRes, isA<Ok<Object?>>(), reason: '${cfgRes.failureOrNull}');

      final catRes = await catalogRepo.categories(forceRefresh: true);
      expect(catRes, isA<Ok<Cached<List<CategoryNode>>>>());
      expect(
        (catRes as Ok<Cached<List<CategoryNode>>>).value.value,
        isNotEmpty,
      );

      final brandRes = await catalogRepo.brands(forceRefresh: true);
      expect(brandRes, isA<Ok<Cached<List<Brand>>>>());
      expect((brandRes as Ok<Cached<List<Brand>>>).value.value, isNotEmpty);

      final prodRes = await catalogRepo.products(
        const ProductQuery(scope: ListScope.all()),
        forceRefresh: true,
      );
      expect(prodRes, isA<Ok<Cached<ProductPage>>>());
      expect(
        (prodRes as Ok<Cached<ProductPage>>).value.value.items,
        isNotEmpty,
      );

      final filterRes = await catalogRepo.filters(forceRefresh: true);
      expect(filterRes, isA<Ok<Cached<List<FilterDimension>>>>());

      final searchRes = await searchRepo.search('ab');
      expect(searchRes, isA<Ok<SearchPage>>());
      expect((searchRes as Ok<SearchPage>).value.items, isNotEmpty);

      final storesRes = await branchesRepo.stores(forceRefresh: true);
      expect(storesRes, isA<Ok<BranchesSnapshot>>());
      expect((storesRes as Ok<BranchesSnapshot>).value.branches, isNotEmpty);

      const expectedPaths = [
        '/config',
        '/categories',
        '/brands',
        '/products',
        '/filters',
        '/search',
        '/stores',
      ];
      expect([for (final r in h.requests) r.path], containsAll(expectedPaths));
      final searchReq = h.requestsFor('GET', '/search').single;
      expect(searchReq.queryParameters['q'], 'ab');

      for (final r in h.requests) {
        expect(
          r.headers.containsKey('Authorization'),
          isFalse,
          reason: '${r.method} ${r.path} no debe enviar Authorization',
        );
      }
    });
  });

  group('TC-144 · Flujo privado M2/M4 por HTTP real', () {
    test(
      'TC-144 · rutas privadas sin Bearer devuelven 401 Unauthorized',
      () async {
        final h = await _startHarness();
        await h.session.restore();
        expect(
          h.container.read(sessionControllerProvider),
          isA<SessionAnonymous>(),
        );

        final profileRepo = ApiProfileRepository(
          ProfileRemoteDataSource(h.client),
        );
        final ordersRepo = ApiOrdersRepository(
          OrdersRemoteDataSource(h.client),
        );

        final meRes = await profileRepo.getMe();
        final listRes = await ordersRepo.listOrders();
        final detailRes = await ordersRepo.getOrder(1);

        expect(meRes.failureOrNull, isA<Unauthorized>());
        expect(listRes.failureOrNull, isA<Unauthorized>());
        expect(detailRes.failureOrNull, isA<Unauthorized>());
        for (final r in h.requests) {
          expect(r.headers.containsKey('Authorization'), isFalse);
        }
      },
    );

    test('TC-144 · POST /auth/login → SessionController → GET /me, /orders y /orders/1 con Bearer y X-Device-Id', () async {
      final h = await _startHarness();
      await h.session.restore();

      final authRepo = ApiAuthRepository(AuthRemoteDataSource(h.client));
      final profileRepo = ApiProfileRepository(
        ProfileRemoteDataSource(h.client),
      );
      final ordersRepo = ApiOrdersRepository(OrdersRemoteDataSource(h.client));

      final loginRes = await authRepo.login(
        const LoginCredentials(
          login: 'cliente@example.invalid',
          password: 'QaPassword123!',
        ),
      );
      expect(loginRes, isA<Ok<AuthenticatedSession>>());
      final auth = (loginRes as Ok<AuthenticatedSession>).value;

      await h.session.setSession(auth.tokens, userId: auth.userId);
      expect(
        h.container.read(sessionControllerProvider),
        isA<SessionAuthenticated>(),
      );
      expect(
        (h.container.read(
          sessionControllerProvider,
        ) as SessionAuthenticated).userId,
        auth.userId,
      );

      final meRes = await profileRepo.getMe();
      expect(meRes, isA<Ok<UserProfile>>(), reason: '${meRes.failureOrNull}');
      expect((meRes as Ok<UserProfile>).value.id, greaterThan(0));

      final listRes = await ordersRepo.listOrders();
      expect(listRes, isA<Ok<OrderPage>>(), reason: '${listRes.failureOrNull}');
      expect((listRes as Ok<OrderPage>).value.items, isNotEmpty);

      final detailRes = await ordersRepo.getOrder(1);
      expect(
        detailRes,
        isA<Ok<OrderDetail>>(),
        reason: '${detailRes.failureOrNull}',
      );
      expect((detailRes as Ok<OrderDetail>).value.summary.id, 1);

      final expectedDeviceId = await h.tokenStore.deviceId();
      for (final path in ['/me', '/orders', '/orders/1']) {
        final req = h.requestsFor('GET', path).single;
        expect(
          req.headers['Authorization'],
          'Bearer ${auth.tokens.accessToken}',
          reason: path,
        );
        expect(req.headers['X-Device-Id'], expectedDeviceId, reason: path);
        expect(isUuidV4(expectedDeviceId), isTrue);
      }
    });
  });

  group('ST-087 · CR-005 · Idempotencia obligatoria por HTTP real', () {
    test('ST-087 · POST /checkout, /me/deletion y /pqrs envían Idempotency-Key UUID v4 y responden OK', () async {
      final h = await _startHarness();
      await h.session.restore();

      final authRepo = ApiAuthRepository(AuthRemoteDataSource(h.client));
      final loginRes = await authRepo.login(
        const LoginCredentials(
          login: 'cliente@example.invalid',
          password: 'QaPassword123!',
        ),
      );
      final auth = (loginRes as Ok<AuthenticatedSession>).value;
      await h.session.setSession(auth.tokens, userId: auth.userId);

      final checkoutRepo = ApiCheckoutRepository(
        CheckoutRemoteDataSource(h.client),
      );
      final profileRepo = ApiProfileRepository(
        ProfileRemoteDataSource(h.client),
      );
      final pqrsRepo = ApiPqrsRepository(PqrsRemoteDataSource(h.client));

      final checkoutKey = uuidV4();
      final deletionKey = uuidV4();
      final pqrsKey = uuidV4();

      final checkoutRes = await checkoutRepo.createCheckout(
        lines: const [CheckoutLine(productId: 101, quantity: 2)],
        idempotencyKey: checkoutKey,
      );
      expect(
        checkoutRes,
        isA<Ok<CheckoutTicket>>(),
        reason: '${checkoutRes.failureOrNull}',
      );
      expect(
        isUuidV4((checkoutRes as Ok<CheckoutTicket>).value.checkoutRef),
        isTrue,
      );

      final deletionRes = await profileRepo.requestDeletion(
        currentPassword: 'QaPassword123!',
        idempotencyKey: deletionKey,
      );
      expect(
        deletionRes,
        isA<Ok<AccountDeletionStatus>>(),
        reason: '${deletionRes.failureOrNull}',
      );
      expect(
        (deletionRes as Ok<AccountDeletionStatus>).value.status,
        AccountDeletionState.scheduled,
      );

      final pqrsRes = await pqrsRepo.submit(
        submission: const PqrsSubmission(
          type: PqrsType.peticion,
          name: 'Ana Prueba',
          email: 'ana@ejemplo.test',
          phone: '3000000001',
          message: 'Consulta sintética de idempotencia.',
          acceptsDataPolicy: true,
        ),
        idempotencyKey: pqrsKey,
      );
      expect(
        pqrsRes,
        isA<Ok<PqrsReceipt>>(),
        reason: '${pqrsRes.failureOrNull}',
      );
      expect((pqrsRes as Ok<PqrsReceipt>).value.status, 'received');

      final checkoutReq = h.requestsFor('POST', '/checkout').single;
      expect(checkoutReq.headers['Idempotency-Key'], checkoutKey);
      expect(isUuidV4(checkoutKey), isTrue);

      final deletionReq = h.requestsFor('POST', '/me/deletion').single;
      expect(deletionReq.headers['Idempotency-Key'], deletionKey);
      expect(isUuidV4(deletionKey), isTrue);

      final pqrsReq = h.requestsFor('POST', '/pqrs').single;
      expect(pqrsReq.headers['Idempotency-Key'], pqrsKey);
      expect(isUuidV4(pqrsKey), isTrue);
      expect(pqrsReq.headers.containsKey('Authorization'), isFalse);
    });

    test('ST-087 · el BFF rechaza con 400 validation_failed al enviar POST /checkout, /me/deletion o /pqrs sin Idempotency-Key', () async {
      final h = await _startHarness();
      await h.session.restore();

      final authRepo = ApiAuthRepository(AuthRemoteDataSource(h.client));
      final auth = ((await authRepo.login(
        const LoginCredentials(
          login: 'cliente@example.invalid',
          password: 'QaPassword123!',
        ),
      )) as Ok<AuthenticatedSession>).value;
      await h.session.setSession(auth.tokens, userId: auth.userId);

      final checkoutNoKey = await h.client.send(
        const ApiRequest.post(
          '/checkout',
          body: {
            'items': [
              {'id': 101, 'quantity': 1},
            ],
          },
          requiresAuth: true,
        ),
      );
      final deletionNoKey = await h.client.send(
        const ApiRequest.post(
          '/me/deletion',
          body: {'currentPassword': 'QaPassword123!', 'confirm': true},
          requiresAuth: true,
        ),
      );
      final pqrsNoKey = await h.client.send(
        const ApiRequest.post(
          '/pqrs',
          body: {
            'type': 'peticion',
            'name': 'Ana Prueba',
            'email': 'ana@example.invalid',
            'phone': '3000000001',
            'message': 'Solicitud sin clave.',
            'acceptsDataPolicy': true,
          },
        ),
      );

      for (final result in [checkoutNoKey, deletionNoKey, pqrsNoKey]) {
        final failure = result.failureOrNull;
        expect(failure, isA<Validation>());
        final validation = failure! as Validation;
        expect(validation.code, 'validation_failed');
        expect(
          validation.fields.any(
            (f) => f.field == 'Idempotency-Key' && f.code == 'required',
          ),
          isTrue,
        );
      }
    });
  });

  group(
    'ST-072 · ST-073 · Escenarios de error y borde con X-Mock-Scenario',
    () {
      test('ST-072 · ST-073 · error:426, error:429, error:503 (con reintentos) y html403 mapean al AppFailure esperado', () async {
        final h = await _startHarness();

        // 426 UpgradeRequired (sin reintentos)
        final r426 = await h.client.send(
          const ApiRequest.get(
            '/products',
            headers: {'X-Mock-Scenario': 'error:426'},
          ),
        );
        expect(r426.failureOrNull, isA<UpgradeRequired>());
        expect(h.requests, hasLength(1));
        expect(h.sleeps, isEmpty);
        expect(h.failures.last, isA<UpgradeRequired>());

        // 429 RateLimited(retryAfter: 1) — GET reintenta 2 veces respetando Retry-After
        h.requests.clear();
        h.sleeps.clear();
        final r429 = await h.client.send(
          const ApiRequest.get(
            '/products',
            headers: {'X-Mock-Scenario': 'error:429'},
          ),
        );
        expect(r429.failureOrNull, isA<RateLimited>());
        expect((r429.failureOrNull! as RateLimited).retryAfter, 1);
        expect(h.requests, hasLength(3));
        expect(h.sleeps, [
          const Duration(seconds: 1),
          const Duration(seconds: 1),
        ]);

        // 503 ServiceUnavailable — GET reintenta 2 veces antes de devolver ServiceUnavailable
        h.requests.clear();
        h.sleeps.clear();
        final r503 = await h.client.send(
          const ApiRequest.get(
            '/products',
            headers: {'X-Mock-Scenario': 'error:503'},
          ),
        );
        expect(r503.failureOrNull, isA<ServiceUnavailable>());
        expect((r503.failureOrNull! as ServiceUnavailable).retryAfter, 1);
        expect(h.requests, hasLength(3));
        expect(h.sleeps, [
          const Duration(seconds: 1),
          const Duration(seconds: 1),
        ]);

        // html403 BlockedByEdge (sin reintentos)
        h.requests.clear();
        h.sleeps.clear();
        final rHtml = await h.client.send(
          const ApiRequest.get(
            '/products',
            headers: {'X-Mock-Scenario': 'html403'},
          ),
        );
        expect(rHtml.failureOrNull, isA<BlockedByEdge>());
        expect(h.requests, hasLength(1));
        expect(h.sleeps, isEmpty);
      });
    },
  );

  group('PT-19 · Smoke de arranque de preview (tool/preview/main.dart)', () {
    test('PT-19 · bootstrapPreviewContainer transiciona SessionController de SessionUnknown a SessionAnonymous (no autenticado) con MemorySecure/MemoryPrefs', () async {
      final server =
          await startMockBff(); // puerto efímero (port: 0 por defecto)
      addTearDown(() => server.close(force: true));

      final secure = MemorySecure();
      final prefs = MemoryPrefs();
      final container = createPreviewContainer(
        apiBaseUrl: 'http://127.0.0.1:${server.port}/mobile/v1',
        secure: secure,
        preferences: prefs,
      );
      addTearDown(container.dispose);

      expect(container.read(sessionControllerProvider), isA<SessionUnknown>());

      final configRefreshed = Completer<void>();
      final sub = container.listen(remoteConfigProvider, (_, next) {
        if (next.source == RemoteConfigSource.network &&
            !configRefreshed.isCompleted) {
          configRefreshed.complete();
        }
      });
      addTearDown(sub.close);

      await bootstrapPreviewContainer(container);

      // En SessionState el estado no autenticado es SessionAnonymous.
      expect(
        container.read(sessionControllerProvider),
        isA<SessionAnonymous>(),
      );

      await configRefreshed.future;
      expect(
        container.read(remoteConfigProvider).source,
        RemoteConfigSource.network,
      );
    });
  });
}
