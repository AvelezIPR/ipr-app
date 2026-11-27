import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/shared/domain/product_summary.dart';

/// Resultado de añadir al carrito.
final class AddToCartOutcome {
  const new({this.quantityLimited = false, this.maxQuantity = 99});

  /// La cantidad pedida (o la suma con lo que ya había) superó el máximo por
  /// producto y se acotó; la ficha lo informa (AC-029-5).
  final bool quantityLimited;

  /// Máximo por línea que se aplicó: el del producto o 99 (W1-06).
  final int maxQuantity;
}

/// Costura hacia el carrito. La ficha **no** conoce el carrito: pide añadir un
/// producto y una cantidad a través de esta interfaz. La implementación real
/// vive en `data/cart_backed_add_to_cart_action.dart`; en las pruebas de la
/// ficha se sustituye por un doble.
abstract interface class AddToCartAction {
  /// Añade [quantity] unidades del producto [productId]. [snapshot] es el
  /// producto tal como lo vio el usuario, para pintar la línea sin red.
  /// `Ok` si quedó en el carrito; `Err` con el motivo si no.
  Future<Result<AddToCartOutcome>> add({
    required int productId,
    required int quantity,
    ProductSummary? snapshot,
  });
}
