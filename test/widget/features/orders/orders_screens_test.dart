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
import 'package:ipr_mobile/shared/widgets/state_widgets.dart';
import 'package:material_ui/material_ui.dart';

import '../../../mocks/test_providers.dart';

final class _RecordingProtection implements ScreenProtection {
  int enables = 0;
  int disables = 0;

  @override
  Future<void> enable() async => enables++;

  @override
  Future<void> disable() async => disables++;
}

final class _StubOrdersRepository implements OrdersRepository {
  Result<OrderPage> Function(int page)? onList;
  Result<OrderDetail> Function(int orderId)? onDetail;

  @override
  Future<Result<OrderPage>> listOrders({
    int page = 1,
    int perPage = OrdersRepository.defaultPerPage,
    RequestCancellation? cancellation,
  }) async =>
      onList?.call(page) ??
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
  }) async => onDetail?.call(orderId) ?? const Err(NotFound());
}

OrderSummary _summary({
  int id = 1001,
  String number = '1001',
  String statusLabel = 'En preparación',
  OrderPaymentState paymentState = OrderPaymentState.paid,
  int total = 465000,
}) => OrderSummary(
  id: id,
  number: number,
  status: 'processing',
  statusLabel: statusLabel,
  paymentState: paymentState,
  createdAt: DateTime.utc(2026, 11, 20, 15, 30),
  currency: 'COP',
  total: Money(total),
  itemCount: 2,
);

OrderDetail _detail({
  String name = 'Compresor rotativo QA',
  String statusLabel = 'En preparación',
  OrderPaymentState paymentState = OrderPaymentState.paid,
}) => OrderDetail(
  summary: _summary(statusLabel: statusLabel, paymentState: paymentState),
  subtotal: const Money(450000),
  shippingTotal: const Money(25000),
  discountTotal: const Money(10000),
  taxTotal: Money.zero,
  paymentMethodTitle: 'Wompi',
  items: [
    OrderItem(
      productId: 501,
      name: name,
      sku: 'QA-COMP-12K',
      quantity: 1,
      total: const Money(350000),
      image: const ImageRef(
        url: 'https://otro-host.invalid/compresor.jpg',
        alt: 'Compresor',
      ),
    ),
  ],
);

Future<_RecordingProtection> _pump(
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

  final protection = _RecordingProtection();
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
          screenProtectionProvider.overrideWithValue(protection),
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
  return protection;
}

void main() {
  group('TC-083 · TC-084 · OrdersScreen', () {
    testWidgets('muestra pedidos con número, fecha Colombia, estado y COP', (
      tester,
    ) async {
      final repo = _StubOrdersRepository()
        ..onList = (_) => Ok(
          OrderPage(
            items: [_summary()],
            page: 1,
            perPage: 10,
            total: 1,
            totalPages: 1,
            hasMore: false,
          ),
        );
      final protection = await _pump(tester, repo: repo);
      expect(protection.enables, greaterThanOrEqualTo(1));
      expect(find.text('Pedido #1001'), findsOneWidget);
      expect(find.text('20/11/2026 10:30'), findsOneWidget);
      expect(find.text('En preparación'), findsOneWidget);
      expect(find.text(r'$ 465.000'), findsOneWidget);
    });

    testWidgets('AC-107-3 · 200 vacío muestra acción al catálogo', (
      tester,
    ) async {
      final repo = _StubOrdersRepository();
      await _pump(tester, repo: repo);
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('Aún no tienes pedidos'), findsOneWidget);
      await tester.tap(find.text('Explorar catálogo'));
      await tester.pumpAndSettle();
      expect(find.text('CATALOGO_DESTINO'), findsOneWidget);
    });

    testWidgets('AC-107-9 · fallo de red muestra ErrorState con Reintentar', (
      tester,
    ) async {
      var attempt = 0;
      final repo = _StubOrdersRepository()
        ..onList = (_) {
          attempt++;
          if (attempt == 1) return const Err(NoConnection());
          return Ok(
            OrderPage(
              items: [_summary()],
              page: 1,
              perPage: 10,
              total: 1,
              totalPages: 1,
              hasMore: false,
            ),
          );
        };
      await _pump(tester, repo: repo);
      expect(find.byType(ErrorState), findsOneWidget);
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Pedido #1001'), findsOneWidget);
    });

    testWidgets('tocar un pedido abre su detalle por id (CR-054)', (
      tester,
    ) async {
      final repo = _StubOrdersRepository()
        ..onList = ((_) => Ok(
          OrderPage(
            items: [_summary()],
            page: 1,
            perPage: 10,
            total: 1,
            totalPages: 1,
            hasMore: false,
          ),
        ))
        ..onDetail = (_) => Ok(_detail());
      await _pump(tester, repo: repo);
      await tester.tap(find.text('Pedido #1001'));
      await tester.pumpAndSettle();
      expect(find.byType(OrderDetailScreen), findsOneWidget);
      expect(find.text('Wompi'), findsOneWidget);
    });
  });

  group('TC-085 · TC-086 · OrderDetailScreen', () {
    testWidgets(
      'muestra líneas, subtotal, envío y descuento (>0), omite tax 0 y ajusta nombre de 150 caracteres en 360 dp',
      (tester) async {
        final longName = 'A' * 150;
        final repo = _StubOrdersRepository()
          ..onDetail = (_) => Ok(
            _detail(
              name: longName,
              statusLabel: '',
              paymentState: OrderPaymentState.unknown,
            ),
          );
        await _pump(tester, repo: repo, initialLocation: '/orders/1001');

        expect(find.text(longName), findsOneWidget);
        expect(find.text('En proceso'), findsOneWidget);
        expect(find.text('Subtotal'), findsOneWidget);
        expect(find.text(r'$ 450.000'), findsOneWidget);
        expect(find.text('Envío'), findsOneWidget);
        expect(find.text(r'$ 25.000'), findsOneWidget);
        expect(find.text('Descuento'), findsOneWidget);
        expect(find.text(r'-$ 10.000'), findsOneWidget);
        expect(find.text('Impuestos'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '404 muestra Pedido no encontrado sin Reintentar; 503 sí reintenta',
      (tester) async {
        final repo = _StubOrdersRepository()
          ..onDetail = (_) => const Err(NotFound());
        await _pump(tester, repo: repo, initialLocation: '/orders/999');
        expect(find.text('Pedido no encontrado'), findsOneWidget);
        expect(find.text('Reintentar'), findsNothing);
        expect(find.text('Volver a mis pedidos'), findsOneWidget);

        repo.onDetail = (_) => const Err(ServiceUnavailable());
        await _pump(tester, repo: repo, initialLocation: '/orders/1001');
        expect(find.text('Reintentar'), findsOneWidget);
      },
    );
  });

  group('RNF-068..071 · accesibilidad y texto al 200 % en pedidos', () {
    testWidgets(
      'OrdersScreen al 200 % sin desbordar y guías de accesibilidad',
      (tester) async {
        final handle = tester.ensureSemantics();
        final repo = _StubOrdersRepository()
          ..onList = (_) => Ok(
            OrderPage(
              items: [_summary()],
              page: 1,
              perPage: 10,
              total: 1,
              totalPages: 1,
              hasMore: false,
            ),
          );
        await _pump(tester, repo: repo, textScale: 2);
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      },
    );

    testWidgets('OrderDetailScreen al 200 % sin desbordar y guías', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final repo = _StubOrdersRepository()..onDetail = (_) => Ok(_detail());
      await _pump(
        tester,
        repo: repo,
        initialLocation: '/orders/1001',
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  });
}
