/// Cuerpo de `POST /checkout` (`CartItemsRequest`): SOLO `items[{id,
/// quantity}]`. Ni precios, ni totales, ni `customer_id`, ni `role`, ni URL de
/// retorno (SC-020, AC-052-2).
final class CheckoutRequestDto {
  const new({required this.items});

  final List<CheckoutItemDto> items;

  Map<String, Object?> toJson() => {
    'items': [for (final item in items) item.toJson()],
  };

  @override
  String toString() => 'CheckoutRequestDto(${items.length} líneas)';
}

final class CheckoutItemDto {
  const new({required this.id, required this.quantity});

  final int id;
  final int quantity;

  Map<String, Object?> toJson() => {'id': id, 'quantity': quantity};
}

/// `CheckoutSession` (`data` de la respuesta 201).
///
/// [checkoutUrl] lleva el ticket: se conserva como cadena SOLO hasta que el
/// mapeador la convierte en `Uri`, y `toString` nunca la imprime. Lanza
/// [FormatException] sin volcar valores si falta algo imprescindible;
/// `ApiClient` lo convierte en `ContractFailure`.
final class CheckoutSessionDto {
  const new({
    required this.checkoutRef,
    required this.checkoutUrl,
    required this.allowedHosts,
    this.expiresAt,
  });

  factory fromJson(Object? json) {
    final data = _data(json);
    final ref = data['checkoutRef'];
    final url = data['checkoutUrl'];
    if (ref is! String || ref.isEmpty) {
      throw const FormatException('falta checkoutRef');
    }
    if (url is! String || url.isEmpty) {
      throw const FormatException('falta checkoutUrl');
    }
    final hosts = data['allowedHosts'];
    return CheckoutSessionDto(
      checkoutRef: ref,
      checkoutUrl: url,
      allowedHosts: hosts is List
          ? [
              for (final host in hosts)
                if (host is String && host.isNotEmpty) host,
            ]
          : const [],
      expiresAt: _dateTime(data['expiresAt']),
    );
  }

  final String checkoutRef;
  final String checkoutUrl;
  final List<String> allowedHosts;
  final DateTime? expiresAt;

  @override
  String toString() => 'CheckoutSessionDto(<oculto>)';
}

/// `OrderSummary` (solo lo que muestra el resultado).
final class OrderSummaryDto {
  const new({
    required this.id,
    required this.number,
    required this.statusLabel,
    required this.paymentState,
  });

  /// `null` si el objeto no sirve para verificar nada (sin número o id).
  static OrderSummaryDto? tryFromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final id = json['id'];
    final number = json['number'];
    if (id is! int || number is! String || number.isEmpty) return null;
    final label = json['statusLabel'];
    return OrderSummaryDto(
      id: id,
      number: number,
      statusLabel: label is String ? label : '',
      paymentState: json['paymentState'],
    );
  }

  final int id;
  final String number;
  final String statusLabel;

  /// Valor crudo; el mapeador lo interpreta de forma tolerante.
  final Object? paymentState;
}

/// `CheckoutStatus` (`data` de `GET /checkout/{ref}`).
final class CheckoutStatusDto {
  const new({
    required this.checkoutRef,
    required this.state,
    required this.order,
  });

  factory fromJson(Object? json) {
    final data = _data(json);
    final ref = data['checkoutRef'];
    if (ref is! String || ref.isEmpty) {
      throw const FormatException('falta checkoutRef');
    }
    final state = data['state'];
    return CheckoutStatusDto(
      checkoutRef: ref,
      state: state is String ? state : '',
      order: OrderSummaryDto.tryFromJson(data['order']),
    );
  }

  final String checkoutRef;
  final String state;
  final OrderSummaryDto? order;
}

Map<String, dynamic> _data(Object? json) {
  if (json is! Map<String, dynamic>) {
    throw const FormatException('respuesta no es un objeto');
  }
  final data = json['data'];
  if (data is! Map<String, dynamic>) throw const FormatException('falta data');
  return data;
}

DateTime? _dateTime(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
