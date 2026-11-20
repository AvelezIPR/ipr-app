import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ipr_mobile/core/config/remote_config.dart';
import 'package:ipr_mobile/core/config/remote_config_controller.dart';
import 'package:ipr_mobile/core/config/remote_config_repository.dart';
import 'package:ipr_mobile/features/technical_tools/technical_tools.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/ipr_localizations.dart';
import 'package:ipr_mobile/shared/design_system/ipr_theme.dart';
import 'package:ipr_mobile/shared/navigation/routes.dart';
import 'package:material_ui/material_ui.dart';

import '../../../mocks/test_providers.dart';

Future<({FakeExternalLauncher launcher, List<String> visited})> _pumpBtu(
  WidgetTester tester, {
  bool enabled = true,
  double textScale = 1,
}) async {
  final launcher = FakeExternalLauncher();
  final visited = <String>[];

  tester.view
    ..physicalSize = const Size(360, 800)
    ..devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearAllTestValues();
  });

  final router = GoRouter(
    initialLocation: Routes.btu,
    routes: [
      GoRoute(path: Routes.btu, builder: (_, _) => const BtuCalculatorScreen()),
      GoRoute(
        path: Routes.catalogList,
        builder: (_, state) {
          visited.add(state.uri.toString());
          return Scaffold(body: Text('DESTINO ${state.uri}'));
        },
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: testOverrides(
        launcher: launcher,
        extra: [
          remoteConfigProvider.overrideWithBuild(
            (_, _) => RemoteConfigState(
              config: RemoteConfig(
                btuCalculatorEnabled: enabled,
                whatsappNumber: '573000000009',
              ),
              source: RemoteConfigSource.network,
            ),
          ),
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
  await tester.pump();
  return (launcher: launcher, visited: visited);
}

Future<void> _enterAndCalculate(
  WidgetTester tester, {
  required String length,
  required String width,
  required String height,
  required String occupants,
  required String equipment,
  String? climateLabel,
}) async {
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), length);
  await tester.enterText(fields.at(1), width);
  await tester.enterText(fields.at(2), height);
  await tester.enterText(fields.at(3), occupants);
  await tester.enterText(fields.at(4), equipment);

  if (climateLabel != null) {
    await tester.ensureVisible(
      find.byType(DropdownButtonFormField<ClimateZone>),
    );
    await tester.tap(find.byType(DropdownButtonFormField<ClimateZone>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(climateLabel).last);
    await tester.pumpAndSettle();
  }

  final calculateBtn = find.widgetWithText(FilledButton, 'Calcular BTU');
  await tester.ensureVisible(calculateBtn);
  await tester.tap(calculateBtn);
  await tester.pump();
}

void main() {
  group('TC-140 · AC-085 · Calculadora BTU (D-08 detrás de flag)', () {
    testWidgets(
      'M5 · D-08 · falla cerrado cuando btuCalculatorEnabled es false',
      (tester) async {
        await _pumpBtu(tester, enabled: false);
        expect(find.text('Calculadora no disponible'), findsOneWidget);
        expect(find.text('Calcular BTU'), findsNothing);
      },
    );

    testWidgets(
      'TC-140 · AC-085-1/5/6/7 · muestra 6 entradas, clima inicial Templado y calcula con coma sin sesión ni red',
      (tester) async {
        await _pumpBtu(tester);
        expect(find.byType(TextField), findsNWidgets(5));
        expect(find.text('Templado'), findsOneWidget);

        await _enterAndCalculate(
          tester,
          length: '4',
          width: '5',
          height: '2,5',
          occupants: '2',
          equipment: '0',
        );
        // T3: 4*5*600*1.05 = 12.600 -> sugerido 18.000
        expect(find.text('12.600 BTU'), findsOneWidget);
        expect(find.text('18.000 BTU'), findsOneWidget);
      },
    );
  });

  group(
    'TC-128 · AC-087/088/089 · resultado, aviso, >36.000 BTU y Ver equipos',
    () {
      testWidgets(
        'TC-128 · AC-087-1 · AC-089-1 · T4 muestra 24.000 BTU, aviso y navega a catálogo filtrado',
        (tester) async {
          final env = await _pumpBtu(tester, textScale: 2);
          await _enterAndCalculate(
            tester,
            length: '5',
            width: '5',
            height: '3.0',
            occupants: '4',
            equipment: '2',
            climateLabel: 'Cálido',
          );
          expect(find.text('21.555 BTU'), findsOneWidget);
          expect(find.text('24.000 BTU'), findsOneWidget);
          expect(find.textContaining('estimación referencial'), findsOneWidget);

          final viewBtn = find.text('Ver equipos');
          await tester.ensureVisible(viewBtn);
          await tester.tap(viewBtn);
          await tester.pumpAndSettle();
          expect(env.visited, ['/catalog/list?btu=24-000-btu']);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'TC-128 · AC-087-2 · AC-088-1..3 · AC-089-4 · T9 >36.000 BTU omite Ver equipos y abre asesor con valor',
        (tester) async {
          final env = await _pumpBtu(tester);
          await _enterAndCalculate(
            tester,
            length: '12',
            width: '5',
            height: '2.5',
            occupants: '2',
            equipment: '1',
            climateLabel: 'Frío',
          );
          expect(find.text('36.600 BTU'), findsOneWidget);
          expect(find.text('0 BTU'), findsNothing);
          expect(find.textContaining('undefined'), findsNothing);
          expect(find.text('Ver equipos'), findsNothing);
          expect(find.textContaining('estimación referencial'), findsOneWidget);

          final advisorBtn = find.text('Contactar a un asesor');
          await tester.ensureVisible(advisorBtn);
          await tester.tap(advisorBtn);
          await tester.pump();
          expect(env.launcher.opened, hasLength(1));
          expect(
            env.launcher.opened.single.queryParameters['text'],
            contains('36.600'),
          );
        },
      );
    },
  );
}
