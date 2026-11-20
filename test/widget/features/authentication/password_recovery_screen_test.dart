import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/shared/navigation/routes.dart';
import 'package:material_ui/material_ui.dart';

import '../../../unit/features/authentication/support/auth_fakes.dart';
import 'support/auth_widget_support.dart';

const _email = 'Correo electrónico';
const _sentBody =
    'Si el correo está registrado, te enviamos un enlace para crear una nueva contraseña. Ábrelo desde tu correo para completar el cambio.';

Future<void> request(WidgetTester tester, String email) async {
  await type(tester, _email, email);
  await submit(tester);
}

void main() {
  group('TC-025 · PasswordRecoveryScreen', () {
    testWidgets('AC-042-1 · se abre desde el login y pide el correo', (
      tester,
    ) async {
      await pumpAuth(tester, start: Routes.login);
      await tapVisible(tester, find.text('¿Olvidaste tu contraseña?'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Escribe el correo de tu cuenta y te enviaremos un enlace para crear una nueva contraseña.',
        ),
        findsOneWidget,
      );
      expect(fieldLabeled(_email), findsOneWidget);
      expect(find.text('Enviar enlace'), findsOneWidget);
    });

    testWidgets('correo inválido o vacío: error en el campo y sin solicitud', (
      tester,
    ) async {
      final h = await pumpAuth(tester, start: Routes.passwordRecovery);
      await submit(tester);
      expect(find.text('Escribe tu correo electrónico.'), findsOneWidget);
      await request(tester, 'a@b');
      expect(
        find.text(
          'Revisa el correo: debe tener el formato nombre@dominio.com.',
        ),
        findsOneWidget,
      );
      expect(h.repo.totalCalls, 0);
    });

    testWidgets(
      'AC-042-8 · sin red: mensaje de conexión, sin avanzar y con el correo conservado',
      (tester) async {
        await pumpAuth(
          tester,
          start: Routes.passwordRecovery,
          repo: FakeAuthRepository(autoReset: const Err(NoConnection())),
        );
        await request(tester, AuthSamples.login);

        expect(
          find.text('No tienes conexión. Revisa tu internet.'),
          findsOneWidget,
        );
        expect(find.text('Revisa tu correo'), findsNothing);
        expect(
          tester.widget<TextField>(fieldLabeled(_email)).controller!.text,
          AuthSamples.login,
        );
        expect(isEnabled(tester, submitButton), isTrue);
      },
    );

    testWidgets('doble toque: una sola solicitud', (tester) async {
      final h = await pumpAuth(tester, start: Routes.passwordRecovery);
      await type(tester, _email, AuthSamples.login);
      await tapVisible(tester, submitButton);
      await tester.tap(submitButton, warnIfMissed: false);
      await tester.pump();
      expect(h.repo.resetCalls, hasLength(1));
      expect(isEnabled(tester, submitButton), isFalse);
    });
  });

  group('TC-026 · AC-042-4 · AC-045-5 · respuesta uniforme', () {
    testWidgets(
      'correo registrado y no registrado muestran EXACTAMENTE la misma confirmación',
      (tester) async {
        final screens = <List<String>>[];
        for (final email in [
          'qa.cliente.01@example.test',
          'qa.nadie@example.test',
        ]) {
          final h = await pumpAuth(
            tester,
            start: Routes.passwordRecovery,
            repo: FakeAuthRepository(autoReset: const Ok(null)),
          );
          await request(tester, email);
          await tester.pumpAndSettle();

          expect(h.repo.resetCalls.single.$1, email);
          screens.add([
            for (final text in tester.widgetList<Text>(find.byType(Text)))
              text.data ?? '',
          ]);
          expect(find.text('Revisa tu correo'), findsOneWidget);
          expect(find.text(_sentBody), findsOneWidget);
          // El correo escrito ya no aparece ni hay campo.
          expect(find.text(email), findsNothing);
          expect(fieldLabeled(_email), findsNothing);
          await tester.pumpWidget(const SizedBox());
        }
        expect(screens.first, screens.last);
      },
    );

    testWidgets(
      'la confirmación no promete nada sobre la cuenta ni las sesiones',
      (tester) async {
        await pumpAuth(
          tester,
          start: Routes.passwordRecovery,
          repo: FakeAuthRepository(autoReset: const Ok(null)),
        );
        await request(tester, AuthSamples.login);
        await tester.pumpAndSettle();
        expect(find.textContaining('sesiones'), findsNothing);
        expect(find.textContaining('no existe'), findsNothing);
        expect(find.text('Volver a iniciar sesión'), findsOneWidget);
      },
    );

    testWidgets('"Volver a iniciar sesión" regresa al login', (tester) async {
      final h = await pumpAuth(tester, start: Routes.login);
      await tapVisible(tester, find.text('¿Olvidaste tu contraseña?'));
      await tester.pumpAndSettle();
      h.repo.autoReset = const Ok(null);
      await request(tester, AuthSamples.login);
      await tester.pumpAndSettle();

      await tapVisible(tester, find.text('Volver a iniciar sesión'));
      await tester.pumpAndSettle();
      expect(h.router.state.uri.path, Routes.login);
    });

    testWidgets('sin pantalla previa, "Volver a iniciar sesión" va al login', (
      tester,
    ) async {
      final h = await pumpAuth(
        tester,
        start: Routes.passwordRecovery,
        repo: FakeAuthRepository(autoReset: const Ok(null)),
      );
      h.router.go(Routes.passwordRecovery);
      await tester.pumpAndSettle();
      await request(tester, AuthSamples.login);
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Volver a iniciar sesión'));
      await tester.pumpAndSettle();
      expect(h.router.state.uri.path, Routes.login);
    });
  });

  group('AC-042-5 · AC-045-1 · límites', () {
    testWidgets('429: espera con cuenta regresiva y botón deshabilitado', (
      tester,
    ) async {
      await pumpAuth(
        tester,
        start: Routes.passwordRecovery,
        repo: FakeAuthRepository(
          autoReset: const Err(RateLimited(retryAfter: 90)),
        ),
      );
      await request(tester, AuthSamples.login);

      expect(find.text('Podrás volver a intentarlo en 1:30.'), findsOneWidget);
      expect(isEnabled(tester, submitButton), isFalse);
      await tester.pump(const Duration(seconds: 90));
      expect(isEnabled(tester, submitButton), isTrue);
    });

    testWidgets('400 con errors[email]: mensaje junto al campo', (
      tester,
    ) async {
      await pumpAuth(
        tester,
        start: Routes.passwordRecovery,
        repo: FakeAuthRepository(
          autoReset: const Err(
            Validation(
              fields: [
                FieldError(
                  field: 'email',
                  code: 'x',
                  message: 'Correo no válido.',
                ),
              ],
            ),
          ),
        ),
      );
      await request(tester, AuthSamples.login);
      expect(
        tester.widget<TextField>(fieldLabeled(_email)).decoration!.errorText,
        'Correo no válido.',
      );
    });
  });

  group('RNF-073 · PasswordRecoveryScreen · seguridad y accesibilidad', () {
    testWidgets('SC-035 · protege la captura mientras está visible', (
      tester,
    ) async {
      final h = await pumpAuth(tester, start: Routes.passwordRecovery);
      expect(h.protection.enabled, 1);
      h.router.go(Routes.home);
      await tester.pumpAndSettle();
      expect(h.protection.disabled, 1);
    });

    testWidgets('autofillHints, teclado de correo y limpieza al salir', (
      tester,
    ) async {
      await pumpAuth(tester, start: Routes.passwordRecovery);
      final field = tester.widget<TextField>(fieldLabeled(_email));
      expect(field.autofillHints, [AutofillHints.email]);
      expect(field.keyboardType, TextInputType.emailAddress);
      expect(field.textInputAction, TextInputAction.done);
      expect(find.byType(AutofillGroup), findsOneWidget);

      await type(tester, _email, AuthSamples.login);
      final controller = field.controller!;
      await tester.pumpWidget(const SizedBox());
      expect(controller.text, isEmpty);
    });

    testWidgets('texto al 200 %: formulario y confirmación sin desbordes', (
      tester,
    ) async {
      await pumpAuth(
        tester,
        start: Routes.passwordRecovery,
        textScale: 2,
        size: const Size(360, 640),
        repo: FakeAuthRepository(autoReset: const Ok(null)),
      );
      expect(tester.takeException(), isNull);
      await request(tester, AuthSamples.login);
      await tester.pumpAndSettle();
      expect(find.text('Revisa tu correo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'guías de accesibilidad en el formulario y en la confirmación',
      (tester) async {
        final handle = tester.ensureSemantics();
        await pumpAuth(
          tester,
          start: Routes.passwordRecovery,
          repo: FakeAuthRepository(autoReset: const Ok(null)),
        );
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));

        await request(tester, AuthSamples.login);
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      },
    );

    testWidgets('la confirmación se anuncia a los lectores de pantalla', (
      tester,
    ) async {
      await pumpAuth(
        tester,
        start: Routes.passwordRecovery,
        repo: FakeAuthRepository(autoReset: const Ok(null)),
      );
      await request(tester, AuthSamples.login);
      await tester.pumpAndSettle();
      expect(
        find.ancestor(
          of: find.text('Revisa tu correo'),
          matching: find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.liveRegion == true,
          ),
        ),
        findsOneWidget,
      );
    });
  });
}
