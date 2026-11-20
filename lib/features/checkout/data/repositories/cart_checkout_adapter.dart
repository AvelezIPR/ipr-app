import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/cart/cart.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/cart_review.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/checkout_line.dart';
import 'package:ipr_mobile/features/checkout/domain/repositories/checkout_cart.dart';

/// Adaptador entre el checkout y la feature `cart` (regla D3: solo importa su
/// API pública `cart.dart`).
///
/// * [lines]: líneas locales; el nombre sale de la instantánea visual del
///   carrito y es solo de presentación (nunca se envía).
/// * [revalidate]: `CartController.revalidate()` (solo viajan `{id, quantity}`).
///   El pago solo se permite si el servidor lo permite **y** ninguna línea es
///   bloqueante (defensa en profundidad). "Cambios" son los avisos de precio
///   o disponibilidad que el usuario aún no aceptó en el carrito.
/// * [clear]: `CartController.clear()`, que el checkout solo llama tras un
///   pedido verificado como pagado.
final class CartCheckoutAdapter implements CheckoutCart {
  const new(this._ref);

  final Ref _ref;

  @override
  List<CheckoutLine> get lines => [
    for (final line in _ref.read(cartProvider).lines)
      CheckoutLine(
        productId: line.productId,
        quantity: line.quantity,
        name: line.snapshot?.name,
      ),
  ];

  @override
  Future<Result<CartReview>> revalidate() async {
    final result = await _ref.read(cartProvider.notifier).revalidate();
    return result.map((validation) {
      final blocking = validation.lines.any((line) => line.isBlocking);
      return CartReview(
        checkoutAllowed: validation.checkoutAllowed && !blocking,
        hasChanges: _ref.read(cartProvider).changes.isNotEmpty,
        hasUnavailable: blocking,
      );
    });
  }

  @override
  Future<void> clear() => _ref.read(cartProvider.notifier).clear();
}
