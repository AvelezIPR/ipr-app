import 'package:ipr_mobile/core/network/uuid_v4.dart';
import 'package:ipr_mobile/features/checkout/data/dtos/checkout_dtos.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/checkout_line.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/checkout_status.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/checkout_ticket.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/payment_state.dart';

/// Cuerpo de la petición: SOLO `{id, quantity}` por línea (el nombre de
/// presentación nunca viaja).
CheckoutRequestDto checkoutRequestOf(List<CheckoutLine> lines) =>
    CheckoutRequestDto(
      items: [
        for (final line in lines)
          CheckoutItemDto(id: line.productId, quantity: line.quantity),
      ],
    );

/// Convierte la respuesta en entidad. Lanza [FormatException] (sin volcar la
/// URL ni el ticket) si `checkoutRef` no es un UUID v4 o la URL no es
/// absoluta. La política de hosts la aplica el controlador.
CheckoutTicket mapCheckoutTicket(CheckoutSessionDto dto) {
  final ref = dto.checkoutRef.toLowerCase();
  if (!isUuidV4(ref)) throw const FormatException('checkoutRef inválido');
  final url = Uri.tryParse(dto.checkoutUrl);
  if (url == null || !url.isAbsolute || url.host.isEmpty) {
    throw const FormatException('checkoutUrl inválida');
  }
  return CheckoutTicket(
    checkoutRef: ref,
    checkoutUrl: url,
    allowedHosts: {for (final host in dto.allowedHosts) host.toLowerCase()},
    expiresAt: dto.expiresAt,
  );
}

/// Estado del intento. Tolerante: un `state` desconocido, o `order_created`
/// sin pedido utilizable, equivale a "aún sin pedido" (nunca a pagado).
CheckoutStatus mapCheckoutStatus(CheckoutStatusDto dto) {
  final ref = dto.checkoutRef.toLowerCase();
  if (!isUuidV4(ref)) throw const FormatException('checkoutRef inválido');
  final order = dto.order;
  if (dto.state != 'order_created' || order == null) {
    return CheckoutStatus(checkoutRef: ref);
  }
  return CheckoutStatus(
    checkoutRef: ref,
    order: VerifiedOrder(
      id: order.id,
      number: order.number,
      statusLabel: order.statusLabel,
      paymentState: PaymentState.fromContract(order.paymentState),
    ),
  );
}
