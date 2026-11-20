import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ipr_mobile/core/storage/durable_store.dart';
import 'package:ipr_mobile/features/cart/cart.dart';
import 'package:ipr_mobile/features/cart/data/mappers/cart_storage_codec.dart';
import 'package:ipr_mobile/features/cart/domain/entities/cart.dart';
import 'package:ipr_mobile/features/cart/domain/repositories/cart_repositories.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/ipr_localizations.dart';
import 'package:ipr_mobile/shared/design_system/ipr_theme.dart';
import 'package:ipr_mobile/shared/navigation/routes.dart';
import 'package:material_ui/material_ui.dart';

import '../../../mocks/test_providers.dart';
import '../../../unit/features/cart/cart_test_support.dart';

export 'package:ipr_mobile/core/storage/durable_store.dart'
    show MemoryDurableStore;

export '../../../mocks/pump_app.dart';
export '../../../mocks/test_providers.dart';
export '../../../unit/features/cart/cart_test_support.dart';

/// Almacén cuya lectura espera a que la prueba la libere (estado "Cargando").
final class GatedDurableStore implements DurableStore {
  new(this.inner);

  final MemoryDurableStore inner;
  final Completer<void> gate = Completer<void>();

  @override
  Future<String?> read(String key) async {
    await gate.future;
    final value = await inner.read(key);
    return value;
  }

  @override
  Future<void> write(String key, String value) => inner.write(key, value);

  @override
  Future<void> remove(String key) => inner.remove(key);
}

/// Lo que una prueba necesita del carrito montado.
final class CartEnv {
  const new({
    required this.container,
    required this.store,
    required this.router,
    this.validation,
  });

  final ProviderContainer container;
  final MemoryDurableStore store;
  final GoRouter router;
  final FakeCartValidationRepository? validation;

  CartController get cart => container.read(cartProvider.notifier);
  CartState get state => container.read(cartProvider);

  /// Ruta actual del enrutador de prueba.
  String get location =>
      router.routerDelegate.currentConfiguration.uri.toString();

  Cart get stored =>
      CartStorageCodec.decode(store.data[CartStorageCodec.storageKey]);
}

const _marker = 'DESTINO ';

/// Monta la pestaña Carrito con un enrutador mínimo (inicio = carrito;
/// `/checkout` y `/catalog` pintan un marcador).
Future<CartEnv> pumpCart(
  WidgetTester tester, {
  List<CartLine> lines = const [],
  CartValidationRepository? validation,
  bool checkoutEnabled = true,
  double textScale = 1,
  Size size = const Size(360, 1600),
  DurableStore? durable,
  MemoryDurableStore? seed,
  bool settle = true,
  FakeExternalLauncher? launcher,
  ValueListenable<bool>? tabActive,
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

  final store =
      seed ??
      MemoryDurableStore({
        if (lines.isNotEmpty)
          CartStorageCodec.storageKey: CartStorageCodec.encode(Cart(lines)),
      });
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          body: tabActive == null
              ? const CartScreen()
              : ValueListenableBuilder<bool>(
                  valueListenable: tabActive,
                  builder: (_, active, _) =>
                      TickerMode(enabled: active, child: const CartScreen()),
                ),
        ),
      ),
      for (final path in [Routes.checkout, Routes.catalog, Routes.login])
        GoRoute(
          path: path,
          builder: (_, _) => Scaffold(body: Text('$_marker$path')),
        ),
    ],
  );
  addTearDown(router.dispose);

  final scope = ProviderScope(
    overrides: cartOverrides(
      durable: durable ?? store,
      validation: validation,
      checkoutEnabled: checkoutEnabled,
      launcher: launcher,
    ),
    child: MaterialApp.router(
      theme: IprTheme.light(),
      locale: iprLocale,
      localizationsDelegates: iprLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
  await tester.pumpWidget(scope);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  final container = ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  );
  return CartEnv(
    container: container,
    store: store,
    router: router,
    validation: validation is FakeCartValidationRepository ? validation : null,
  );
}

Finder get payButton => find.ancestor(
  of: find.textContaining(RegExp('^(Pagar|Verificando…)')),
  matching: find.bySubtype<FilledButton>(),
);

bool isEnabled(WidgetTester tester, Finder button) =>
    tester.widget<FilledButton>(button).onPressed != null;

/// ¿La pantalla llegó a `path`? (el enrutador de prueba pinta un marcador).
Finder destination(String path) => find.text('$_marker$path');

/// Texto visible completo, para buscar cadenas prohibidas.
String allText(WidgetTester tester) => [
  for (final text in tester.widgetList<Text>(find.byType(Text)))
    text.data ?? text.textSpan?.toPlainText() ?? '',
].join('\n');

/// Etiqueta semántica anunciada por un [Finder].
String semanticsLabel(WidgetTester tester, Finder finder) =>
    tester.getSemantics(finder).label;

/// Desplaza la lista hasta que [finder] sea visible.
Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
}

SemanticsHandle ensureSemantics(WidgetTester tester) =>
    tester.ensureSemantics();
