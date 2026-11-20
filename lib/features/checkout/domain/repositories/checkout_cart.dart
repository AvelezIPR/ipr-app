import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/cart_review.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/checkout_line.dart';

/// Lo que el checkout necesita del carrito. La feature `cart` se construye en
/// paralelo: se conecta con un adaptador en `data/` y todo se prueba con un
/// doble de esta interfaz.
abstract interface class CheckoutCart {
  /// Líneas actuales (solo lectura).
  List<CheckoutLine> get lines;

  /// Revalida precio y disponibilidad contra el servidor (N-05).
  Future<Result<CartReview>> revalidate();

  /// Vacía el carrito. SOLO se llama tras un pedido verificado como pagado.
  Future<void> clear();
}
