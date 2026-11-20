import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/app/providers.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/core/providers.dart';
import 'package:ipr_mobile/features/cart/cart.dart';
import 'package:ipr_mobile/features/product_detail/domain/usecases/add_to_cart_action.dart';
import 'package:ipr_mobile/features/product_detail/presentation/controllers/add_to_cart_provider.dart';

import '../../mocks/test_providers.dart';

ProviderContainer _container() {
  final c = ProviderContainer(
    overrides: testOverrides(extra: integrationOverrides()),
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('M3 · integración de la app con el carrito', () {
    test('la ficha añade al carrito real y avisa si se acotó a 99', () async {
      final c = _container();
      final action = c.read(addToCartActionProvider)!;

      final first = await action.add(productId: 7, quantity: 60);
      expect((first as Ok<AddToCartOutcome>).value.quantityLimited, isFalse);
      final second = await action.add(productId: 7, quantity: 60);
      expect((second as Ok<AddToCartOutcome>).value.quantityLimited, isTrue);

      final lines = c.read(cartProvider).lines;
      expect(lines, hasLength(1));
      expect(lines.single.quantity, 99);
    });

    test(
      'un rechazo del carrito llega como Validation con código cart_*',
      () async {
        final c = _container();
        final action = c.read(addToCartActionProvider)!;
        final result = await action.add(productId: 0, quantity: 1);
        final failure = (result as Err).failure;
        expect(failure, isA<Validation>());
        expect((failure as Validation).code, startsWith('cart_'));
      },
    );

    test(
      'H-07: cerrar sesión conserva el carrito; eliminar la cuenta lo borra',
      () async {
        final c = _container();
        await c.read(cartProvider.notifier).add(5, 2);
        final hooks = c.read(sessionHooksProvider);
        expect(hooks, hasLength(2));

        for (final hook in hooks) {
          await hook.onLogout();
        }
        expect(c.read(cartProvider).lines, hasLength(1));

        for (final hook in hooks) {
          await hook.onAccountDeleted();
        }
        expect(c.read(cartProvider).lines, isEmpty);
      },
    );

    test('la insignia cuenta unidades, no líneas', () async {
      final c = _container();
      await c.read(cartProvider.notifier).add(1, 3);
      await c.read(cartProvider.notifier).add(2, 4);
      expect(c.read(cartUnitCountProvider), 7);
    });
  });
}
