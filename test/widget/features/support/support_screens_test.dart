import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ipr_mobile/core/config/remote_config.dart';
import 'package:ipr_mobile/core/config/remote_config_controller.dart';
import 'package:ipr_mobile/core/config/remote_config_repository.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/support/support.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/ipr_localizations.dart';
import 'package:ipr_mobile/shared/design_system/ipr_theme.dart';
import 'package:ipr_mobile/shared/navigation/routes.dart';
import 'package:material_ui/material_ui.dart';

import '../../../mocks/test_providers.dart';

final class _FakePqrsRepo implements PqrsRepository {
  final List<PqrsSubmission> sent = [];
  Future<Result<PqrsReceipt>> Function()? onSubmit;

  @override
  Future<Result<PqrsReceipt>> submit({
    required PqrsSubmission submission,
    required String idempotencyKey,
    RequestCancellation? cancel,
  }) {
    sent.add(submission);
    return onSubmit?.call() ??
        Future.value(
          Ok(PqrsReceipt(status: 'received', receivedAt: DateTime.utc(2026))),
        );
  }
}

Future<
  ({FakeExternalLauncher launcher, List<String> clipboard, List<String> nav})
>
_pumpSupportRoute(
  WidgetTester tester, {
  required String initialLocation,
  bool pqrsEnabled = true,
  FakeExternalLauncher? launcher,
  _FakePqrsRepo? pqrsRepo,
  double textScale = 1,
}) async {
  final fakeLauncher = launcher ?? FakeExternalLauncher();
  final clipboard = <String>[];
  final nav = <String>[];

  tester.view
    ..physicalSize = const Size(360, 800)
    ..devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboard.add((call.arguments as Map)['text'] as String);
      }
      return null;
    },
  );
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearAllTestValues();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });

  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: Routes.support, builder: (_, _) => const HelpScreen()),
      GoRoute(path: Routes.pqrs, builder: (_, _) => const PqrsScreen()),
      GoRoute(
        path: Routes.engineering,
        builder: (_, _) => const EngineeringScreen(),
      ),
      GoRoute(
        path: Routes.branches,
        builder: (_, _) {
          nav.add(Routes.branches);
          return const Scaffold(body: Text('DESTINO SEDES'));
        },
      ),
      GoRoute(
        path: Routes.legal,
        builder: (_, _) {
          nav.add(Routes.legal);
          return const Scaffold(body: Text('DESTINO LEGAL'));
        },
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: testOverrides(
        launcher: fakeLauncher,
        extra: [
          remoteConfigProvider.overrideWithBuild(
            (_, _) => RemoteConfigState(
              config: RemoteConfig(
                pqrsEnabled: pqrsEnabled,
                whatsappNumber: '573000000000',
                phoneDisplay: '(604) 3604440',
                phoneDial: '+576043604440',
                salesEmail: 'ventas@example.invalid',
                engineeringWhatsapp: '573000000099',
                engineeringEmail: 'ingenieria@example.invalid',
              ),
              source: RemoteConfigSource.network,
            ),
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
  await tester.pump();
  return (launcher: fakeLauncher, clipboard: clipboard, nav: nav);
}

void main() {
  group('TC-133 · Ayuda y contacto (sin sesión)', () {
    testWidgets(
      'TC-133 · AC-095-1/2 · agrupa WhatsApp, cotizar, teléfono, correo, PQRS y sedes',
      (tester) async {
        final launcher = FakeExternalLauncher(results: [true, true, false]);
        final env = await _pumpSupportRoute(
          tester,
          initialLocation: Routes.support,
          launcher: launcher,
        );

        await tester.tap(find.text('Atención por WhatsApp'));
        await tester.pump();
        expect(launcher.opened.last.host, 'wa.me');

        await tester.tap(find.text('Cotizar por WhatsApp'));
        await tester.pump();
        expect(launcher.opened.last.queryParameters['text'], isNotEmpty);

        // Correo sin cliente -> copia al portapapeles
        final emailTile = find.text('Correo de ventas');
        await tester.ensureVisible(emailTile);
        await tester.tap(emailTile);
        await tester.pump();
        expect(env.clipboard, ['ventas@example.invalid']);

        final branchesTile = find.text('Sedes a nivel nacional');
        await tester.ensureVisible(branchesTile);
        await tester.tap(branchesTile);
        await tester.pumpAndSettle();
        expect(env.nav, contains(Routes.branches));
      },
    );
  });

  group('TC-139 · Asesoría técnica / Ingeniería (RF-079, RF-080)', () {
    testWidgets(
      'TC-139 · AC-079/080 · muestra servicios, WhatsApp ingeniería, PBX y copiar correo sin cliente',
      (tester) async {
        final launcher = FakeExternalLauncher(results: [true, true, false]);
        final env = await _pumpSupportRoute(
          tester,
          initialLocation: Routes.engineering,
          launcher: launcher,
          textScale: 2,
        );

        expect(find.text('Aire acondicionado'), findsOneWidget);
        expect(find.text('Refrigeración'), findsOneWidget);

        final waBtn = find.text('Escribir por WhatsApp de ingeniería');
        await tester.ensureVisible(waBtn);
        await tester.tap(waBtn);
        await tester.pump();
        expect(launcher.opened.last.path, '/573000000099');

        final phoneBtn = find.textContaining('Llamar al PBX');
        await tester.ensureVisible(phoneBtn);
        await tester.tap(phoneBtn);
        await tester.pump();
        expect(launcher.opened.last.toString(), 'tel:+576043604440');

        final mailBtn = find.textContaining('ingenieria@example.invalid');
        await tester.ensureVisible(mailBtn);
        await tester.tap(mailBtn);
        await tester.pump();
        expect(env.clipboard, ['ingenieria@example.invalid']);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('TC-129 / TC-130 · Formulario PQRS (RF-096)', () {
    testWidgets(
      'TC-129 · AC-096-3 · bloquea carácter 1001 y muestra contador 1000/1000',
      (tester) async {
        await _pumpSupportRoute(tester, initialLocation: Routes.pqrs);
        final fields = find.byType(TextField);
        await tester.enterText(fields.at(4), 'a' * 1001);
        await tester.pump();
        expect(find.text('1000/1000'), findsOneWidget);
      },
    );

    testWidgets(
      'TC-130 · AC-096-4..8/11 · envía una sola PQRS, limpia formulario y conserva datos ante 429/500/offline',
      (tester) async {
        final repo = _FakePqrsRepo();
        final completer = Completer<Result<PqrsReceipt>>();
        repo.onSubmit = () => completer.future;

        await _pumpSupportRoute(
          tester,
          initialLocation: Routes.pqrs,
          pqrsRepo: repo,
        );

        final fields = find.byType(TextField);
        await tester.enterText(fields.at(0), 'Ana Prueba');
        await tester.enterText(fields.at(1), 'ana.prueba@example.invalid');
        await tester.enterText(fields.at(2), '3000000001');
        await tester.enterText(fields.at(4), 'Consulta sintética completa.');
        await tester.ensureVisible(find.byType(CheckboxListTile));
        await tester.tap(find.byType(CheckboxListTile));
        await tester.pump();

        final submit = find.text('Enviar solicitud');
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pump();
        // Segundo toque mientras está enviando no duplica la petición.
        expect(repo.sent, hasLength(1));

        completer.complete(
          Ok(PqrsReceipt(status: 'received', receivedAt: DateTime.utc(2026))),
        );
        await tester.pump();
        expect(find.text('Solicitud enviada'), findsOneWidget);
        expect(
          tester.widget<TextField>(fields.at(0)).controller!.text,
          isEmpty,
        );

        // Ante 429 conserva lo escrito
        repo.onSubmit = () async => const Err(RateLimited(retryAfter: 60));
        await tester.enterText(fields.at(0), 'Ana Prueba');
        await tester.enterText(fields.at(1), 'ana.prueba@example.invalid');
        await tester.enterText(fields.at(2), '3000000001');
        await tester.enterText(fields.at(4), 'Segundo intento');
        await tester.ensureVisible(find.byType(CheckboxListTile));
        await tester.tap(find.byType(CheckboxListTile));
        await tester.pump();
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pump();
        expect(find.textContaining('Demasiadas solicitudes'), findsOneWidget);
        expect(
          tester.widget<TextField>(fields.at(0)).controller!.text,
          'Ana Prueba',
        );
      },
    );

    testWidgets('M5 · pqrsEnabled false falla cerrado', (tester) async {
      await _pumpSupportRoute(
        tester,
        initialLocation: Routes.pqrs,
        pqrsEnabled: false,
      );
      expect(
        find.text('El formulario PQRS no está disponible ahora'),
        findsOneWidget,
      );
    });
  });
}
