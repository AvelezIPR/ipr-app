import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/providers.dart';
import 'package:ipr_mobile/core/storage/durable_store.dart';
import 'package:ipr_mobile/features/cart/data/mappers/cart_storage_codec.dart';
import 'package:ipr_mobile/features/cart/data/repositories/api_cart_validation_repository.dart';
import 'package:ipr_mobile/features/cart/data/repositories/durable_cart_repository.dart';
import 'package:ipr_mobile/features/cart/domain/rules/checkout_gate.dart';
import 'package:ipr_mobile/shared/domain/money.dart';
import 'package:ipr_mobile/shared/domain/price_status.dart';

import '../../../mocks/fake_http_adapter.dart';
import '../../../mocks/test_clients.dart';
import 'cart_test_support.dart';

/// Controlador + repositorios reales (`cart_providers.dart`) sobre un BFF
/// simulado: el cableado de producción de punta a punta.
void main() {
  group('cableado de producción (repositorios reales)', () {
    test(
      'los providers de la feature construyen los repositorios concretos',
      () {
        final adapter = FakeHttpAdapter();
        final container = ProviderContainer(
          overrides: cartOverrides(
            extra: [
              apiClientProvider.overrideWithValue(
                buildTestClient(adapter: adapter).client,
              ),
            ],
          ),
        );
        addTearDown(container.dispose);
        expect(
          container.read(cartLocalRepositoryProvider),
          isA<DurableCartRepository>(),
        );
        expect(
          container.read(cartValidationRepositoryProvider),
          isA<ApiCartValidationRepository>(),
        );
      },
    );

    test('TC-042 · AC-029-8 · se guarda id y cantidad; el precio mostrado es el del servidor', () async {
      final adapter = FakeHttpAdapter([
        (_) => FakeHttpAdapter.json(
          cartFixtureBody('CartValidation.price-changed.json'),
        ),
      ]);
      final store = MemoryDurableStore();
      final container = ProviderContainer(
        overrides: cartOverrides(
          durable: store,
          extra: [
            apiClientProvider.overrideWithValue(
              buildTestClient(adapter: adapter).client,
            ),
          ],
        ),
      );
      addTearDown(container.dispose);
      final cart = await loadedCart(container);

      // El usuario vio 100.000 en la ficha.
      await cart.add(4521, 1, snapshot: productOf());
      final stored = store.data[CartStorageCodec.storageKey]!;
      expect(stored, contains('"productId":4521'));
      expect(stored, contains('"quantity":1'));

      // El servidor dice 110.000: eso es lo que se muestra.
      await cart.revalidate();
      final view = container.read(cartOverviewProvider).lines.single;
      expect(view.unitPrice, const Priced(Money(110000)));
      expect(
        container.read(cartOverviewProvider).subtotal.amount,
        const Money(110000),
      );
      // La petición llevó solo id y cantidad.
      expect(adapter.requests.single.data, {
        'items': [
          {'id': 4521, 'quantity': 1},
        ],
      });
    });

    test(
      'TC-049 · 503 del BFF: las líneas quedan intactas y el pago, bloqueado',
      () async {
        final adapter = FakeHttpAdapter([
          (_) => FakeHttpAdapter.problem(503, 'service_unavailable'),
        ]);
        final store = MemoryDurableStore();
        final container = ProviderContainer(
          overrides: cartOverrides(
            durable: store,
            extra: [
              apiClientProvider.overrideWithValue(
                buildTestClient(adapter: adapter).client,
              ),
            ],
          ),
        );
        addTearDown(container.dispose);
        final cart = await loadedCart(container);
        await cart.add(4521, 3);
        await cart.revalidate();
        final state = container.read(cartProvider);
        expect(state.validationFailure, isA<ServiceUnavailable>());
        expect(state.lines.single.quantity, 3);
        expect(container.read(cartReadinessProvider), CartReadiness.unverified);
        expect(
          CartStorageCodec.decode(store.data[CartStorageCodec.storageKey])
              .lines
              .single
              .quantity,
          3,
        );
      },
    );
  });
}
