/// DTOs tolerantes de `GET /orders` y `GET /orders/{orderId}`.
///
/// Solo lectura por lista blanca; `toString` no imprime datos del pedido.
final class OrderSummaryDto {
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

  factory fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('OrderSummary no es un objeto');
    }
    final id = json['id'];
    final number = json['number'];
    if (id is! int || id < 1 || number is! String || number.isEmpty) {
      throw const FormatException('id o number de pedido inválido');
    }
    final status = json['status'];
    final statusLabel = json['statusLabel'];
    final currency = json['currency'];
    final itemCount = json['itemCount'];
    return OrderSummaryDto(
      id: id,
      number: number,
      status: status is String ? status : '',
      statusLabel: statusLabel is String ? statusLabel : '',
      paymentState: json['paymentState'],
      createdAt: json['createdAt'],
      currency: currency is String && currency.isNotEmpty ? currency : 'COP',
      total: json['total'],
      itemCount: itemCount is int && itemCount >= 0 ? itemCount : 0,
    );
  }

  final int id;
  final String number;
  final String status;
  final String statusLabel;
  final Object? paymentState;
  final Object? createdAt;
  final String currency;
  final Object? total;
  final int itemCount;

  @override
  String toString() => 'OrderSummaryDto(id: $id)';
}

final class OrderPageDto {
  const new({
    required this.items,
    required this.page,
    required this.perPage,
    required this.total,
    required this.totalPages,
    required this.hasMore,
  });

  factory fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('respuesta de /orders no es un objeto');
    }
    final data = json['data'];
    final meta = json['meta'];
    if (data is! List || meta is! Map<String, dynamic>) {
      throw const FormatException('falta data o meta en /orders');
    }
    final page = meta['page'];
    final perPage = meta['perPage'];
    final total = meta['total'];
    final totalPages = meta['totalPages'];
    final hasMore = meta['hasMore'];
    return OrderPageDto(
      items: [for (final raw in data) OrderSummaryDto.fromJson(raw)],
      page: page is int && page >= 1 ? page : 1,
      perPage: perPage is int && perPage >= 1 ? perPage : 10,
      total: total is int && total >= 0 ? total : data.length,
      totalPages: totalPages is int && totalPages >= 0 ? totalPages : 1,
      hasMore: hasMore is bool && hasMore,
    );
  }

  final List<OrderSummaryDto> items;
  final int page;
  final int perPage;
  final int total;
  final int totalPages;
  final bool hasMore;

  @override
  String toString() => 'OrderPageDto(page: $page, count: ${items.length})';
}

final class OrderItemDto {
  const new({
    required this.productId,
    required this.name,
    required this.sku,
    required this.quantity,
    required this.total,
    required this.imageUrl,
  });

  factory fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('OrderItem no es un objeto');
    }
    final name = json['name'];
    final quantity = json['quantity'];
    if (name is! String || name.isEmpty || quantity is! int || quantity < 1) {
      throw const FormatException('línea de pedido inválida');
    }
    final productId = json['productId'];
    final sku = json['sku'];
    final imageUrl = json['imageUrl'];
    return OrderItemDto(
      productId: productId is int ? productId : null,
      name: name,
      sku: sku is String && sku.isNotEmpty ? sku : null,
      quantity: quantity,
      total: json['total'],
      imageUrl: imageUrl is String && imageUrl.isNotEmpty ? imageUrl : null,
    );
  }

  final int? productId;
  final String name;
  final String? sku;
  final int quantity;
  final Object? total;
  final String? imageUrl;

  @override
  String toString() => 'OrderItemDto(qty: $quantity)';
}

final class OrderDetailDto {
  const new({
    required this.summary,
    required this.subtotal,
    required this.shippingTotal,
    required this.discountTotal,
    required this.taxTotal,
    required this.paymentMethodTitle,
    required this.items,
  });

  factory fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('respuesta de /orders/{id} no es un objeto');
    }
    final data = json['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('falta data en /orders/{id}');
    }
    final rawItems = data['items'];
    if (rawItems is! List) {
      throw const FormatException('falta items en OrderDetail');
    }
    final method = data['paymentMethodTitle'];
    return OrderDetailDto(
      summary: OrderSummaryDto.fromJson(data),
      subtotal: data['subtotal'],
      shippingTotal: data['shippingTotal'],
      discountTotal: data['discountTotal'],
      taxTotal: data['taxTotal'],
      paymentMethodTitle: method is String ? method : '',
      items: [for (final raw in rawItems) OrderItemDto.fromJson(raw)],
    );
  }

  final OrderSummaryDto summary;
  final Object? subtotal;
  final Object? shippingTotal;
  final Object? discountTotal;
  final Object? taxTotal;
  final String paymentMethodTitle;
  final List<OrderItemDto> items;

  @override
  String toString() => 'OrderDetailDto(id: ${summary.id})';
}
