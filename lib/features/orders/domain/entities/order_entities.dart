import 'package:ipr_mobile/shared/domain/image_ref.dart';
import 'package:ipr_mobile/shared/domain/money.dart';
import 'package:meta/meta.dart';

/// Estado de pago del pedido (`openapi.yaml` → `PaymentState`, CR-007).
///
/// Valores desconocidos se mapean a [unknown] (tolerante a ampliaciones del
/// contrato; nunca se interpreta como pagado).
enum OrderPaymentState {
  paid,
  pending,
  failed,
  cancelled,
  refunded,
  unknown;

  static OrderPaymentState fromContract(Object? raw) => switch (raw) {
    'paid' => paid,
    'pending' => pending,
    'failed' => failed,
    'cancelled' => cancelled,
    'refunded' => refunded,
    _ => unknown,
  };
}

/// Resumen de un pedido en el historial (`GET /orders`, RF-107).
@immutable
final class OrderSummary {
  const new({
    required this.id,
    required this.number,
    required this.status,
    required this.statusLabel,
    required this.paymentState,
    required this.createdAt,
    required this.currency,
    required this.total,
    required this.itemCount,
  });

  final int id;
  final String number;
  final String status;
  final String statusLabel;
  final OrderPaymentState paymentState;
  final DateTime? createdAt;
  final String currency;
  final Money total;
  final int itemCount;
}

/// Página del historial de pedidos (`PageMeta` + lista).
@immutable
final class OrderPage {
  const new({
    required this.items,
    required this.page,
    required this.perPage,
    required this.total,
    required this.totalPages,
    required this.hasMore,
  });

  final List<OrderSummary> items;
  final int page;
  final int perPage;
  final int total;
  final int totalPages;
  final bool hasMore;
}

/// Línea de producto dentro del detalle de un pedido (`OrderDetail.items`).
@immutable
final class OrderItem {
  const new({
    required this.productId,
    required this.name,
    required this.sku,
    required this.quantity,
    required this.total,
    required this.image,
  });

  final int? productId;
  final String name;
  final String? sku;
  final int quantity;
  final Money total;
  final ImageRef? image;
}

/// Detalle de un pedido (`GET /orders/{orderId}`, RF-108).
///
/// Los importes se muestran tal como los entrega el servidor (AC-107-8,
/// AC-108-4): la app nunca los recalcula ni inventa ceros. Nunca incluye
/// seguimiento ni dirección (RF-109 es fase 2).
@immutable
final class OrderDetail {
  const new({
    required this.summary,
    required this.subtotal,
    required this.shippingTotal,
    required this.discountTotal,
    required this.taxTotal,
    required this.paymentMethodTitle,
    required this.items,
  });

  final OrderSummary summary;
  final Money subtotal;
  final Money? shippingTotal;
  final Money? discountTotal;
  final Money? taxTotal;
  final String paymentMethodTitle;
  final List<OrderItem> items;
}
