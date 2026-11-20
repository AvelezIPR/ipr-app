import 'package:ipr_mobile/core/network/api_client.dart';
import 'package:ipr_mobile/core/network/api_request.dart';
import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/orders/data/dtos/orders_dtos.dart';
import 'package:ipr_mobile/features/orders/data/mappers/orders_mappers.dart';
import 'package:ipr_mobile/features/orders/domain/entities/order_entities.dart';

/// Fuente remota de `/orders` y `/orders/{orderId}`.
final class OrdersRemoteDataSource {
  const new(this._client);

  final ApiClient _client;

  Future<Result<OrderPage>> listOrders({
    required int page,
    required int perPage,
    RequestCancellation? cancellation,
  }) => _client.sendDecoded(
    ApiRequest.get(
      '/orders',
      query: {'page': page, 'perPage': perPage},
      requiresAuth: true,
    ),
    (json) => mapOrderPage(OrderPageDto.fromJson(json)),
    cancellation: cancellation,
  );

  Future<Result<OrderDetail>> getOrder(
    int orderId, {
    RequestCancellation? cancellation,
  }) => _client.sendDecoded(
    ApiRequest.get('/orders/$orderId', requiresAuth: true),
    (json) => mapOrderDetail(OrderDetailDto.fromJson(json)),
    cancellation: cancellation,
  );
}
