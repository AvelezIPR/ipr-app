import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/external/screen_protection.dart';
import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/core/providers.dart';
import 'package:ipr_mobile/features/orders/domain/entities/order_entities.dart';
import 'package:ipr_mobile/features/orders/domain/repositories/orders_repository.dart';
import 'package:ipr_mobile/features/orders/orders.dart';
import 'package:ipr_mobile/features/orders/orders_providers.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/ipr_localizations.dart';
import 'package:ipr_mobile/shared/design_system/ipr_theme.dart';
import 'package:ipr_mobile/shared/domain/image_ref.dart';
import 'package:ipr_mobile/shared/domain/money.dart';
import 'package:ipr_mobile/shared/navigation/routes.dart';
import 'package:material_ui/material_ui.dart';

import '../../../mocks/test_providers.dart';

final class _NoopScreenProtection implements ScreenProtection {
  @override
  Future<void> enable() async {}

  @override
  Future<void> disable() async {}
}

final class _StubOrdersRepository implements OrdersRepository {
  new({this.listResult, this.detailResult});

  final Result<OrderPage>? listResult;
  final Result<OrderDetail>? detailResult;

  @override
  Future<Result<OrderPage>> listOrders({
    int page = 1,
    int perPage = OrdersRepository.defaultPerPage,
    RequestCancellation? cancellation,
  }) async =>
      listResult ??
      const Ok(
        OrderPage(
          items: [],
          page: 1,
          perPage: 10,
          total: 0,
          totalPages: 0,
          hasMore: false,
        ),
      );

  @override
  Future<Result<OrderDetail>> getOrder(
    int orderId, {
    RequestCancellation? cancellation,
  }) async => detailResult ?? const Err(NotFound());
}

OrderSummary _summary({
  required int id,
  required OrderPaymentState paymentState,
  String statusLabel = 'En preparación',
  int total = 465000,
  int itemCount = 2,
}) => OrderSummary(
  id: id,
  number: 'QA-$id',
  status: paymentState.name,
  statusLabel: statusLabel,
  paymentState: paymentState,
  createdAt: DateTime.utc(2026, 11, 20, 15, 30),
  currency: 'COP',
  total: Money(total),
  itemCount: itemCount,
);

OrderDetail _detail({
  OrderPaymentState paymentState = OrderPaymentState.paid,
  String statusLabel = 'Pagado',
  String paymentMethodTitle = 'Wompi',
  Money? taxTotal = const Money(19000),
  String firstItemName = 'Compresor scroll QA 24.000 BTU',
}) => OrderDetail(
  summary: _summary(
    id: 1001,
    paymentState: paymentState,
    statusLabel: statusLabel,
  ),
  subtotal: const Money(450000),
  shippingTotal: const Money(25000),
  discountTotal: const Money(10000),
  taxTotal: taxTotal,
  paymentMethodTitle: paymentMethodTitle,
  items: [
    OrderItem(
      productId: 501,
      name: firstItemName,
      sku: 'QA-COMP-12K',
      quantity: 1,
      total: const Money(350000),
      image: const ImageRef(
        url: 'https://otro-host.invalid/compresor.jpg',
        alt: 'Compresor QA',
      ),
    ),
    const OrderItem(
      productId: 502,
      name: 'Contactor tripolar QA 25 A',
      sku: null,
      quantity: 2,
      total: Money(100000),
      image: null,
    ),
  ],
);

Future<void> _pumpOrders(
  WidgetTester tester, {
  required _StubOrdersRepository repo,
  String initialLocation = Routes.orders,
  double textScale = 1,
  Size size = const Size(360, 800),
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearAllTestValues();
  });

  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: Routes.orders, builder: (_, _) => const OrdersScreen()),
      GoRoute(
        path: '${Routes.orders}/:orderId',
        builder: (_, s) =>
            OrderDetailScreen(orderId: int.parse(s.pathParameters['orderId']!)),
      ),
      GoRoute(
        path: Routes.catalog,
        builder: (_, _) => const Scaffold(body: Text('CATALOGO_DESTINO')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: testOverrides(
        extra: [
          ordersRepositoryProvider.overrideWithValue(repo),
          screenProtectionProvider.overrideWithValue(_NoopScreenProtection()),
        ],
      ),
      child: MaterialApp.router(
        theme: IprTheme.light(),
        locale: iprLocale,
        localizationsDelegates: iprLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _scrollToBottom(WidgetTester tester) async {
  final scrollables = find.byType(Scrollable);
  if (scrollables.evaluate().isEmpty) return;
  final scrollable = scrollables.first;
  for (var i = 0; i < 12; i++) {
    final state = tester.state<ScrollableState>(scrollable);
    if (state.position.pixels >= state.position.maxScrollExtent) break;
    await tester.drag(scrollable, const Offset(0, -400));
    await tester.pumpAndSettle();
  }
}

Future<void> _expectAllGuidelines(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}

typedef _OrderScenarioBuilder = Future<void> Function(
  WidgetTester tester, {
  double textScale,
  Size size,
});

final Map<String, _OrderScenarioBuilder> _scenarios = {
  'OrdersScreen · listado con múltiples estados':
      (tester, {textScale = 1, size = const Size(360, 800)}) => _pumpOrders(
        tester,
        textScale: textScale,
        size: size,
        repo: _StubOrdersRepository(
          listResult: Ok(
            OrderPage(
              items: [
                _summary(
                  id: 1001,
                  paymentState: OrderPaymentState.paid,
                  statusLabel: 'Completado',
                ),
                _summary(
                  id: 1002,
                  paymentState: OrderPaymentState.pending,
                  statusLabel: 'Pendiente de pago',
                  total: 120000,
                  itemCount: 1,
                ),
                _summary(
                  id: 1003,
                  paymentState: OrderPaymentState.failed,
                  statusLabel: 'Pago rechazado',
                ),
                _summary(
                  id: 1004,
                  paymentState: OrderPaymentState.cancelled,
                  statusLabel: 'Cancelado',
                ),
                _summary(
                  id: 1005,
                  paymentState: OrderPaymentState.refunded,
                  statusLabel: 'Reembolsado',
                ),
                _summary(
                  id: 1006,
                  paymentState: OrderPaymentState.unknown,
                  statusLabel: '',
                ),
              ],
              page: 1,
              perPage: 10,
              total: 6,
              totalPages: 1,
              hasMore: false,
            ),
          ),
        ),
      ),
  'OrdersScreen · lista vacía':
      (tester, {textScale = 1, size = const Size(360, 800)}) => _pumpOrders(
        tester,
        textScale: textScale,
        size: size,
        repo: _StubOrdersRepository(),
      ),
  'OrdersScreen · fallo de red':
      (tester, {textScale = 1, size = const Size(360, 800)}) => _pumpOrders(
        tester,
        textScale: textScale,
        size: size,
        repo: _StubOrdersRepository(listResult: const Err(NoConnection())),
      ),
  'OrderDetailScreen · detalle completo':
      (tester, {textScale = 1, size = const Size(360, 800)}) => _pumpOrders(
        tester,
        initialLocation: '/orders/1001',
        textScale: textScale,
        size: size,
        repo: _StubOrdersRepository(
          detailResult: Ok(_detail(firstItemName: 'Compresor QA ${'X' * 120}')),
        ),
      ),
  'OrderDetailScreen · estado pendiente sin método de pago':
      (tester, {textScale = 1, size = const Size(360, 800)}) => _pumpOrders(
        tester,
        initialLocation: '/orders/1001',
        textScale: textScale,
        size: size,
        repo: _StubOrdersRepository(
          detailResult: Ok(
            _detail(
              paymentState: OrderPaymentState.pending,
              statusLabel: '',
              paymentMethodTitle: '',
              taxTotal: Money.zero,
            ),
          ),
        ),
      ),
  'OrderDetailScreen · no encontrado (404)':
      (tester, {textScale = 1, size = const Size(360, 800)}) => _pumpOrders(
        tester,
        initialLocation: '/orders/999',
        textScale: textScale,
        size: size,
        repo: _StubOrdersRepository(detailResult: const Err(NotFound())),
      ),
  'OrderDetailScreen · servicio no disponible (503)':
      (tester, {textScale = 1, size = const Size(360, 800)}) => _pumpOrders(
        tester,
        initialLocation: '/orders/1001',
        textScale: textScale,
        size: size,
        repo: _StubOrdersRepository(
          detailResult: const Err(ServiceUnavailable()),
        ),
      ),
};

void main() {
  group('TC-157 · RNF-067..076 · Orders · texto al 200 % sin desbordes', () {
    for (final entry in _scenarios.entries) {
      for (final size in const [Size(360, 800), Size(320, 568)]) {
        testWidgets(
          'TC-157 · RNF-067..076 · ${entry.key} · texto 200 % en ${size.width.toInt()}x${size.height.toInt()}',
          (tester) async {
            await entry.value(tester, textScale: 2, size: size);
            expect(tester.takeException(), isNull);
            await _scrollToBottom(tester);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });

  group('TC-157 · RNF-067..076 · Orders · guías automáticas WCAG 2.2 AA', () {
    for (final entry in _scenarios.entries) {
      testWidgets(
        'TC-157 · RNF-067..076 · ${entry.key} · 4 guías de accesibilidad',
        (tester) async {
          final handle = tester.ensureSemantics();
          try {
            await entry.value(tester, size: const Size(360, 1600));
            await _expectAllGuidelines(tester);
          } finally {
            handle.dispose();
          }
        },
      );
    }
  });

  group('TC-157 · RNF-067..076 · Orders · semántica y no solo color', () {
    testWidgets(
      'TC-157 · RNF-067..076 · OrdersScreen · estado con ícono + texto, tarjeta táctil ≥ 48 dp e importe en pesos',
      (tester) async {
        final handle = tester.ensureSemantics();
        try {
          await _scenarios['OrdersScreen · listado con múltiples estados']!(
            tester,
            size: const Size(360, 1600),
          );

          final firstCard = find.byType(Card).first;
          expect(tester.getSize(firstCard).height, greaterThanOrEqualTo(48));
          expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
          expect(find.byIcon(Icons.error_outline), findsNWidgets(2));
          expect(find.byIcon(Icons.schedule), findsNWidgets(3));
          final cardSemantics = tester.getSemantics(firstCard);
          expect(cardSemantics.label, contains('Estado: Completado'));
          expect(cardSemantics.label, contains('465.000 pesos, IVA incluido'));
        } finally {
          handle.dispose();
        }
      },
    );

    testWidgets(
      'TC-157 · RNF-067..076 · OrderDetailScreen · encabezado Productos, descuento negativo e ícono + texto',
      (tester) async {
        final handle = tester.ensureSemantics();
        try {
          await _scenarios['OrderDetailScreen · detalle completo']!(
            tester,
            size: const Size(360, 1600),
          );

          expect(
            tester.getSemantics(find.text('Productos')),
            isSemantics(isHeader: true, label: 'Productos'),
          );
          expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
          expect(
            tester.getSemantics(find.text(r'-$ 10.000')).label,
            contains('-10.000 pesos, IVA incluido'),
          );
          expect(
            tester.getSemantics(find.text(r'$ 465.000')).label,
            contains('465.000 pesos, IVA incluido'),
          );
        } finally {
          handle.dispose();
        }
      },
    );
  });
}
