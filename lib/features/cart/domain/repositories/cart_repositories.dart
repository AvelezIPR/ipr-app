import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/cart/domain/entities/cart.dart';
import 'package:ipr_mobile/features/cart/domain/entities/cart_validation.dart';

/// Almacén local del carrito (RF-049): fuente local de verdad hasta el
/// checkout. Sin datos personales.
abstract interface class CartLocalRepository {
  /// Lee el carrito guardado. Datos ausentes, ilegibles o corruptos → carrito
  /// vacío; **nunca** lanza.
  Future<Cart> load();

  /// Guarda el carrito completo (se llama tras cada cambio). Un fallo de
  /// escritura no lanza: el carrito sigue en memoria.
  Future<void> save(Cart cart);

  Future<void> clear();
}

/// Revalidación en el servidor (`POST /cart/validate`, RF-050).
abstract interface class CartValidationRepository {
  /// Envía **solo** `{id, quantity}` por línea; jamás precios (IR-01). Un
  /// fallo de red o de servidor llega como `Err` y no modifica el carrito.
  Future<Result<CartValidation>> validate(
    Cart cart, {
    RequestCancellation? cancellation,
  });
}
