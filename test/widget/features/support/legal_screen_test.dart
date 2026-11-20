import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/config/remote_config.dart';
import 'package:ipr_mobile/features/support/support.dart';
import 'package:material_ui/material_ui.dart';

import '../../../mocks/fake_http_adapter.dart';
import '../../../mocks/pump_app.dart';
import '../../../mocks/test_providers.dart';
import '../../../unit/features/support/support_fakes.dart';

/// Dobles y registros de una prueba de la pantalla legal.
class LegalEnv {
  new({
    required this.browser,
    required this.launcher,
    required this.adapter,
    required this.clipboard,
  });

  final FakeSecureBrowser browser;
  final FakeExternalLauncher launcher;
  final FakeHttpAdapter adapter;
  final List<String> clipboard;
}

Future<LegalEnv> pumpLegal(
  WidgetTester tester, {
  RemoteConfig config = fullLegalConfig,
  FakeSecureBrowser? browser,
  FakeExternalLauncher? launcher,
  FakeHttpAdapter? adapter,
  double textScale = 1,
}) async {
  final env = LegalEnv(
    browser: browser ?? FakeSecureBrowser(),
    launcher: launcher ?? FakeExternalLauncher(),
    adapter: adapter ?? FakeHttpAdapter(),
    clipboard: [],
  );
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        env.clipboard.add((call.arguments as Map)['text'] as String);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  // Sin override de sesión: la pantalla no puede depender de ella (RF-099).
  await pumpApp(
    tester,
    const LegalScreen(),
    textScale: textScale,
    overrides: supportOverrides(
      config: config,
      adapter: env.adapter,
      browser: env.browser,
      launcher: env.launcher,
    ),
  );
  return env;
}

void main() {
  group('RF-099 · documentos legales publicados', () {
    testWidgets(
      'TC-132 · AC-099-2 · lista términos, política y derechos con su versión, '
      'sin sesión',
      (tester) async {
        await pumpLegal(tester);

        expect(find.text('Información legal'), findsOneWidget);
        expect(find.text('Términos y condiciones'), findsOneWidget);
        expect(find.text('Versión 2026-01'), findsOneWidget);
        expect(
          find.text('Política de tratamiento de datos personales'),
          findsOneWidget,
        );
        expect(find.text('Versión 2026-02'), findsOneWidget);
        expect(find.text('Escribir a datos@staging.invalid'), findsOneWidget);
        expect(
          find.text('Los documentos legales no están disponibles por ahora'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'AC-099-7 · términos se abren en el navegador seguro (https, sin WebView)',
      (tester) async {
        final env = await pumpLegal(tester);
        await tester.tap(find.text('Términos y condiciones'));
        await tester.pump();

        expect(
          env.browser.opened.single.toString(),
          'https://$legalHost/terminos',
        );
        expect(env.launcher.opened, isEmpty);
        expect(find.byType(AlertDialog), findsNothing);
      },
    );

    testWidgets('la política de datos abre su propia URL', (tester) async {
      final env = await pumpLegal(tester);
      await tester.tap(
        find.text('Política de tratamiento de datos personales'),
      );
      await tester.pump();
      expect(
        env.browser.opened.single.toString(),
        'https://$legalHost/privacidad',
      );
    });

    testWidgets('canal de derechos con URL y correo muestra las dos filas', (
      tester,
    ) async {
      final env = await pumpLegal(
        tester,
        config: const RemoteConfig(
          dataRightsUrl: 'https://$legalHost/derechos',
          dataRightsEmail: 'datos@$legalHost',
        ),
      );
      expect(find.text('Derechos sobre tus datos personales'), findsOneWidget);
      expect(find.text('Escribir a datos@staging.invalid'), findsOneWidget);
      await tester.tap(find.text('Derechos sobre tus datos personales'));
      await tester.pump();
      expect(env.browser.opened.single.path, '/derechos');
    });

    testWidgets('canal de derechos solo con URL no muestra fila de correo', (
      tester,
    ) async {
      await pumpLegal(
        tester,
        config: const RemoteConfig(dataRightsUrl: 'https://$legalHost/d'),
      );
      expect(find.text('Derechos sobre tus datos personales'), findsOneWidget);
      expect(find.textContaining('Escribir a'), findsNothing);
    });

    testWidgets('un documento sin versión no inventa una', (tester) async {
      await pumpLegal(
        tester,
        config: const RemoteConfig(termsUrl: 'https://$legalHost/t'),
      );
      expect(find.text('Términos y condiciones'), findsOneWidget);
      expect(find.textContaining('Versión'), findsNothing);
      expect(
        find.text('Política de tratamiento de datos personales'),
        findsNothing,
      );
    });

    testWidgets(
      'el aviso de eliminación de cuenta se muestra como texto plano',
      (tester) async {
        await pumpLegal(
          tester,
          config: fullLegalConfig.copyWith(
            accountDeletionNotice: 'Se borra <b>todo</b> en 30 días.',
          ),
        );
        expect(find.text('Eliminación de cuenta'), findsOneWidget);
        expect(find.text('Se borra <b>todo</b> en 30 días.'), findsOneWidget);
      },
    );

    testWidgets('sin aviso no hay sección de eliminación', (tester) async {
      await pumpLegal(tester);
      expect(find.text('Eliminación de cuenta'), findsNothing);
    });
  });

  group('RF-099 · el documento no se puede abrir (nunca en silencio)', () {
    testWidgets(
      'AC-099-5 · el navegador no abre: mensaje claro y alternativa de ayuda',
      (tester) async {
        final env = await pumpLegal(
          tester,
          browser: FakeSecureBrowser(result: false),
        );
        await tester.tap(find.text('Términos y condiciones'));
        await tester.pumpAndSettle();

        expect(find.text('No pudimos abrir el documento'), findsOneWidget);
        expect(find.textContaining('Revisa tu conexión'), findsOneWidget);
        expect(find.text('Pedir ayuda por WhatsApp'), findsOneWidget);
        expect(find.text('Copiar correo'), findsOneWidget);
        expect(env.browser.opened, hasLength(1));

        await tester.tap(find.text('Cerrar'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
      },
    );

    testWidgets('una excepción del navegador también se informa', (
      tester,
    ) async {
      await pumpLegal(tester, browser: FakeSecureBrowser(throws: true));
      await tester.tap(find.text('Términos y condiciones'));
      await tester.pumpAndSettle();
      expect(find.text('No pudimos abrir el documento'), findsOneWidget);
    });

    testWidgets('AC-099-7 · host no permitido: no se abre y se explica', (
      tester,
    ) async {
      final env = await pumpLegal(
        tester,
        config: const RemoteConfig(
          termsVersion: '1',
          termsUrl: 'https://evil.example/terminos',
        ),
      );
      await tester.tap(find.text('Términos y condiciones'));
      await tester.pumpAndSettle();

      expect(env.browser.opened, isEmpty);
      expect(find.text('No pudimos abrir el documento'), findsOneWidget);
      expect(
        find.textContaining('no está disponible en la app por ahora'),
        findsOneWidget,
      );
      expect(find.text('Pedir ayuda por WhatsApp'), findsOneWidget);
    });

    testWidgets('http (no https) no se abre', (tester) async {
      final env = await pumpLegal(
        tester,
        config: const RemoteConfig(termsUrl: 'http://$legalHost/t'),
      );
      await tester.tap(find.text('Términos y condiciones'));
      await tester.pumpAndSettle();
      expect(env.browser.opened, isEmpty);
      expect(find.text('No pudimos abrir el documento'), findsOneWidget);
    });

    testWidgets(
      'URL ausente (solo versión): explica, sin correo no hay copiar',
      (tester) async {
        final env = await pumpLegal(
          tester,
          config: const RemoteConfig(termsVersion: '3'),
        );
        await tester.tap(find.text('Términos y condiciones'));
        await tester.pumpAndSettle();

        expect(env.browser.opened, isEmpty);
        expect(
          find.textContaining('no está disponible en la app por ahora'),
          findsOneWidget,
        );
        expect(find.text('Copiar correo'), findsNothing);
      },
    );

    testWidgets('la ayuda por WhatsApp del aviso abre wa.me con el mensaje', (
      tester,
    ) async {
      final env = await pumpLegal(
        tester,
        browser: FakeSecureBrowser(result: false),
      );
      await tester.tap(find.text('Términos y condiciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pedir ayuda por WhatsApp'));
      await tester.pump();

      expect(env.launcher.opened.single.host, 'wa.me');
      expect(
        env.launcher.opened.single.queryParameters['text'],
        contains('documento legal'),
      );
    });

    testWidgets('"Copiar correo" copia la dirección y avisa', (tester) async {
      final env = await pumpLegal(
        tester,
        browser: FakeSecureBrowser(result: false),
      );
      await tester.tap(find.text('Términos y condiciones'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copiar correo'));
      await tester.pumpAndSettle();

      expect(env.clipboard, ['datos@staging.invalid']);
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        find.text('Copiamos la dirección datos@staging.invalid.'),
        findsOneWidget,
      );
    });
  });

  group('RF-099 · correo del canal de derechos', () {
    testWidgets('abre el cliente de correo si el sistema lo permite', (
      tester,
    ) async {
      final env = await pumpLegal(tester);
      await tester.tap(find.text('Escribir a datos@staging.invalid'));
      await tester.pump();
      expect(
        env.launcher.opened.single.toString(),
        'mailto:datos@staging.invalid',
      );
      expect(env.clipboard, isEmpty);
    });

    testWidgets(
      'si no se puede abrir (la política de core no permite mailto) copia la '
      'dirección y lo dice',
      (tester) async {
        final env = await pumpLegal(
          tester,
          launcher: FakeExternalLauncher(result: false),
        );
        await tester.tap(find.text('Escribir a datos@staging.invalid'));
        await tester.pumpAndSettle();

        expect(env.clipboard, ['datos@staging.invalid']);
        expect(
          find.text('Copiamos la dirección datos@staging.invalid.'),
          findsOneWidget,
        );
      },
    );
  });

  group('RF-099 · sin documentos publicados (falla cerrado)', () {
    const empty = RemoteConfig(whatsappNumber: '573014021882');

    testWidgets(
      'explica que no están disponibles y ofrece Reintentar y WhatsApp',
      (tester) async {
        final env = await pumpLegal(tester, config: empty);

        expect(
          find.text('Los documentos legales no están disponibles por ahora'),
          findsOneWidget,
        );
        expect(find.text('Reintentar'), findsOneWidget);
        expect(find.text('Pedir ayuda por WhatsApp'), findsOneWidget);
        expect(find.text('Términos y condiciones'), findsNothing);
        expect(env.browser.opened, isEmpty);
      },
    );

    testWidgets('Reintentar vuelve a pedir /config y muestra los documentos', (
      tester,
    ) async {
      final adapter = FakeHttpAdapter([
        (_) => FakeHttpAdapter.json(configBody()),
      ]);
      await pumpLegal(tester, config: empty, adapter: adapter);

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(adapter.requests.single.path, '/config');
      expect(find.text('Términos y condiciones'), findsOneWidget);
      expect(find.text('Versión 2026-01'), findsOneWidget);
      expect(find.text('Reintentar'), findsNothing);
      // El aviso de eliminación llega con la misma respuesta.
      expect(
        find.text('Tu cuenta se elimina de forma permanente.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'si sigue sin haber documentos, avisa y deja reintentar de nuevo',
      (tester) async {
        final adapter = FakeHttpAdapter()
          ..fallback = (_) =>
              FakeHttpAdapter.problem(503, 'service_unavailable');
        await pumpLegal(tester, config: empty, adapter: adapter);

        await tester.tap(find.text('Reintentar'));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Todavía no están disponibles. Revisa tu conexión e intenta de nuevo.',
          ),
          findsOneWidget,
        );
        expect(find.text('Reintentar'), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(
                find.ancestor(
                  of: find.text('Reintentar'),
                  matching: find.bySubtype<FilledButton>(),
                ),
              )
              .onPressed,
          isNotNull,
        );
      },
    );

    testWidgets('mientras reintenta el botón queda deshabilitado', (
      tester,
    ) async {
      final gate = Completer<void>();
      final adapter = FakeHttpAdapter([
        (_) async {
          await gate.future;
          return FakeHttpAdapter.json(configBody());
        },
      ]);
      await pumpLegal(tester, config: empty, adapter: adapter);

      await tester.tap(find.text('Reintentar'));
      await tester.pump();

      expect(find.text('Reintentar'), findsNothing);
      final loadingButton = find.ancestor(
        of: find.text('Cargando'),
        matching: find.bySubtype<FilledButton>(),
      );
      expect(tester.widget<FilledButton>(loadingButton).onPressed, isNull);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Términos y condiciones'), findsOneWidget);
    });

    testWidgets(
      'el aviso de eliminación sigue visible aunque no haya documentos',
      (tester) async {
        await pumpLegal(
          tester,
          config: empty.copyWith(accountDeletionNotice: 'Aviso de borrado.'),
        );
        expect(find.text('Aviso de borrado.'), findsOneWidget);
      },
    );
  });

  group('RNF · accesibilidad de los documentos legales', () {
    final states = <String, RemoteConfig>{
      'con documentos': fullLegalConfig,
      'sin documentos': const RemoteConfig(whatsappNumber: '573014021882'),
    };

    for (final MapEntry(key: name, value: config) in states.entries) {
      testWidgets('las 4 guías de accesibilidad ($name)', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpLegal(tester, config: config);

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });

      testWidgets('texto al 200 % sin desbordar ($name)', (tester) async {
        await pumpLegal(tester, config: config, textScale: 2);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        // El contenido completo es alcanzable desplazando.
        final last = name == 'con documentos'
            ? find.text('Escribir a datos@staging.invalid')
            : find.text('Pedir ayuda por WhatsApp');
        await tester.scrollUntilVisible(
          last,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(last, findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('el aviso de error cumple las guías y el 200 %', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpLegal(
        tester,
        browser: FakeSecureBrowser(result: false),
        textScale: 2,
      );
      await tester.tap(find.text('Términos y condiciones'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });

    testWidgets('cada documento anuncia título, versión y que abre fuera', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpLegal(tester);
      expect(
        tester.getSemantics(find.text('Términos y condiciones')),
        isSemantics(
          label: 'Términos y condiciones\nVersión 2026-01',
          hint: 'Se abre en el navegador',
          isButton: true,
        ),
      );
      handle.dispose();
    });
  });
}
