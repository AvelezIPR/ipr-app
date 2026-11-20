import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/core/session/session_controller.dart';
import 'package:ipr_mobile/core/session/session_state.dart';
import 'package:ipr_mobile/core/session/token_store.dart';
import 'package:ipr_mobile/features/profile/presentation/controllers/logout_controller.dart';
import 'package:ipr_mobile/shared/widgets/state_widgets.dart';
import 'package:material_ui/material_ui.dart';

import '../../../mocks/fake_session_remote.dart';
import 'account_harness.dart';

Finder _buttonWith(String label) => find.ancestor(
  of: find.text(label),
  matching: find.bySubtype<OutlinedButton>(),
);

Finder get _logoutButton => _buttonWith('Cerrar sesión');

void main() {
  group('M2 · RF-037 · pestaña Cuenta como invitado', () {
    testWidgets('mientras se lee el almacén seguro muestra "Cargando"', (
      tester,
    ) async {
      await pumpAccount(tester);
      expect(find.byType(LoadingState), findsOneWidget);
      expect(find.text('Iniciar sesión'), findsNothing);
      expect(find.text('Cerrar sesión'), findsNothing);
    });

    testWidgets(
      'explica, ofrece iniciar sesión y crear cuenta, legales y WhatsApp',
      (tester) async {
        final env = await pumpAccount(tester);
        await env.signedOut();
        await tester.pump();

        expect(find.text('Inicia sesión o crea tu cuenta'), findsOneWidget);
        expect(find.textContaining('sin cuenta'), findsOneWidget);
        expect(find.text('Iniciar sesión'), findsOneWidget);
        expect(find.text('Crear cuenta'), findsOneWidget);
        expect(find.text('Términos y política de datos'), findsOneWidget);
        expect(find.text('Asesoría por WhatsApp'), findsOneWidget);
        // Nada de la cuenta de un cliente.
        expect(find.text('Cerrar sesión'), findsNothing);
        expect(find.text('Mis pedidos'), findsNothing);
        expect(find.text('Eliminar cuenta'), findsNothing);
      },
    );

    testWidgets('"Iniciar sesión" abre el login', (tester) async {
      final env = await pumpAccount(tester);
      await env.signedOut();
      await tester.pump();
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();
      expect(destinationOf(tester), '/login');
    });

    testWidgets('"Crear cuenta" abre el registro', (tester) async {
      final env = await pumpAccount(tester);
      await env.signedOut();
      await tester.pump();
      await tester.tap(find.text('Crear cuenta'));
      await tester.pumpAndSettle();
      expect(destinationOf(tester), '/register');
    });

    testWidgets(
      'TC-132 · AC-099-2 · los legales son accesibles desde Cuenta sin sesión',
      (tester) async {
        final env = await pumpAccount(tester);
        await env.signedOut();
        await tester.pump();
        await tester.tap(find.text('Términos y política de datos'));
        await tester.pumpAndSettle();
        expect(destinationOf(tester), '/support/legal');
      },
    );

    testWidgets(
      'M2 · RF-064 · WhatsApp abre wa.me con el mensaje de asesoría',
      (tester) async {
        final env = await pumpAccount(tester);
        await env.signedOut();
        await tester.pump();
        await tester.ensureVisible(find.text('Asesoría por WhatsApp'));
        await tester.tap(find.text('Asesoría por WhatsApp'));
        await tester.pump();
        expect(env.launcher.opened, hasLength(1));
        expect(env.launcher.opened.single.host, 'wa.me');
        expect(
          env.launcher.opened.single.queryParameters['text'],
          contains('asesoría'),
        );
      },
    );

    testWidgets(
      'M2 · RF-044 · con la sesión expirada vuelve a invitado y lo explica',
      (tester) async {
        final env = await pumpAccount(tester);
        await env.signIn();
        await tester.pump();
        await env.session.expire();
        await tester.pump();

        expect(find.text('Iniciar sesión'), findsOneWidget);
        expect(
          find.text('Tu sesión terminó. Inicia sesión de nuevo.'),
          findsOneWidget,
        );
        expect(find.text('Cerrar sesión'), findsNothing);
      },
    );
  });

  group('M2 · RF-037 · pestaña Cuenta con sesión', () {
    testWidgets('muestra "Sesión iniciada" y los accesos de M4', (
      tester,
    ) async {
      final env = await pumpAccount(tester);
      await env.signIn();
      await tester.pump();

      expect(find.text('Sesión iniciada'), findsOneWidget);
      for (final label in [
        'Mis pedidos',
        'Mis datos',
        'Direcciones',
        'Eliminar cuenta',
        'Términos y política de datos',
        'Cerrar sesión',
      ]) {
        await tester.ensureVisible(find.text(label));
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('Iniciar sesión'), findsNothing);
      expect(find.text('Crear cuenta'), findsNothing);
    });

    for (final (label, route) in const [
      ('Mis pedidos', '/orders'),
      ('Mis datos', '/account/profile'),
      ('Direcciones', '/account/addresses'),
      ('Derechos sobre mis datos', '/account/data-rights'),
      ('Eliminar cuenta', '/account/delete'),
      ('Términos y política de datos', '/support/legal'),
    ]) {
      testWidgets('"$label" navega a $route', (tester) async {
        final env = await pumpAccount(tester);
        await env.signIn();
        await tester.pump();
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(destinationOf(tester), route);
      });
    }

    testWidgets(
      'M2 · RF-104 · no llama a /me ni a ningún endpoint ni muestra datos '
      'personales (el perfil es de M4)',
      (tester) async {
        final env = await pumpAccount(tester);
        await env.signIn(userId: 987654);
        await tester.pump();
        await tester.pump();

        expect(env.adapter.requests, isEmpty);
        expect(find.textContaining('987654'), findsNothing);
        expect(find.textContaining('@'), findsNothing);
        // Ningún texto de la pantalla trae dígitos de teléfono o documento.
        final allText = tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data ?? '')
            .join(' ');
        expect(RegExp(r'\d{5,}').hasMatch(allText), isFalse);
      },
    );
  });

  group('RF-041 · cerrar sesión', () {
    testWidgets(
      'TC-014 · AC-041-1 · AC-041-7 · revoca con el token del dispositivo, '
      'avisa y queda en modo invitado',
      (tester) async {
        final remote = FakeSessionRemote();
        final env = await pumpAccount(tester, remote: remote);
        await env.signIn();
        await tester.pump();

        await tester.ensureVisible(_logoutButton);
        await tester.tap(_logoutButton);
        await tester.pump();
        await tester.pump();

        expect(remote.logoutCalls, hasLength(1));
        expect(remote.logoutCalls.single.accessToken, 'ipra_a');
        expect(
          env.container.read(sessionControllerProvider),
          isA<SessionAnonymous>(),
        );
        expect(find.text('Sesión cerrada'), findsOneWidget);
        expect(find.text('Iniciar sesión'), findsOneWidget);
        expect(find.text('Cerrar sesión'), findsNothing);
        expect(
          await TokenStore(env.secure).readRefreshToken(),
          isNull,
          reason: 'AC-041-3: no quedan tokens',
        );
      },
    );

    testWidgets(
      'TC-014 · AC-041-8 · dos toques seguidos emiten una sola revocación',
      (tester) async {
        final gate = Completer<void>();
        final remote = GatedSessionRemote(logoutGate: gate.future);
        final env = await pumpAccount(tester, remote: remote);
        await env.signIn();
        await tester.pump();

        await tester.ensureVisible(_logoutButton);
        await tester.tap(_logoutButton);
        // Segundo toque antes de que la pantalla se reconstruya.
        await tester.tap(_logoutButton, warnIfMissed: false);
        await tester.pump();

        // En curso: botón deshabilitado y texto de progreso.
        expect(find.text('Cerrando sesión'), findsOneWidget);
        expect(
          tester
              .widget<OutlinedButton>(_buttonWith('Cerrando sesión'))
              .onPressed,
          isNull,
        );
        expect(remote.logoutCalls, hasLength(1));

        gate.complete();
        await tester.pump();
        await tester.pump();
        expect(remote.logoutCalls, hasLength(1));
        expect(find.text('Sesión cerrada'), findsOneWidget);
      },
    );

    testWidgets('TC-015 · AC-041-6 · sin red no bloquea: sesión local cerrada, '
        'revocación pendiente y aviso', (tester) async {
      final remote = GatedSessionRemote(
        logoutResult: const Err(NoConnection()),
      );
      final env = await pumpAccount(tester, remote: remote);
      await env.signIn();
      await tester.pump();

      await tester.ensureVisible(_logoutButton);
      await tester.tap(_logoutButton);
      await tester.pump();
      await tester.pump();

      expect(
        env.container.read(sessionControllerProvider),
        isA<SessionAnonymous>(),
        reason: 'el usuario no queda con la sesión abierta sin saberlo',
      );
      expect(find.text('Sesión cerrada'), findsOneWidget);
      expect(find.text('Iniciar sesión'), findsOneWidget);
      expect(await TokenStore(env.secure).readRefreshToken(), isNull);
      expect(
        await TokenStore(env.secure).readPendingRevocation(),
        'iprr_a',
        reason: 'CR-039: se revocará al recuperar la red',
      );
    });

    testWidgets(
      'M2 · RF-041 · si el cierre falla localmente avisa y conserva la sesión',
      (tester) async {
        final remote = GatedSessionRemote(logoutThrows: true);
        final env = await pumpAccount(tester, remote: remote);
        await env.signIn();
        await tester.pump();

        await tester.ensureVisible(_logoutButton);
        await tester.tap(_logoutButton);
        await tester.pump();
        await tester.pump();

        expect(
          find.text('No pudimos cerrar la sesión. Intenta de nuevo.'),
          findsOneWidget,
        );
        expect(
          env.container.read(sessionControllerProvider),
          isA<SessionAuthenticated>(),
        );
        // El botón vuelve a estar disponible para reintentar.
        expect(
          tester.widget<OutlinedButton>(_logoutButton).onPressed,
          isNotNull,
        );
      },
    );

    testWidgets(
      'M2 · RF-041 · el controlador ignora una segunda llamada en curso',
      (tester) async {
        final gate = Completer<void>();
        final env = await pumpAccount(
          tester,
          remote: GatedSessionRemote(logoutGate: gate.future),
        );
        await env.signIn();
        await tester.pump();
        final controller = env.container.read(
          logoutControllerProvider.notifier,
        );
        final first = controller.logout();
        final second = await controller.logout();
        expect(second, LogoutOutcome.ignored);
        gate.complete();
        expect(await first, LogoutOutcome.done);
        expect(env.container.read(logoutControllerProvider), isFalse);
      },
    );
  });

  group('M2 · RNF · accesibilidad de la pestaña Cuenta', () {
    for (final signedIn in [false, true]) {
      final mode = signedIn ? 'con sesión' : 'invitado';

      testWidgets('las 4 guías de accesibilidad ($mode)', (tester) async {
        final handle = tester.ensureSemantics();
        final env = await pumpAccount(tester);
        signedIn ? await env.signIn() : await env.signedOut();
        await tester.pump();

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });

      testWidgets('texto al 200 % sin desbordar y todo alcanzable ($mode)', (
        tester,
      ) async {
        final env = await pumpAccount(tester, textScale: 2);
        signedIn ? await env.signIn() : await env.signedOut();
        await tester.pump();

        final last = signedIn
            ? _logoutButton
            : find.text('Asesoría por WhatsApp');
        await tester.scrollUntilVisible(
          last,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(last, findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('encabezados y botones con semántica en español', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final env = await pumpAccount(tester);
      await env.signedOut();
      await tester.pump();

      expect(
        tester.getSemantics(find.text('Inicia sesión o crea tu cuenta')),
        isSemantics(label: 'Inicia sesión o crea tu cuenta', isHeader: true),
      );
      expect(
        tester.getSemantics(find.text('Iniciar sesión')),
        isSemantics(
          label: 'Iniciar sesión',
          isButton: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });
  });
}
