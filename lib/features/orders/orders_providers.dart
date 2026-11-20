import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ipr_mobile/core/providers.dart';
import 'package:ipr_mobile/features/orders/data/datasources/orders_remote_datasource.dart';
import 'package:ipr_mobile/features/orders/data/repositories/api_orders_repository.dart';
import 'package:ipr_mobile/features/orders/domain/repositories/orders_repository.dart';

/// Repositorio de pedidos (D4: en la raíz de la feature para que
/// `presentation/` no importe `data/`).
final ordersRepositoryProvider = Provider<OrdersRepository>(
  (ref) =>
      ApiOrdersRepository(OrdersRemoteDataSource(ref.watch(apiClientProvider))),
);
