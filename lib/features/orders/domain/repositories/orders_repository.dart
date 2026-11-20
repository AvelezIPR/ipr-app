import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/orders/domain/entities/order_entities.dart';

/// Acceso de solo lectura a los pedidos del usuario autenticado
/// (`GET /orders` y `GET /orders/{orderId}`).
///
/// Solo en memoria (`Cache-Control: private, no-store`, RNF-062): nunca se
/// guarda en caché de disco.
abstract interface class OrdersRepository {
  static const int defaultPerPage = 10;
  static const int maxPage = 100;

  Future<Result<OrderPage>> listOrders({
    int page = 1,
    int perPage = defaultPerPage,
    RequestCancellation? cancellation,
  });

  Future<Result<OrderDetail>> getOrder(
    int orderId, {
    RequestCancellation? cancellation,
  });
}
