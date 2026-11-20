import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/orders/data/datasources/orders_remote_datasource.dart';
import 'package:ipr_mobile/features/orders/domain/entities/order_entities.dart';
import 'package:ipr_mobile/features/orders/domain/repositories/orders_repository.dart';

/// Implementación sobre `/mobile/v1`. Nunca persiste pedidos en disco
/// (`Cache-Control: private, no-store`, RNF-062).
final class ApiOrdersRepository implements OrdersRepository {
  const new(this._remote);

  final OrdersRemoteDataSource _remote;

  @override
  Future<Result<OrderPage>> listOrders({
    int page = 1,
    int perPage = OrdersRepository.defaultPerPage,
    RequestCancellation? cancellation,
  }) => _remote.listOrders(
    page: page,
    perPage: perPage,
    cancellation: cancellation,
  );

  @override
  Future<Result<OrderDetail>> getOrder(
    int orderId, {
    RequestCancellation? cancellation,
  }) => _remote.getOrder(orderId, cancellation: cancellation);
}
