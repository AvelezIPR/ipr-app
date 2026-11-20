import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ipr_mobile/core/config/remote_config.dart';
import 'package:ipr_mobile/core/external/screen_protection.dart';
import 'package:ipr_mobile/core/providers.dart';
import 'package:ipr_mobile/core/session/session_state.dart';
import 'package:ipr_mobile/core/storage/cache_store.dart';
import 'package:ipr_mobile/features/checkout/checkout.dart';
import 'package:ipr_mobile/features/checkout/domain/rules/checkout_flow.dart';
import 'package:ipr_mobile/features/checkout/presentation/controllers/checkout_controller.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/ipr_localizations.dart';
import 'package:ipr_mobile/shared/design_system/ipr_theme.dart';
import 'package:ipr_mobile/shared/navigation/routes.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../unit/features/checkout/support/checkout_fakes.dart';

/// Registra la protección de captura (SC-035).
final class FakeScreenProtection implements ScreenProtection {
  int enabled = 0;
  int disabled = 0;

  @override
  Future<void> enable() async => enabled++;

  @override
  Future<void> disable() async => disabled++;
}

/// Controlador que arranca en un estado dado (para pintar cada resultado sin
/// recorrer todo el flujo). Las acciones siguen siendo las reales.
final class SeededCheckoutController extends CheckoutController {
  new(this.seed);

  final CheckoutFlowState seed;

  @override
  CheckoutFlowState build() {
    super.build();
    return seed;
  }
}

/// Lo que devuelve [pumpCheckout].
final class CheckoutWidgetHarness {
  new({
    required this.cart,
    required this.repo,
    required this.browser,
    required this.cache,
    required this.clock,
    required this.protection,
    required this.session,
    required this.remoteConfig,
    required this.router,
  });

  final FakeCheckoutCart cart;
  final FakeCheckoutRepository repo;
  final FakeSecureBrowser browser;
  final MemoryCacheStore cache;
  final ManualClock clock;
  final FakeScreenProtection protection;
  final FakeSessionController session;
  final FakeRemoteConfigController remoteConfig;
  final GoRouter router;

  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(Navigator).first));

  CheckoutFlowState state(WidgetTester tester) =>
      container(tester).read(checkoutControllerProvider);

  String get location =>
      router.routerDelegate.currentConfiguration.uri.toString();
}

/// Monta las pantallas del checkout dentro de un `GoRouter` mínimo con las
/// rutas que enlazan (`/`, carrito, catálogo, pedidos, login).
Future<CheckoutWidgetHarness> pumpCheckout(
  WidgetTester tester, {
  String start = Routes.checkout,
  CheckoutFlowState? seed,
  FakeCheckoutCart? cart,
  FakeCheckoutRepository? repo,
  FakeSecureBrowser? browser,
  MemoryCacheStore? cache,
  RemoteConfig config = checkoutOn,
  SessionState sessionState = const SessionAuthenticated(userId: 4821),
  double textScale = 1,
  Size size = const Size(360, 800),
}) async {
  final fakeCart = cart ?? FakeCheckoutCart();
  final fakeRepo = repo ?? FakeCheckoutRepository();
  final fakeBrowser = browser ?? FakeSecureBrowser();
  final fakeCache = cache ?? MemoryCacheStore();
  final clock = ManualClock();
  final protection = FakeScreenProtection();
  final session = FakeSessionController(sessionState);
  final remoteConfig = FakeRemoteConfigController(config);

  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
    tester.platformDispatcher.clearAllTestValues();
  });

  Widget marker(String text) => Scaffold(body: Text(text));

  final router = GoRouter(
    initialLocation: start,
    routes: [
      GoRoute(path: Routes.home, builder: (_, _) => marker('PANTALLA INICIO')),
      GoRoute(path: Routes.cart, builder: (_, _) => marker('PANTALLA CARRITO')),
      GoRoute(
        path: Routes.catalog,
        builder: (_, _) => marker('PANTALLA CATALOGO'),
      ),
      GoRoute(
        path: Routes.orders,
        builder: (_, _) => marker('PANTALLA PEDIDOS'),
      ),
      GoRoute(path: Routes.login, builder: (_, _) => marker('PANTALLA LOGIN')),
      GoRoute(path: Routes.checkout, builder: (_, _) => const CheckoutScreen()),
      GoRoute(
        path: Routes.checkoutResult,
        builder: (_, state) => CheckoutResultScreen(
          order: state.uri.queryParameters['order'],
          status: state.uri.queryParameters['status'],
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  // Un árbol nuevo: si no, `ProviderScope` conserva el estado de la
  // llamada anterior.
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...checkoutTestOverrides(
          cart: fakeCart,
          repo: fakeRepo,
          browser: fakeBrowser,
          cache: fakeCache,
          clock: clock,
          uuids: SequentialUuids(),
          session: session,
          remoteConfig: remoteConfig,
        ),
        screenProtectionProvider.overrideWithValue(protection),
        if (seed != null)
          checkoutControllerProvider.overrideWith(
            () => SeededCheckoutController(seed),
          ),
      ],
      child: MaterialApp.router(
        theme: IprTheme.light(),
        locale: iprLocale,
        localizationsDelegates: iprLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await settle(tester);

  return CheckoutWidgetHarness(
    cart: fakeCart,
    repo: fakeRepo,
    browser: fakeBrowser,
    cache: fakeCache,
    clock: clock,
    protection: protection,
    session: session,
    remoteConfig: remoteConfig,
    router: router,
  );
}

/// Deja correr microtareas, fotogramas y navegación sin `pumpAndSettle` (los
/// indicadores de progreso animan sin parar).
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Finder buttonLabeled(String label) => find.widgetWithText(FilledButton, label);

Finder outlinedLabeled(String label) =>
    find.widgetWithText(OutlinedButton, label);

Finder anyButtonLabeled(String label) => find.byWidgetPredicate(
  (widget) =>
      (widget is FilledButton && _hasText(widget.child, label)) ||
      (widget is OutlinedButton && _hasText(widget.child, label)),
  description: 'botón "$label"',
);

bool _hasText(Widget? child, String label) =>
    child is Text && child.data == label;

bool isButtonEnabled(WidgetTester tester, Finder button) {
  final widget = tester.widget(button);
  return switch (widget) {
    FilledButton(:final onPressed) => onPressed != null,
    OutlinedButton(:final onPressed) => onPressed != null,
    _ => throw StateError('no es un botón'),
  };
}

Future<void> tapButton(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await settle(tester);
}
