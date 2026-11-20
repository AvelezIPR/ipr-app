import 'package:ipr_mobile/core/network/api_client.dart';
import 'package:ipr_mobile/core/network/api_request.dart';
import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/cart/data/mappers/cart_validation_mapper.dart';
import 'package:ipr_mobile/features/cart/domain/entities/cart.dart';
import 'package:ipr_mobile/features/cart/domain/entities/cart_validation.dart';
import 'package:ipr_mobile/features/cart/domain/repositories/cart_repositories.dart';
import 'package:ipr_mobile/shared/domain/money.dart';

/// `POST /cart/validate` (RF-050). Operación sin efectos: no exige sesión (un
/// invitado también revalida), no lleva `Idempotency-Key` y no se reintenta
/// (POST).
///
/// El cuerpo contiene **únicamente** `{items: [{id, quantity}]}`: ni precios,
/// ni totales, ni datos del usuario (IR-01, AC-050-8). Un carrito vacío no
/// genera petición (el contrato exige al menos una línea).
final class ApiCartValidationRepository implements CartValidationRepository {
  const new(this._client);

  final ApiClient _client;

  static const path = '/cart/validate';

  /// Cuerpo de la petición; público para poder probar que no lleva precios.
  static Map<String, Object?> requestBody(Cart cart) => {
    'items': [
      for (final line in cart.lines)
        {'id': line.productId, 'quantity': line.quantity},
    ],
  };

  @override
  Future<Result<CartValidation>> validate(
    Cart cart, {
    RequestCancellation? cancellation,
  }) {
    if (cart.isEmpty) {
      return Future.value(
        const Ok(
          CartValidation(
            checkoutAllowed: false,
            lines: [],
            informativeSubtotal: Money.zero,
          ),
        ),
      );
    }
    return _client.sendDecoded(
      ApiRequest.post(path, body: requestBody(cart)),
      mapCartValidation,
      cancellation: cancellation,
    );
  }
}
