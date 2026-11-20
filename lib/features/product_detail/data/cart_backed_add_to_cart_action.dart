import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/cart/cart.dart';
import 'package:ipr_mobile/features/product_detail/domain/usecases/add_to_cart_action.dart';
import 'package:ipr_mobile/shared/domain/product_summary.dart';

/// Conecta la ficha con el carrito local (M3). `product_detail` puede importar
/// la API pública de `cart` (regla D3).
final class CartBackedAddToCartAction implements AddToCartAction {
  const new(this._ref);

  final Ref _ref;

  @override
  Future<Result<AddToCartOutcome>> add({
    required int productId,
    required int quantity,
    ProductSummary? snapshot,
  }) async {
    final result = await _ref
        .read(cartProvider.notifier)
        .addLine(productId, quantity, snapshot: snapshot);
    return switch (result) {
      CartAdded(:final clamped) => Ok(
        AddToCartOutcome(quantityLimited: clamped),
      ),
      CartAddRejected(:final reason) => Err(
        Validation(code: cartRejectionCode(reason)),
      ),
    };
  }
}
