import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/config/remote_config_controller.dart';
import 'package:ipr_mobile/core/network/uuid_v4.dart';
import 'package:ipr_mobile/core/providers.dart';
import 'package:ipr_mobile/core/session/session_state.dart';
import 'package:ipr_mobile/core/storage/cache_store.dart';
import 'package:ipr_mobile/features/checkout/checkout_providers.dart';
import 'package:ipr_mobile/features/checkout/data/datasources/checkout_remote_datasource.dart';
import 'package:ipr_mobile/features/checkout/data/repositories/api_checkout_repository.dart';
import 'package:ipr_mobile/features/checkout/data/repositories/cache_pending_checkout_store.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/payment_state.dart';
import 'package:ipr_mobile/features/checkout/domain/rules/checkout_flow.dart';
import 'package:ipr_mobile/features/checkout/presentation/controllers/checkout_controller.dart';

import '../../../../mocks/fake_http_adapter.dart';
import '../../../../mocks/test_clients.dart';
import '../support/checkout_fakes.dart';

Object _fixture(String name) =>
    jsonDecode(File('test/fixtures/checkout/$name').readAsStringSync())
        as Object;

void main() {
  group('M3 · cableado por defecto de la feature', () {
    test('repositorio, registro, reloj, espera e identificadores', () async {
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(testConfig),
          apiClientProvider.overrideWithValue(
            buildTestClient(adapter: FakeHttpAdapter()).client,
          ),
          cacheStoreProvider.overrideWithValue(MemoryCacheStore()),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(checkoutRepositoryProvider),
        isA<ApiCheckoutRepository>(),
      );
      expect(
        container.read(pendingCheckoutStoreProvider),
        isA<CachePendingCheckoutStore>(),
      );
      expect(isUuidV4(container.read(checkoutUuidProvider)()), isTrue);
      expect(
        container.read(checkoutNowProvider)().difference(DateTime.now()).abs(),
        lessThan(const Duration(seconds: 5)),
      );
      await container.read(checkoutSleepProvider)(Duration.zero);
      expect(
        container.read(checkoutControllerProvider).phase,
        CheckoutPhase.idle,
      );
    });
  });

  group(
    'TC-067 · AC-052-2 · flujo completo con la pila HTTP real (sin red)',
    () {
      test(
        'POST con solo {id, quantity} y clave; luego GET verificado',
        () async {
          final adapter = FakeHttpAdapter([
            (_) => FakeHttpAdapter.json(
              _fixture('CheckoutSession.valid.json'),
              status: 201,
            ),
            (_) => FakeHttpAdapter.json(
              _fixture('CheckoutStatus.paid.valid.json'),
            ),
          ]);
          final client = buildTestClient(adapter: adapter).client;
          final cart = FakeCheckoutCart();
          final browser = FakeSecureBrowser();
          final container = ProviderContainer(
            overrides: checkoutTestOverrides(
              cart: cart,
              repo: ApiCheckoutRepository(CheckoutRemoteDataSource(client)),
              browser: browser,
              cache: MemoryCacheStore(),
              clock: ManualClock(),
              uuids: SequentialUuids(),
              session: FakeSessionController(
                const SessionAuthenticated(userId: 4821),
              ),
              remoteConfig: FakeRemoteConfigController(checkoutOn),
            ),
          );
          addTearDown(container.dispose);

          final controller = container.read(
            checkoutControllerProvider.notifier,
          );
          await controller.pay();

          final post = adapter.requests.first;
          expect(post.method, 'POST');
          expect(post.path, '/checkout');
          expect(
            jsonEncode(post.data),
            jsonEncode(_fixture('CartItemsRequest.valid.json')),
          );
          expect(isUuidV4(post.headers['Idempotency-Key'] as String), isTrue);
          expect(browser.opened.single.host, 'staging.invalid');
          expect(
            browser.opened.single.queryParameters['ipr_ticket'],
            hasLength(32),
          );

          await controller.verifyNow();
          final get = adapter.requests.last;
          expect(get.method, 'GET');
          expect(get.path, '/checkout/$refA');
          final state = container.read(checkoutControllerProvider);
          expect(state.phase, CheckoutPhase.paid);
          expect(state.order?.paymentState, PaymentState.paid);
          expect(cart.clearCalls, 1);
        },
      );
    },
  );
}
