import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ipr_mobile/core/config/remote_config.dart';
import 'package:ipr_mobile/core/config/remote_config_controller.dart';
import 'package:ipr_mobile/core/config/remote_config_repository.dart'
    show RemoteConfigSource;
import 'package:ipr_mobile/features/home/domain/repositories/home_repository.dart';
import 'package:ipr_mobile/features/home/home.dart';
import 'package:ipr_mobile/features/home/home_providers.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/ipr_localizations.dart';
import 'package:ipr_mobile/shared/design_system/ipr_theme.dart';
import 'package:material_ui/material_ui.dart';

import '../../../mocks/test_providers.dart';

/// Destinos que el inicio puede abrir; cada uno pinta un marcador con su
/// ruta para comprobar la navegación sin depender de otras features.
const _marker = 'DESTINO ';

const _destinations = [
  '/search',
  '/catalog',
  '/catalog/list',
  '/catalog/brands',
  '/catalog/brands/:slug',
  '/catalog/sale',
  '/branches',
  '/product/:slug',
  '/support',
  '/cart',
  '/tools/btu',
];

/// Datos de contacto para las pruebas.
const phoneConfig = RemoteConfigState(
  config: RemoteConfig(
    whatsappNumber: '573014021882',
    phoneDial: '+576043604440',
    phoneDisplay: '(604) 360 4440',
  ),
  source: RemoteConfigSource.network,
);

/// Monta el inicio dentro de un `GoRouter` con destinos marcadores (ver
/// [destinationOf]).
Future<void> pumpHome(
  WidgetTester tester, {
  required HomeRepository repository,
  FakeExternalLauncher? launcher,
  double textScale = 1,
  Size size = const Size(360, 800),
  List<Override> extra = const [],
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
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: HomeScreen()),
      ),
      for (final path in _destinations)
        GoRoute(
          path: path,
          builder: (context, state) =>
              Scaffold(body: Center(child: Text('$_marker${state.uri}'))),
        ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: testOverrides(
        launcher: launcher,
        extra: [homeRepositoryProvider.overrideWithValue(repository), ...extra],
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
  // Un cuadro para que arranquen las cargas y otro para pintar su resultado.
  await tester.pump();
  await tester.pump();
}

/// Destino abierto por el inicio (lo pinta el marcador de cada ruta de
/// prueba, con la URI completa incluida la consulta).
String destinationOf(WidgetTester tester) {
  final texts = tester
      .widgetList<Text>(find.textContaining(_marker))
      .map((t) => t.data!)
      .toList();
  expect(texts, hasLength(1), reason: 'se esperaba un solo destino abierto');
  return texts.single.substring(_marker.length);
}

/// Override de `/config` con teléfono de atención.
Override phoneOverride() =>
    remoteConfigProvider.overrideWithBuild((ref, notifier) => phoneConfig);

/// Dos cuadros: arranca la carga pendiente y pinta su resultado.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}
