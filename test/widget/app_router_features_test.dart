import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/app/router/app_router.dart';
import 'package:ipr_mobile/core/session/session_controller.dart';
import 'package:ipr_mobile/features/authentication/authentication.dart';
import 'package:ipr_mobile/features/branches/branches.dart';
import 'package:ipr_mobile/features/cart/cart.dart';
import 'package:ipr_mobile/features/catalog/catalog.dart';
import 'package:ipr_mobile/features/checkout/checkout.dart';
import 'package:ipr_mobile/features/home/home.dart';
import 'package:ipr_mobile/features/orders/orders.dart';
import 'package:ipr_mobile/features/product_detail/product_detail.dart';
import 'package:ipr_mobile/features/profile/profile.dart';
import 'package:ipr_mobile/features/search/search.dart';
import 'package:ipr_mobile/features/support/support.dart';
import 'package:ipr_mobile/features/technical_tools/technical_tools.dart';
import 'package:ipr_mobile/shared/navigation/routes.dart';

import '../mocks/fake_session_remote.dart' show fakeTokens;
import 'app_router_test.dart' show pumpIprApp;

void main() {
  group('M1/M2 · cableado de rutas de las features', () {
    final cases = <String, Type>{
      Routes.home: HomeScreen,
      Routes.catalog: CatalogScreen,
      Routes.categoryList('compresores'): ProductListScreen,
      Routes.brands: BrandsScreen,
      Routes.brand('elitech'): BrandLandingScreen,
      Routes.sale: SaleScreen,
      Routes.searchFor('compresor'): SearchScreen,
      Routes.product('detector-co2'): ProductDetailScreen,
      // M3
      Routes.cart: CartScreen,
      // M2
      Routes.account: AccountScreen,
      Routes.login: LoginScreen,
      Routes.register: RegisterScreen,
      Routes.passwordRecovery: PasswordRecoveryScreen,
      Routes.legal: LegalScreen,
      // M5
      Routes.branches: BranchesScreen,
      Routes.branchDetail('sede-prueba'): BranchDetailScreen,
      Routes.btu: BtuCalculatorScreen,
      Routes.support: HelpScreen,
      Routes.pqrs: PqrsScreen,
      Routes.engineering: EngineeringScreen,
      Routes.btuCatalogList('12-000-btu'): ProductListScreen,
    };
    for (final entry in cases.entries) {
      testWidgets('${entry.key} abre ${entry.value}', (tester) async {
        final c = await pumpIprApp(tester);
        c.read(appRouterProvider).go(entry.key);
        await tester.pumpAndSettle();
        expect(find.byType(entry.value), findsOneWidget);
      });
    }

    testWidgets('la categoría y la consulta llegan a su pantalla', (
      tester,
    ) async {
      final c = await pumpIprApp(tester);
      c.read(appRouterProvider).go(Routes.categoryList('compresores'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ProductListScreen>(find.byType(ProductListScreen))
            .categorySlug,
        'compresores',
      );
      c.read(appRouterProvider).go(Routes.product('detector-co2'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ProductDetailScreen>(find.byType(ProductDetailScreen))
            .slug,
        'detector-co2',
      );
    });
  });

  group('M3 · rutas del pago (protegidas por sesión)', () {
    testWidgets('sin sesión /checkout lleva a login con from', (tester) async {
      final c = await pumpIprApp(tester);
      c.read(appRouterProvider).go(Routes.checkout);
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('con sesión /checkout y /checkout/result abren su pantalla', (
      tester,
    ) async {
      final c = await pumpIprApp(tester);
      await c
          .read(sessionControllerProvider.notifier)
          .setSession(fakeTokens('a'));
      c.read(appRouterProvider).go(Routes.checkout);
      await tester.pumpAndSettle();
      expect(find.byType(CheckoutScreen), findsOneWidget);
      c
          .read(appRouterProvider)
          .go('${Routes.checkoutResult}?order=1&status=paid');
      await tester.pumpAndSettle();
      final result = tester.widget<CheckoutResultScreen>(
        find.byType(CheckoutResultScreen),
      );
      expect(result.order, '1');
      expect(result.status, 'paid');
    });
  });

  group('M4 · rutas de pedidos y perfil (protegidas por sesión)', () {
    for (final path in [
      Routes.orders,
      Routes.orderDetail(1001),
      Routes.profile,
      Routes.changePassword,
      Routes.addresses,
      Routes.deleteAccount,
      Routes.dataRights,
    ]) {
      testWidgets('sin sesión $path lleva a login', (tester) async {
        final c = await pumpIprApp(tester);
        c.read(appRouterProvider).go(path);
        await tester.pumpAndSettle();
        expect(find.byType(LoginScreen), findsOneWidget);
      });
    }

    testWidgets('con sesión abren las pantallas reales de M4', (tester) async {
      final c = await pumpIprApp(tester);
      await c
          .read(sessionControllerProvider.notifier)
          .setSession(fakeTokens('a'));
      final expected = <String, Type>{
        Routes.orders: OrdersScreen,
        Routes.orderDetail(1001): OrderDetailScreen,
        Routes.profile: ProfileScreen,
        Routes.changePassword: ChangePasswordScreen,
        Routes.addresses: AddressesScreen,
        Routes.deleteAccount: DeleteAccountScreen,
        Routes.dataRights: DataRightsScreen,
      };
      for (final entry in expected.entries) {
        c.read(appRouterProvider).go(entry.key);
        await tester.pumpAndSettle();
        expect(find.byType(entry.value), findsOneWidget, reason: entry.key);
      }
    });
  });
}
