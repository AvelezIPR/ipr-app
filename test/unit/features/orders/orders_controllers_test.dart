import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/orders/domain/entities/order_entities.dart';
import 'package:ipr_mobile/features/orders/domain/repositories/orders_repository.dart';
import 'package:ipr_mobile/features/orders/orders_providers.dart';
import 'package:ipr_mobile/features/orders/presentation/controllers/order_detail_controller.dart';
import 'package:ipr_mobile/features/orders/presentation/controllers/orders_list_controller.dart';
import 'package:ipr_mobile/shared/domain/money.dart';
import 'package:ipr_mobile/shared/widgets/ui_state.dart';

OrderSummary _order(int id) => OrderSummary(
  id: id,
  number: '$id',
  status: 'processing',
  statusLabel: 'En preparación',
  paymentState: OrderPaymentState.paid,
  createdAt: DateTime.utc(2026, 11, 20, 12),
  currency: 'COP',
  total: Money(100000 * id),
  itemCount: 1,
);

OrderDetail _detail(int id) => OrderDetail(
  summary: _order(id),
  subtotal: const Money(100000),
  shippingTotal: const Money(15000),
  discountTotal: null,
  taxTotal: null,
  paymentMethodTitle: 'Wompi',
  items: const [
    OrderItem(
      productId: 10,
      name: 'Válvula QA',
      sku: 'QA-V1',
      quantity: 1,
      total: Money(100000),
      image: null,
    ),
  ],
);

final class _FakeOrdersRepository implements OrdersRepository {
  final List<int> listCalls = [];
  final List<int> detailCalls = [];
  final Map<int, FutureOr<Result<OrderPage>> Function()> listHandlers = {};
  FutureOr<Result<OrderDetail>> Function(int id)? detailHandler;
  bool cancelledOnDispose = false;

  @override
  Future<Result<OrderPage>> listOrders({
    int page = 1,
    int perPage = OrdersRepository.defaultPerPage,
    RequestCancellation? cancellation,
  }) async {
    cancellation?.onCancel(() => cancelledOnDispose = true);
    listCalls.add(page);
    final handler = listHandlers[page];
    if (handler != null) return await handler();
    return Ok(
      OrderPage(
        items: [_order(page)],
        page: page,
        perPage: perPage,
        total: 1,
        totalPages: 1,
        hasMore: false,
      ),
    );
  }

  @override
  Future<Result<OrderDetail>> getOrder(
    int orderId, {
    RequestCancellation? cancellation,
  }) async {
    cancellation?.onCancel(() => cancelledOnDispose = true);
    detailCalls.add(orderId);
    if (detailHandler != null) return await detailHandler!(orderId);
    return Ok(_detail(orderId));
  }
}

ProviderContainer _container(_FakeOrdersRepository repo) {
  final c = ProviderContainer(
    overrides: [ordersRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('TC-083 · TC-084 · OrdersListController', () {
    test('200 vacío emite UiEmpty', () async {
      final repo = _FakeOrdersRepository()
        ..listHandlers[1] = () => const Ok(
          OrderPage(
            items: [],
            page: 1,
            perPage: 10,
            total: 0,
            totalPages: 0,
            hasMore: false,
          ),
        );
      final c = _container(repo)..listen(ordersListProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(c.read(ordersListProvider), isA<UiEmpty<OrdersListData>>());
    });

    test(
      'paginación sin duplicados y error en página 2 conserva página 1',
      () async {
        final repo = _FakeOrdersRepository()
          ..listHandlers[1] = () => Ok(
            OrderPage(
              items: [_order(1), _order(2)],
              page: 1,
              perPage: 10,
              total: 4,
              totalPages: 2,
              hasMore: true,
            ),
          );
        var failPage2 = true;
        repo.listHandlers[2] = () {
          if (failPage2) return const Err(NoConnection());
          return Ok(
            OrderPage(
              items: [_order(2), _order(3)], // id 2 duplicado se filtra
              page: 2,
              perPage: 10,
              total: 4,
              totalPages: 2,
              hasMore: false,
            ),
          );
        };

        final c = _container(repo)..listen(ordersListProvider, (_, _) {});
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        final ctrl = c.read(ordersListProvider.notifier);
        await ctrl.loadMore();
        var data = (c.read(ordersListProvider) as UiData<OrdersListData>).value;
        expect(data.items.map((o) => o.id), [1, 2]);
        expect(data.pageFailure, isA<NoConnection>());

        // Sin tocar retry no vuelve a pedir página 2.
        await ctrl.loadMore();
        expect(repo.listCalls, [1, 2]);

        // Con retry carga página 2 y deduplica id 2.
        failPage2 = false;
        await ctrl.loadMore(retry: true);
        data = (c.read(ordersListProvider) as UiData<OrdersListData>).value;
        expect(data.items.map((o) => o.id), [1, 2, 3]);
        expect(data.hasMore, isFalse);

        // Al llegar al final no emite más páginas.
        await ctrl.loadMore();
        expect(repo.listCalls, [1, 2, 2]);
      },
    );

    test('refresh conserva los pedidos actuales si la red falla', () async {
      final repo = _FakeOrdersRepository()
        ..listHandlers[1] = () => Ok(
          OrderPage(
            items: [_order(1)],
            page: 1,
            perPage: 10,
            total: 1,
            totalPages: 1,
            hasMore: false,
          ),
        );
      final c = _container(repo)..listen(ordersListProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      repo.listHandlers[1] = () => const Err(ServiceUnavailable());
      await c.read(ordersListProvider.notifier).refresh();
      final state = c.read(ordersListProvider) as UiData<OrdersListData>;
      expect(state.value.items.single.id, 1);
      expect(state.value.pageFailure, isA<ServiceUnavailable>());
    });
  });

  group('TC-085 · TC-086 · OrderDetailController', () {
    test('distingue 404 NotFound de 503 ServiceUnavailable y 200', () async {
      final repo = _FakeOrdersRepository()
        ..detailHandler = (id) => switch (id) {
          404 => const Err(NotFound()),
          503 => const Err(ServiceUnavailable()),
          _ => Ok(_detail(id)),
        };
      final c = _container(repo)
        ..listen(orderDetailProvider(404), (_, _) {})
        ..listen(orderDetailProvider(503), (_, _) {})
        ..listen(orderDetailProvider(10), (_, _) {});
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
        (c.read(orderDetailProvider(404)) as UiFailure).failure,
        isA<NotFound>(),
      );
      expect(
        (c.read(orderDetailProvider(503)) as UiFailure).failure,
        isA<ServiceUnavailable>(),
      );
      final detail =
          (c.read(orderDetailProvider(10)) as UiData<OrderDetail>).value;
      expect(detail.summary.id, 10);
      expect(detail.subtotal, const Money(100000));
    });

    test('cancela la petición en vuelo al destruirse el proveedor', () async {
      final gate = Completer<Result<OrderDetail>>();
      final repo = _FakeOrdersRepository()..detailHandler = (_) => gate.future;
      final c = ProviderContainer(
        overrides: [ordersRepositoryProvider.overrideWithValue(repo)],
      )..listen(orderDetailProvider(1), (_, _) {});
      await Future<void>.delayed(Duration.zero);
      c.dispose();
      expect(repo.cancelledOnDispose, isTrue);
    });
  });
}
