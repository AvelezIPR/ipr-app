import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/checkout_line.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/checkout_status.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/checkout_ticket.dart';

/// Acceso al BFF para pagar (`POST /checkout` y `GET /checkout/{ref}`).
abstract interface class CheckoutRepository {
  /// Pide el ticket. Solo se envían `{id, quantity}` de cada línea, con la
  /// [idempotencyKey] del intento. **Nunca** se reintenta por sí solo.
  Future<Result<CheckoutTicket>> createCheckout({
    required List<CheckoutLine> lines,
    required String idempotencyKey,
    RequestCancellation? cancellation,
  });

  /// Estado verificado del intento: la única fuente de verdad del resultado.
  Future<Result<CheckoutStatus>> status(
    String checkoutRef, {
    RequestCancellation? cancellation,
  });
}
