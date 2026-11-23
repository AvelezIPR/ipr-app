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

Future<void> _pumpBtu(
  WidgetTester tester, {
  bool enabled = true,
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
    initialLocation: Routes.btu,
    routes: [
      GoRoute(path: Routes.btu, builder: (_, _) => const BtuCalculatorScreen()),
      GoRoute(
        path: Routes.catalogList,
        builder: (_, state) => Scaffold(body: Text('DESTINO ${state.uri}')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: testOverrides(
        extra: [
          remoteConfigProvider.overrideWithBuild(
            (_, _) => RemoteConfigState(
              config: RemoteConfig(
                btuCalculatorEnabled: enabled,
                whatsappNumber: '573000000000',
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
  await tester.pumpAndSettle();
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
    final dropdown = find.byType(DropdownButtonFormField<ClimateZone>);
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text(climateLabel).last);
    await tester.pumpAndSettle();
  }

  final calculateBtn = find.widgetWithText(FilledButton, 'Calcular BTU');
  await tester.ensureVisible(calculateBtn);
  await tester.tap(calculateBtn);
  await tester.pumpAndSettle();
}

Future<void> _scrollToBottom(WidgetTester tester) async {
  final scrollables = find.byType(Scrollable);
  if (scrollables.evaluate().isEmpty) return;
  final scrollable = scrollables.first;
  for (var i = 0; i < 14; i++) {
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

typedef _BtuScenarioBuilder = Future<void> Function(
  WidgetTester tester, {
  double textScale,
  Size size,
});

final Map<String, _BtuScenarioBuilder> _scenarios = {
  'BtuCalculatorScreen · formulario inicial': _pumpBtu,
  'BtuCalculatorScreen · errores de validación':
      (tester, {textScale = 1, size = const Size(360, 800)}) async {
        await _pumpBtu(tester, textScale: textScale, size: size);
        final calculateBtn = find.widgetWithText(FilledButton, 'Calcular BTU');
        await tester.ensureVisible(calculateBtn);
        await tester.tap(calculateBtn);
        await tester.pumpAndSettle();
      },
  'BtuCalculatorScreen · resultado comercial sugerido (<= 36.000 BTU)':
      (tester, {textScale = 1, size = const Size(360, 800)}) async {
        await _pumpBtu(tester, textScale: textScale, size: size);
        await _enterAndCalculate(
          tester,
          length: '5',
          width: '5',
          height: '3.0',
          occupants: '4',
          equipment: '2',
          climateLabel: 'Cálido',
        );
      },
  'BtuCalculatorScreen · resultado superior a 36.000 BTU':
      (tester, {textScale = 1, size = const Size(360, 800)}) async {
        await _pumpBtu(tester, textScale: textScale, size: size);
        await _enterAndCalculate(
          tester,
          length: '12',
          width: '5',
          height: '2.5',
          occupants: '2',
          equipment: '1',
          climateLabel: 'Frío',
        );
      },
  'BtuCalculatorScreen · deshabilitada por configuración': (
    tester, {
    textScale = 1,
    size = const Size(360, 800),
  }) => _pumpBtu(tester, enabled: false, textScale: textScale, size: size),
};

void main() {
  group('TC-157 · RNF-067..076 · TechnicalTools · texto al 200 % sin desbordes', () {
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

  group(
    'TC-157 · RNF-067..076 · TechnicalTools · guías automáticas WCAG 2.2 AA',
    () {
      for (final entry in _scenarios.entries) {
        testWidgets(
          'TC-157 · RNF-067..076 · ${entry.key} · 4 guías de accesibilidad',
          (tester) async {
            final handle = tester.ensureSemantics();
            try {
              await entry.value(tester, size: const Size(360, 2000));
              await _expectAllGuidelines(tester);
            } finally {
              handle.dispose();
            }
          },
        );
      }
    },
  );

  group('TC-157 · RNF-067..076 · TechnicalTools · semántica de resultado y botones', () {
    testWidgets(
      'TC-157 · RNF-067..076 · BtuCalculatorScreen · resultado como encabezado y botones ≥ 48 dp',
      (tester) async {
        final handle = tester.ensureSemantics();
        try {
          await _scenarios['BtuCalculatorScreen · resultado comercial sugerido (<= 36.000 BTU)']!(
            tester,
            size: const Size(360, 2000),
          );

          expect(
            tester.getSemantics(find.text('Resultado estimado')),
            isSemantics(isHeader: true, label: 'Resultado estimado'),
          );
          expect(
            tester
                .getSize(find.widgetWithText(FilledButton, 'Calcular BTU'))
                .height,
            greaterThanOrEqualTo(48),
          );
          expect(
            tester
                .getSize(
                  find.ancestor(
                    of: find.text('Ver equipos'),
                    matching: find.bySubtype<FilledButton>(),
                  ),
                )
                .height,
            greaterThanOrEqualTo(48),
          );
        } finally {
          handle.dispose();
        }
      },
    );

    testWidgets(
      'TC-157 · RNF-067..076 · BtuCalculatorScreen · exceso >36.000 BTU muestra texto explicativo y botón asesor ≥ 48 dp',
      (tester) async {
        final handle = tester.ensureSemantics();
        try {
          await _scenarios['BtuCalculatorScreen · resultado superior a 36.000 BTU']!(
            tester,
            size: const Size(360, 2000),
          );

          expect(
            find.textContaining('Supera la capacidad máxima sugerible'),
            findsOneWidget,
          );
          expect(
            tester
                .getSize(
                  find.ancestor(
                    of: find.text('Contactar a un asesor'),
                    matching: find.bySubtype<FilledButton>(),
                  ),
                )
                .height,
            greaterThanOrEqualTo(48),
          );
        } finally {
          handle.dispose();
        }
      },
    );
  });
}
