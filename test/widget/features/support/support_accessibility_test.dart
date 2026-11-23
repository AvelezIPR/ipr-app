import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ipr_mobile/core/config/remote_config.dart';
import 'package:ipr_mobile/core/config/remote_config_controller.dart';
import 'package:ipr_mobile/core/config/remote_config_repository.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/external/secure_browser.dart';
import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/core/providers.dart';
import 'package:ipr_mobile/features/support/support.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/ipr_localizations.dart';
import 'package:ipr_mobile/shared/design_system/ipr_theme.dart';
import 'package:ipr_mobile/shared/navigation/routes.dart';
import 'package:material_ui/material_ui.dart';

import '../../../mocks/test_providers.dart';

final class _FakeSecureBrowser implements SecureBrowser {
  new({this.result = true});

  final bool result;

  @override
  Future<bool> open(Uri url) async => result;
}

final class _StubPqrsRepo implements PqrsRepository {
  new({this.result});

  final Result<PqrsReceipt>? result;

  @override
  Future<Result<PqrsReceipt>> submit({
    required PqrsSubmission submission,
    required String idempotencyKey,
    RequestCancellation? cancel,
  }) async =>
      result ??
      Ok(PqrsReceipt(status: 'received', receivedAt: DateTime.utc(2026)));
}

const _fullConfig = RemoteConfig(
  pqrsEnabled: true,
  whatsappNumber: '573000000000',
  phoneDisplay: '(604) 0000001',
  phoneDial: '+576040000001',
  salesEmail: 'ventas@example.invalid',
  engineeringWhatsapp: '573000000099',
  engineeringEmail: 'ingenieria@example.invalid',
  termsVersion: '2026-01',
  termsUrl: 'https://staging.invalid/terminos',
  privacyPolicyVersion: '2026-02',
  privacyPolicyUrl: 'https://staging.invalid/privacidad',
  dataRightsUrl: 'https://staging.invalid/derechos',
  dataRightsEmail: 'datos@staging.invalid',
  accountDeletionNotice: 'Aviso sintético de eliminación de cuenta.',
);

const _minimalConfig = RemoteConfig(whatsappNumber: '573000000000');

Future<void> _pumpSupport(
  WidgetTester tester, {
  required String initialLocation,
  RemoteConfig config = _fullConfig,
  _StubPqrsRepo? pqrsRepo,
  SecureBrowser? browser,
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
      GoRoute(path: Routes.support, builder: (_, _) => const HelpScreen()),
      GoRoute(
        path: Routes.engineering,
        builder: (_, _) => const EngineeringScreen(),
      ),
      GoRoute(path: Routes.pqrs, builder: (_, _) => const PqrsScreen()),
      GoRoute(path: Routes.legal, builder: (_, _) => const LegalScreen()),
      GoRoute(
        path: Routes.branches,
        builder: (_, _) => const Scaffold(body: Text('DESTINO_SEDES')),
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
              config: config,
              source: RemoteConfigSource.network,
            ),
          ),
          secureBrowserProvider.overrideWithValue(
            browser ?? _FakeSecureBrowser(),
          ),
          if (pqrsRepo != null)
            pqrsRepositoryProvider.overrideWithValue(pqrsRepo),
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

Future<void> _fillValidPqrs(WidgetTester tester) async {
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), 'Ana Prueba');
  await tester.enterText(fields.at(1), 'ana.prueba@example.invalid');
  await tester.enterText(fields.at(2), '3000000001');
  await tester.enterText(fields.at(3), 'QA-1001');
  await tester.enterText(fields.at(4), 'Consulta sintética de accesibilidad.');
  await tester.ensureVisible(find.byType(CheckboxListTile));
  await tester.tap(find.byType(CheckboxListTile));
  await tester.pumpAndSettle();
}

Future<void> _scrollToBottom(WidgetTester tester) async {
  final scrollables = find.byType(Scrollable);
  if (scrollables.evaluate().isEmpty) return;
  final scrollable = scrollables.last;
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

typedef _SupportScenarioBuilder = Future<void> Function(
  WidgetTester tester, {
  double textScale,
  Size size,
});

final Map<String, _SupportScenarioBuilder> _scenarios = {
  'HelpScreen · canales completos':
      (tester, {textScale = 1, size = const Size(360, 800)}) => _pumpSupport(
        tester,
        initialLocation: Routes.support,
        textScale: textScale,
        size: size,
      ),
  'HelpScreen · sin canales opcionales':
      (tester, {textScale = 1, size = const Size(360, 800)}) => _pumpSupport(
        tester,
        initialLocation: Routes.support,
        config: _minimalConfig,
        textScale: textScale,
        size: size,
      ),
  'EngineeringScreen · canales completos':
      (tester, {textScale = 1, size = const Size(360, 800)}) => _pumpSupport(
        tester,
        initialLocation: Routes.engineering,
        textScale: textScale,
        size: size,
      ),
  'EngineeringScreen · canales mínimos':
      (tester, {textScale = 1, size = const Size(360, 800)}) => _pumpSupport(
        tester,
        initialLocation: Routes.engineering,
        config: _minimalConfig,
        textScale: textScale,
        size: size,
      ),
  'PqrsScreen · formulario inicial':
      (tester, {textScale = 1, size = const Size(360, 800)}) => _pumpSupport(
        tester,
        initialLocation: Routes.pqrs,
        pqrsRepo: _StubPqrsRepo(),
        textScale: textScale,
        size: size,
      ),
  'PqrsScreen · errores de validación':
      (tester, {textScale = 1, size = const Size(360, 800)}) async {
        await _pumpSupport(
          tester,
          initialLocation: Routes.pqrs,
          pqrsRepo: _StubPqrsRepo(),
          textScale: textScale,
          size: size,
        );
        final submit = find.text('Enviar solicitud');
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();
      },
  'PqrsScreen · envío confirmado (recibo visible)':
      (tester, {textScale = 1, size = const Size(360, 800)}) async {
        await _pumpSupport(
          tester,
          initialLocation: Routes.pqrs,
          pqrsRepo: _StubPqrsRepo(),
          textScale: textScale,
          size: size,
        );
        await _fillValidPqrs(tester);
        final submit = find.text('Enviar solicitud');
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();
      },
  'PqrsScreen · fallo 429 conservando datos':
      (tester, {textScale = 1, size = const Size(360, 800)}) async {
        await _pumpSupport(
          tester,
          initialLocation: Routes.pqrs,
          pqrsRepo: _StubPqrsRepo(
            result: const Err(RateLimited(retryAfter: 60)),
          ),
          textScale: textScale,
          size: size,
        );
        await _fillValidPqrs(tester);
        final submit = find.text('Enviar solicitud');
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();
      },
  'PqrsScreen · deshabilitado por /config':
      (tester, {textScale = 1, size = const Size(360, 800)}) => _pumpSupport(
        tester,
        initialLocation: Routes.pqrs,
        config: _minimalConfig,
        textScale: textScale,
        size: size,
      ),
  'LegalScreen · con documentos publicados':
      (tester, {textScale = 1, size = const Size(360, 800)}) => _pumpSupport(
        tester,
        initialLocation: Routes.legal,
        textScale: textScale,
        size: size,
      ),
  'LegalScreen · sin documentos publicados':
      (tester, {textScale = 1, size = const Size(360, 800)}) => _pumpSupport(
        tester,
        initialLocation: Routes.legal,
        config: _minimalConfig,
        textScale: textScale,
        size: size,
      ),
  'LegalScreen · diálogo de fallo al abrir':
      (tester, {textScale = 1, size = const Size(360, 800)}) async {
        await _pumpSupport(
          tester,
          initialLocation: Routes.legal,
          browser: _FakeSecureBrowser(result: false),
          textScale: textScale,
          size: size,
        );
        await tester.tap(find.text('Términos y condiciones'));
        await tester.pumpAndSettle();
      },
};

void main() {
  group('TC-157 · RNF-067..076 · Support · texto al 200 % sin desbordes', () {
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

  group('TC-157 · RNF-067..076 · Support · guías automáticas WCAG 2.2 AA', () {
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
  });

  group(
    'TC-157 · RNF-067..076 · Support · semántica de encabezados y enlaces',
    () {
      testWidgets(
        'TC-157 · RNF-067..076 · HelpScreen y EngineeringScreen · encabezados semánticos y objetivos ≥ 48 dp',
        (tester) async {
          final handle = tester.ensureSemantics();
          try {
            await _scenarios['HelpScreen · canales completos']!(
              tester,
              size: const Size(360, 1600),
            );
            expect(
              tester.getSemantics(find.text('Canales de atención')),
              isSemantics(isHeader: true, label: 'Canales de atención'),
            );

            await _scenarios['EngineeringScreen · canales completos']!(
              tester,
              size: const Size(360, 1600),
            );
            expect(
              tester.getSemantics(
                find.text('Canales corporativos de ingeniería'),
              ),
              isSemantics(
                isHeader: true,
                label: 'Canales corporativos de ingeniería',
              ),
            );
          } finally {
            handle.dispose();
          }
        },
      );

      testWidgets(
        'TC-157 · RNF-067..076 · PqrsScreen · contador, enlace de política ≥ 48 dp y recibo anunciado',
        (tester) async {
          final handle = tester.ensureSemantics();
          try {
            await _scenarios['PqrsScreen · envío confirmado (recibo visible)']!(
              tester,
              size: const Size(360, 2000),
            );
            expect(find.text('0/1000'), findsOneWidget);
            expect(find.text('Solicitud enviada'), findsOneWidget);
            expect(
              tester
                  .getSize(
                    find.ancestor(
                      of: find.text(
                        'Consultar política de tratamiento de datos',
                      ),
                      matching: find.bySubtype<TextButton>(),
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
        'TC-157 · RNF-067..076 · LegalScreen · documento anuncia versión y que se abre fuera',
        (tester) async {
          final handle = tester.ensureSemantics();
          try {
            await _scenarios['LegalScreen · con documentos publicados']!(
              tester,
              size: const Size(360, 1600),
            );
            expect(
              tester.getSemantics(find.text('Términos y condiciones')),
              isSemantics(
                label: 'Términos y condiciones\nVersión 2026-01',
                hint: 'Se abre en el navegador',
                isButton: true,
              ),
            );
            expect(
              tester.getSemantics(find.text('Eliminación de cuenta')),
              isSemantics(isHeader: true, label: 'Eliminación de cuenta'),
            );
          } finally {
            handle.dispose();
          }
        },
      );
    },
  );
}
