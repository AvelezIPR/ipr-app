import 'package:ipr_mobile/features/checkout/domain/entities/payment_state.dart';
import 'package:meta/meta.dart';

/// Pedido tal como lo informa el servidor (`OrderSummary`): solo lo que se
/// muestra en el resultado. Sin dirección, correo ni datos de pago.
@immutable
final class VerifiedOrder {
  const new({
    required this.id,
    required this.number,
    required this.statusLabel,
    required this.paymentState,
  });

  final int id;

  /// Número visible del pedido (cadena: puede no ser numérico).
  final String number;

  /// Etiqueta del estado que entrega el servidor (AC-056-8); puede estar
  /// vacía.
  final String statusLabel;
  final PaymentState paymentState;

  @override
  bool operator ==(Object other) =>
      other is VerifiedOrder &&
      other.id == id &&
      other.number == number &&
      other.statusLabel == statusLabel &&
      other.paymentState == paymentState;

  @override
  int get hashCode => Object.hash(id, number, statusLabel, paymentState);

  @override
  String toString() => 'VerifiedOrder($number, ${paymentState.name})';
}

/// `CheckoutStatus` (`GET /checkout/{checkoutRef}`): la fuente de verdad del
/// resultado. [order] nulo = `awaiting_order` (aún no hay pedido).
@immutable
final class CheckoutStatus {
  const new({required this.checkoutRef, this.order});

  final String checkoutRef;
  final VerifiedOrder? order;

  bool get awaitingOrder => order == null;

  @override
  bool operator ==(Object other) =>
      other is CheckoutStatus &&
      other.checkoutRef == checkoutRef &&
      other.order == order;

  @override
  int get hashCode => Object.hash(checkoutRef, order);

  @override
  String toString() => 'CheckoutStatus($checkoutRef, order: $order)';
}
