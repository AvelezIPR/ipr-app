import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/core/providers.dart';
import 'package:ipr_mobile/core/storage/durable_store.dart';
// Solo en pruebas: el doble de la revalidación del carrito.
import 'package:ipr_mobile/features/cart/cart.dart';
import 'package:ipr_mobile/features/cart/cart_providers.dart';
import 'package:ipr_mobile/features/cart/domain/entities/cart.dart';
import 'package:ipr_mobile/features/cart/domain/repositories/cart_repositories.dart';
import 'package:ipr_mobile/features/checkout/checkout_providers.dart';
import 'package:ipr_mobile/shared/domain/money.dart';
import 'package:ipr_mobile/shared/domain/price_status.dart';
import 'package:ipr_mobile/shared/domain/product_summary.dart';
import 'package:ipr_mobile/shared/domain/stock_status.dart';

ProductSummary _product(int id, {StockStatus stock = StockStatus.inStock}) =>
    ProductSummary(
      id: id,
      slug: 'producto-$id',
      name: 'Producto $id',
      sku: 'SKU-$id',
      price: const Priced(Money(100000)),
      availability: stock,
    );

ValidatedCartLine _line(
  int id,
  int quantity, {
  CartLineStatus status = CartLineStatus.available,
  StockStatus stock = StockStatus.inStock,
}) => ValidatedCartLine(
  id: id,
  quantity: quantity,
  status: status,
  product: _product(id, stock: stock),
  lineSubtotal: Money(100000 * quantity),
);

final class _FakeValidation implements CartValidationRepository {
  new(this.result);

  Result<CartValidation> result;
  int calls = 0;

  @override
  Future<Result<CartValidation>> validate(
    Cart cart, {
    RequestCancellation? cancellation,
  }) async {
    calls++;
    return result;
  }
}

Future<(ProviderContainer, _FakeValidation)> _container(
  Result<CartValidation> result,
) async {
  final validation = _FakeValidation(result);
  final container = ProviderContainer(
    overrides: [
      durableStoreProvider.overrideWithValue(MemoryDurableStore()),
      cartValidationRepositoryProvider.overrideWithValue(validation),
    ],
  );
  addTearDown(container.dispose);
  final cart = container.read(cartProvider.notifier);
  await cart.addLine(1201, 2, snapshot: _product(1201));
  await cart.addLine(988, 1);
  return (container, validation);
}

void main() {
  group('M3 · RF-052 · RF-057 · adaptador con la feature cart', () {
    test(
      'las líneas salen del carrito (nombre solo si hay instantánea)',
      () async {
        final (container, _) = await _container(
          const Ok(
            CartValidation(
              checkoutAllowed: true,
              lines: [],
              informativeSubtotal: Money.zero,
            ),
          ),
        );
        final lines = container.read(checkoutLinesProvider);
        expect(lines.map((l) => (l.productId, l.quantity)), [
          (1201, 2),
          (988, 1),
        ]);
        expect(lines[0].name, 'Producto 1201');
        expect(lines[1].name, isNull);
      },
    );

    test('el resumen se actualiza cuando cambia el carrito', () async {
      final (container, _) = await _container(
        const Ok(
          CartValidation(
            checkoutAllowed: true,
            lines: [],
            informativeSubtotal: Money.zero,
          ),
        ),
      );
      container.listen(checkoutLinesProvider, (_, _) {});
      await container.read(cartProvider.notifier).setQuantity(988, 4);
      expect(container.read(checkoutLinesProvider).last.quantity, 4);
    });

    test('revalidación limpia: se puede pagar sin revisar nada', () async {
      final (container, validation) = await _container(
        Ok(
          CartValidation(
            checkoutAllowed: true,
            lines: [_line(1201, 2), _line(988, 1)],
            informativeSubtotal: const Money(300000),
          ),
        ),
      );
      final review = (await container.read(checkoutCartProvider).revalidate())
          .valueOrNull!;
      expect(review.checkoutAllowed, isTrue);
      expect(review.hasUnavailable, isFalse);
      expect(review.needsAttention, isFalse);
      expect(validation.calls, 1);
    });

    test('un producto agotado bloquea aunque el servidor dijera sí', () async {
      final (container, _) = await _container(
        Ok(
          CartValidation(
            checkoutAllowed: true,
            lines: [
              _line(1201, 2),
              _line(
                988,
                1,
                status: CartLineStatus.outOfStock,
                stock: StockStatus.outOfStock,
              ),
            ],
            informativeSubtotal: const Money(200000),
          ),
        ),
      );
      final review = (await container.read(checkoutCartProvider).revalidate())
          .valueOrNull!;
      expect(review.checkoutAllowed, isFalse);
      expect(review.hasUnavailable, isTrue);
    });

    test('si el servidor no permite pagar, no se paga', () async {
      final (container, _) = await _container(
        Ok(
          CartValidation(
            checkoutAllowed: false,
            lines: [_line(1201, 2), _line(988, 1)],
            informativeSubtotal: const Money(300000),
          ),
        ),
      );
      final review = (await container.read(checkoutCartProvider).revalidate())
          .valueOrNull!;
      expect(review.checkoutAllowed, isFalse);
    });

    test('un fallo de red llega como fallo y no toca las líneas', () async {
      final (container, _) = await _container(const Err(NoConnection()));
      final result = await container.read(checkoutCartProvider).revalidate();
      expect(result.failureOrNull, isA<NoConnection>());
      expect(container.read(checkoutLinesProvider), hasLength(2));
    });

    test('clear vacía el carrito', () async {
      final (container, _) = await _container(const Err(NoConnection()));
      await container.read(checkoutCartProvider).clear();
      expect(container.read(cartProvider).isEmpty, isTrue);
    });
  });
}
