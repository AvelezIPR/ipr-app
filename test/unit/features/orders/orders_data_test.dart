import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/core/session/session_gateway.dart';
import 'package:ipr_mobile/features/orders/data/datasources/orders_remote_datasource.dart';
import 'package:ipr_mobile/features/orders/data/dtos/orders_dtos.dart';
import 'package:ipr_mobile/features/orders/data/mappers/orders_mappers.dart';
import 'package:ipr_mobile/features/orders/data/repositories/api_orders_repository.dart';
import 'package:ipr_mobile/features/orders/domain/entities/order_entities.dart';
import 'package:ipr_mobile/shared/domain/money.dart';

import '../../../mocks/fake_http_adapter.dart';
import '../../../mocks/test_clients.dart';

final class _FakeGateway implements SessionGateway {
  @override
  String? get accessToken => 'ipra_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  @override
  Future<bool> hasRefreshToken() async => true;

  @override
  Future<RefreshOutcome> refresh() async => RefreshOutcome.expired;

  @override
  Future<void> expire() async {}
}

Map<String, Object?> _summaryJson({
  int id = 1001,
  String number = '1001',
  String paymentState = 'paid',
  Object? total = 450000,
}) => {
  'id': id,
  'number': number,
  'status': 'processing',
  'statusLabel': 'En preparación',
  'paymentState': paymentState,
  'createdAt': '2026-11-19T18:30:00Z',
  'currency': 'COP',
  'total': total,
  'itemCount': 2,
};

Map<String, Object?> _detailJson({
  int id = 1001,
  Object? subtotal = 450000,
  Object? shipping = 25000,
  Object? discount = 10000,
  Object? tax = 0,
}) => {
  'data': {
    ..._summaryJson(id: id, total: 465000),
    'subtotal': subtotal,
    'shippingTotal': shipping,
    'discountTotal': discount,
    'taxTotal': tax,
    'paymentMethodTitle': 'Wompi',
    'items': [
      {
        'productId': 501,
        'name': 'Compresor QA',
        'sku': 'QA-1',
        'quantity': 1,
        'total': 350000,
        'imageUrl': 'https://staging.invalid/img.jpg',
      },
      {
        'productId': null,
        'name': 'Capacitor QA',
        'sku': null,
        'quantity': 2,
        'total': 100000,
        'imageUrl': null,
      },
    ],
  },
};

void main() {
  group('M4 · orders DTOs y mappers', () {
    test('mapeo tolerante: paymentState desconocido cae a unknown', () {
      final dto = OrderSummaryDto.fromJson(
        _summaryJson(paymentState: 'gateway_v2_pending'),
      );
      final entity = mapOrderSummary(dto);
      expect(entity.paymentState, OrderPaymentState.unknown);
      expect(entity.total, const Money(450000));
      expect(entity.toString(), isNotEmpty);
    });

    test(
      'importes flotantes o negativos producen ContractFailure (CR-047)',
      () async {
        final adapter = FakeHttpAdapter([
          (_) => FakeHttpAdapter.json({
            'data': [_summaryJson(total: 1200.5)],
            'meta': {
              'page': 1,
              'perPage': 10,
              'total': 1,
              'totalPages': 1,
              'hasMore': false,
            },
          }),
        ]);
        final repo = ApiOrdersRepository(
          OrdersRemoteDataSource(
            buildTestClient(adapter: adapter, gateway: _FakeGateway()).client,
          ),
        );
        final res = await repo.listOrders();
        expect((res as Err).failure, isA<ContractFailure>());
      },
    );

    test('OrderDetailDto ignora campos no soportados (dirección/tracking)', () {
      final raw = _detailJson();
      (raw['data']! as Map<String, Object?>)['shippingAddress'] = 'secreta';
      (raw['data']! as Map<String, Object?>)['trackingNumber'] = 'TRK-99';
      final detail = mapOrderDetail(OrderDetailDto.fromJson(raw));
      expect(detail.items, hasLength(2));
      expect(detail.items.first.image?.url, 'https://staging.invalid/img.jpg');
      expect(detail.items.last.image, isNull);
    });
  });

  group('TC-083 · TC-086 · ApiOrdersRepository', () {
    test('listOrders envía Bearer, page y perPage y mapea la página', () async {
      final adapter = FakeHttpAdapter([
        (_) => FakeHttpAdapter.json({
          'data': [_summaryJson()],
          'meta': {
            'page': 2,
            'perPage': 10,
            'total': 15,
            'totalPages': 2,
            'hasMore': false,
          },
        }),
      ]);
      final repo = ApiOrdersRepository(
        OrdersRemoteDataSource(
          buildTestClient(adapter: adapter, gateway: _FakeGateway()).client,
        ),
      );

      final res = await repo.listOrders(page: 2);
      final page = (res as Ok<OrderPage>).value;
      expect(page.items, hasLength(1));
      expect(page.page, 2);
      expect(page.hasMore, isFalse);

      final req = adapter.requests.single;
      expect(req.path, '/orders');
      expect(req.queryParameters, {'page': 2, 'perPage': 10});
      expect(req.headers['Authorization'], startsWith('Bearer ipra_'));
    });

    test(
      'TC-086 · AC-108-3 · pedido ajeno (404) ≠ caída (503) ≠ sin red',
      () async {
        final adapter = FakeHttpAdapter([
          (_) => FakeHttpAdapter.problem(404, 'not_found'),
          (_) => FakeHttpAdapter.problem(503, 'upstream_unavailable'),
          (_) => FakeHttpAdapter.problem(503, 'upstream_unavailable'),
          (_) => FakeHttpAdapter.problem(503, 'upstream_unavailable'),
          FakeHttpAdapter.connectionError,
          FakeHttpAdapter.connectionError,
          FakeHttpAdapter.connectionError,
        ]);
        final repo = ApiOrdersRepository(
          OrdersRemoteDataSource(
            buildTestClient(adapter: adapter, gateway: _FakeGateway()).client,
          ),
        );

        expect((await repo.getOrder(999) as Err).failure, isA<NotFound>());
        expect(
          (await repo.getOrder(1001) as Err).failure,
          isA<ServiceUnavailable>(),
        );
        expect((await repo.getOrder(1001) as Err).failure, isA<NoConnection>());
      },
    );

    test('getOrder devuelve el detalle exacto del servidor', () async {
      final adapter = FakeHttpAdapter([
        (_) => FakeHttpAdapter.json(_detailJson()),
      ]);
      final repo = ApiOrdersRepository(
        OrdersRemoteDataSource(
          buildTestClient(adapter: adapter, gateway: _FakeGateway()).client,
        ),
      );
      final res = await repo.getOrder(1001);
      final detail = (res as Ok<OrderDetail>).value;
      expect(detail.summary.id, 1001);
      expect(detail.subtotal, const Money(450000));
      expect(detail.shippingTotal, const Money(25000));
      expect(detail.discountTotal, const Money(10000));
      expect(detail.taxTotal, Money.zero);
      expect(detail.paymentMethodTitle, 'Wompi');
    });
  });
}
