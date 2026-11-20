import 'package:ipr_mobile/features/orders/data/dtos/orders_dtos.dart';
import 'package:ipr_mobile/features/orders/domain/entities/order_entities.dart';
import 'package:ipr_mobile/shared/domain/image_ref.dart';
import 'package:ipr_mobile/shared/domain/money.dart';
import 'package:ipr_mobile/shared/formatting/date_format.dart';

OrderSummary mapOrderSummary(OrderSummaryDto dto) {
  final total = Money.tryFromJson(dto.total);
  if (total == null) {
    throw const FormatException('total de pedido inválido');
  }
  return OrderSummary(
    id: dto.id,
    number: dto.number,
    status: dto.status,
    statusLabel: dto.statusLabel,
    paymentState: OrderPaymentState.fromContract(dto.paymentState),
    createdAt: tryParseServerDate(dto.createdAt),
    currency: dto.currency,
    total: total,
    itemCount: dto.itemCount,
  );
}

OrderPage mapOrderPage(OrderPageDto dto) => OrderPage(
  items: [for (final item in dto.items) mapOrderSummary(item)],
  page: dto.page,
  perPage: dto.perPage,
  total: dto.total,
  totalPages: dto.totalPages,
  hasMore: dto.hasMore,
);

OrderItem mapOrderItem(OrderItemDto dto) {
  final total = Money.tryFromJson(dto.total);
  if (total == null) {
    throw const FormatException('total de línea inválido');
  }
  final imageUrl = dto.imageUrl;
  return OrderItem(
    productId: dto.productId,
    name: dto.name,
    sku: dto.sku,
    quantity: dto.quantity,
    total: total,
    image: (dto.productId != null && imageUrl != null)
        ? ImageRef(url: imageUrl, alt: dto.name)
        : null,
  );
}

OrderDetail mapOrderDetail(OrderDetailDto dto) {
  final subtotal = Money.tryFromJson(dto.subtotal);
  if (subtotal == null) {
    throw const FormatException('subtotal de pedido inválido');
  }
  return OrderDetail(
    summary: mapOrderSummary(dto.summary),
    subtotal: subtotal,
    shippingTotal: Money.tryFromJson(dto.shippingTotal),
    discountTotal: Money.tryFromJson(dto.discountTotal),
    taxTotal: Money.tryFromJson(dto.taxTotal),
    paymentMethodTitle: dto.paymentMethodTitle.trim(),
    items: [for (final item in dto.items) mapOrderItem(item)],
  );
}
