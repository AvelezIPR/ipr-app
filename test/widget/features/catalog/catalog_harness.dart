import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ipr_mobile/core/storage/cache_store.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/ipr_localizations.dart';
import 'package:ipr_mobile/shared/design_system/ipr_theme.dart';
import 'package:ipr_mobile/shared/navigation/routes.dart';
import 'package:material_ui/material_ui.dart';

import '../../../fixtures/catalog/fake_catalog_bff.dart';

/// Monta [screen] como ruta `/` de un `GoRouter` con destinos de relleno para
/// el resto de rutas: cada una muestra `DESTINO <ubicación>` y queda en
/// [visited]. Devuelve el router para poder consultar la ubicación.
Future<GoRouter> pumpCatalog(
  WidgetTester tester,
  Widget screen,
  FakeCatalogBff bff, {
  double textScale = 1,
  Size size = const Size(360, 800),
  CacheStore? cache,
  List<String>? visited,
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

  GoRoute stub(String path) => GoRoute(
    path: path,
    builder: (context, state) {
      visited?.add(state.uri.toString());
      return Scaffold(appBar: AppBar(title: Text('DESTINO ${state.uri}')));
    },
  );

  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => screen),
      stub(Routes.catalogList),
      stub(Routes.brands),
      stub('${Routes.brandPrefix}/:slug'),
      stub(Routes.sale),
      stub(Routes.search),
      stub('${Routes.productPrefix}/:slug'),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: bff.overrides(cache: cache),
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
  return router;
}

/// Deja correr las peticiones simuladas y las transiciones. Hay animaciones
/// que no terminan (el indicador de carga), así que no se usa `pumpAndSettle`.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Toca el botón atrás de la barra superior y espera la transición.
Future<void> goBack(WidgetTester tester) async {
  await tester.tap(find.byType(BackButton).last);
  await settle(tester);
}
