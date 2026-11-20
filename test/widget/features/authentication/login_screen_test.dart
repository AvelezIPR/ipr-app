import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/core/session/session_controller.dart';
import 'package:ipr_mobile/core/session/session_state.dart';
import 'package:ipr_mobile/core/storage/secure_key_value.dart';
import 'package:ipr_mobile/shared/navigation/routes.dart';
import 'package:material_ui/material_ui.dart';

import '../../../unit/features/authentication/support/auth_fakes.dart';
import 'support/auth_widget_support.dart';

const credentialsError = 'Correo o contraseña incorrectos.';

Future<void> fillAndSubmit(
  WidgetTester tester, {
  String login = AuthSamples.login,
  String password = AuthSamples.password,
}) async {
  await type(tester, 'Correo o usuario', login);
  await type(tester, 'Contraseña', password);
  await submit(tester);
}

void main() {
  group('TC-009 · LoginScreen', () {
    testWidgets(
      'AC-040-3 · campos vacíos: error en cada campo y sin solicitud',
      (tester) async {
        final h = await pumpAuth(tester, start: Routes.login);
        await submit(tester);

        expect(find.text('Escribe tu correo o tu usuario.'), findsOneWidget);
        expect(find.text('Escribe tu contraseña.'), findsOneWidget);
        expect(h.repo.totalCalls, 0);

        await type(tester, 'Correo o usuario', AuthSamples.login);
        await submit(tester);
        expect(find.text('Escribe tu correo o tu usuario.'), findsNothing);
        expect(find.text('Escribe tu contraseña.'), findsOneWidget);
        expect(h.repo.totalCalls, 0);
      },
    );

    testWidgets(
      'AC-040-4 · doble toque: una sola solicitud y botón deshabilitado',
      (tester) async {
        final h = await pumpAuth(tester, start: Routes.login);
        await type(tester, 'Correo o usuario', AuthSamples.login);
        await type(tester, 'Contraseña', AuthSamples.password);

        await tapVisible(tester, submitButton);
        await tester.tap(submitButton, warnIfMissed: false);
        await tester.pump();

        expect(h.repo.loginCalls, hasLength(1));
        expect(isEnabled(tester, submitButton), isFalse);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // El usuario escrito llega al repositorio con la contraseña tal cual.
        final credentials = h.repo.loginCalls.single.$1;
        expect(credentials.login, AuthSamples.login);
        expect(credentials.password, AuthSamples.password);
      },
    );

    testWidgets(
      'AC-040-8 · mostrar/ocultar contraseña y se vuelve a enmascarar en segundo plano',
      (tester) async {
        await pumpAuth(tester, start: Routes.login);
        expect(isObscured(tester, 'Contraseña'), isTrue);

        await tester.tap(find.byTooltip('Mostrar contraseña'));
        await tester.pump();
        expect(isObscured(tester, 'Contraseña'), isFalse);
        expect(find.byTooltip('Ocultar contraseña'), findsOneWidget);

        await tester.tap(find.byTooltip('Ocultar contraseña'));
        await tester.pump();
        expect(isObscured(tester, 'Contraseña'), isTrue);

        // Visible → segundo plano → de vuelta: enmascarada.
        await tester.tap(find.byTooltip('Mostrar contraseña'));
        await tester.pump();
        expect(isObscured(tester, 'Contraseña'), isFalse);
        [
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
          AppLifecycleState.hidden,
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ].forEach(tester.binding.handleAppLifecycleStateChanged);
        await tester.pump();
        expect(isObscured(tester, 'Contraseña'), isTrue);
        expect(find.byTooltip('Mostrar contraseña'), findsOneWidget);
      },
    );

    testWidgets('AC-040-1 · éxito: setSession guarda la sesión', (
      tester,
    ) async {
      final h = await pumpAuth(
        tester,
        start: Routes.login,
        repo: FakeAuthRepository(autoLogin: Ok(fixtureSession())),
      );
      await fillAndSubmit(tester);
      await tester.pumpAndSettle();

      final state = h.container(tester).read(sessionControllerProvider);
      expect((state as SessionAuthenticated).userId, 4821);
      expect(h.session(tester).accessToken, fixtureTokens().accessToken);
      expect(find.text(credentialsError), findsNothing);
    });

    testWidgets(
      'AC-040-6 · AC-044-1 · tokens y contraseña NO quedan en disco ni en caché',
      (tester) async {
        final h = await pumpAuth(
          tester,
          start: Routes.login,
          repo: FakeAuthRepository(autoLogin: Ok(fixtureSession())),
        );
        await fillAndSubmit(tester, password: 'Qa-Clave-Unica-77');
        await tester.pumpAndSettle();

        final tokens = fixtureTokens();
        // Solo el refresh token, en el almacén seguro.
        expect(h.secure.data[SecureKeys.refreshToken], tokens.refreshToken);
        final everythingOnDisk = [
          ...h.secure.data.values,
          ...h.preferences.data.values.map((v) => '$v'),
        ].join('|');
        expect(everythingOnDisk, isNot(contains(tokens.accessToken)));
        expect(everythingOnDisk, isNot(contains('Qa-Clave-Unica-77')));
        expect(everythingOnDisk, isNot(contains(AuthSamples.login)));
        // Preferencias y caché pública: nada de la sesión.
        expect(h.preferences.data, isEmpty);
        expect(h.cache.length, 0);
      },
    );

    testWidgets(
      'TC-011 · AC-040-2 · AC-045-5 · el mismo mensaje ante cuenta inexistente, rol bloqueado o 403',
      (tester) async {
        for (final failure in <AppFailure>[
          const Unauthorized(code: 'invalid_credentials'),
          const Unauthorized(),
          const Forbidden(code: 'account_locked'),
        ]) {
          final h = await pumpAuth(
            tester,
            start: Routes.login,
            repo: FakeAuthRepository(autoLogin: Err(failure)),
          );
          await fillAndSubmit(tester, password: AuthSamples.wrongPassword);
          await tester.pump();

          expect(
            find.text(credentialsError),
            findsOneWidget,
            reason: '$failure',
          );
          expect(find.textContaining('existe'), findsNothing);
          expect(find.textContaining('bloquead'), findsNothing);
          expect(find.textContaining('administrador'), findsNothing);
          // La contraseña se limpia tras el rechazo y se conserva el usuario.
          expect(
            tester
                .widget<TextField>(fieldLabeled('Contraseña'))
                .controller!
                .text,
            isEmpty,
          );
          expect(
            tester
                .widget<TextField>(fieldLabeled('Correo o usuario'))
                .controller!
                .text,
            AuthSamples.login,
          );
          expect(h.session(tester).accessToken, isNull);
          await tester.pumpWidget(const SizedBox());
        }
      },
    );

    testWidgets(
      'TC-012 · AC-040-5 · sin red: mensaje de conexión (no credenciales) y usuario conservado',
      (tester) async {
        await pumpAuth(
          tester,
          start: Routes.login,
          repo: FakeAuthRepository(autoLogin: const Err(NoConnection())),
        );
        await fillAndSubmit(tester);
        await tester.pump();

        expect(
          find.text('No tienes conexión. Revisa tu internet.'),
          findsOneWidget,
        );
        expect(find.text(credentialsError), findsNothing);
        expect(
          tester
              .widget<TextField>(fieldLabeled('Correo o usuario'))
              .controller!
              .text,
          AuthSamples.login,
        );
        // Se puede reintentar de inmediato.
        expect(isEnabled(tester, submitButton), isTrue);
      },
    );

    testWidgets(
      'TC-030 · AC-045-1 · AC-045-7 · 429 con Retry-After: cuenta regresiva y botón deshabilitado',
      (tester) async {
        final h = await pumpAuth(
          tester,
          start: Routes.login,
          repo: FakeAuthRepository(
            autoLogin: const Err(RateLimited(retryAfter: 60)),
          ),
        );
        await fillAndSubmit(tester);
        await tester.pump();

        expect(
          find.text(
            'Demasiados intentos. Espera un momento antes de intentarlo de nuevo.',
          ),
          findsOneWidget,
        );
        expect(
          find.text('Podrás volver a intentarlo en 1:00.'),
          findsOneWidget,
        );
        expect(find.text('Disponible en 1:00'), findsOneWidget);
        expect(isEnabled(tester, submitButton), isFalse);
        // No revela nada de la cuenta.
        expect(find.textContaining('existe'), findsNothing);
        expect(find.text(credentialsError), findsNothing);

        await tester.pump(const Duration(seconds: 1));
        expect(
          find.text('Podrás volver a intentarlo en 0:59.'),
          findsOneWidget,
        );
        expect(isEnabled(tester, submitButton), isFalse);

        await tester.pump(const Duration(seconds: 58));
        expect(
          find.text('Podrás volver a intentarlo en 0:01.'),
          findsOneWidget,
        );
        expect(isEnabled(tester, submitButton), isFalse);
        // Tocar el botón deshabilitado no emite solicitud.
        await tester.tap(submitButton, warnIfMissed: false);
        expect(h.repo.loginCalls, hasLength(1));

        await tester.pump(const Duration(seconds: 1));
        expect(isEnabled(tester, submitButton), isTrue);
        expect(find.textContaining('Podrás volver'), findsNothing);
        expect(find.text('Iniciar sesión'), findsWidgets);
      },
    );

    testWidgets(
      'M2 · RF-045 · errores del servidor junto al campo que coincide',
      (tester) async {
        await pumpAuth(
          tester,
          start: Routes.login,
          repo: FakeAuthRepository(
            autoLogin: const Err(
              Validation(
                fields: [
                  FieldError(
                    field: 'login',
                    code: 'invalid',
                    message: 'Ese usuario no es válido.',
                  ),
                ],
              ),
            ),
          ),
        );
        await fillAndSubmit(tester);
        await tester.pump();

        final errorText = tester
            .widget<TextField>(fieldLabeled('Correo o usuario'))
            .decoration!
            .errorText;
        expect(errorText, 'Ese usuario no es válido.');
        expect(
          tester
              .widget<TextField>(fieldLabeled('Contraseña'))
              .decoration!
              .errorText,
          isNull,
        );
      },
    );

    testWidgets(
      'AC-044-5 · con la sesión terminada muestra el aviso con el carrito intacto',
      (tester) async {
        final h = await pumpAuth(tester, start: Routes.login);
        expect(find.textContaining('Tu sesión terminó'), findsNothing);
        await h.session(tester).expire();
        await tester.pump();
        expect(
          find.text(
            'Tu sesión terminó. Inicia sesión de nuevo. Tu carrito sigue igual.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'AC-042-1 · "¿Olvidaste tu contraseña?" es visible y abre la recuperación',
      (tester) async {
        await pumpAuth(tester, start: Routes.login);
        expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);
        await tapVisible(tester, find.text('¿Olvidaste tu contraseña?'));
        await tester.pumpAndSettle();
        expect(find.text('Recuperar contraseña'), findsWidgets);
        expect(find.text('Enviar enlace'), findsOneWidget);
      },
    );

    testWidgets(
      'M2 · enlaces a Registro (reemplaza la pantalla) y a documentos legales',
      (tester) async {
        final h = await pumpAuth(tester, start: '${Routes.login}?from=/orders');
        await tapVisible(tester, find.text('Términos y política de datos'));
        await tester.pumpAndSettle();
        expect(find.text('PANTALLA LEGAL'), findsOneWidget);
        h.router.pop();
        await tester.pumpAndSettle();

        await tapVisible(tester, find.text('¿No tienes cuenta? Regístrate'));
        await tester.pumpAndSettle();
        expect(find.text('Crear cuenta'), findsWidgets);
        // El origen se conserva al cambiar de pantalla.
        expect(
          h.router.state.uri.toString(),
          '${Routes.register}?from=%2Forders',
        );
      },
    );

    testWidgets(
      'M2 · sin destino previo, el botón de la barra lleva al inicio',
      (tester) async {
        final h = await pumpAuth(tester, start: Routes.login);
        h.router.go(Routes.login);
        await tester.pumpAndSettle();
        expect(find.byTooltip('Volver al inicio'), findsOneWidget);
        await tester.tap(find.byTooltip('Volver al inicio'));
        await tester.pumpAndSettle();
        expect(find.text('PANTALLA INICIO'), findsOneWidget);
      },
    );
  });

  group('RNF-073 · RF-040 · seguridad y accesibilidad del login', () {
    testWidgets(
      'SC-035 · protege la captura mientras está visible y la libera al salir',
      (tester) async {
        final h = await pumpAuth(tester, start: Routes.login);
        expect(h.protection.enabled, 1);
        expect(h.protection.disabled, 0);
        h.router.go(Routes.home);
        await tester.pumpAndSettle();
        expect(h.protection.disabled, 1);
      },
    );

    testWidgets('autofillHints correctos y AutofillGroup', (tester) async {
      await pumpAuth(tester, start: Routes.login);
      expect(find.byType(AutofillGroup), findsOneWidget);
      expect(
        tester
            .widget<TextField>(fieldLabeled('Correo o usuario'))
            .autofillHints,
        [AutofillHints.username, AutofillHints.email],
      );
      expect(
        tester.widget<TextField>(fieldLabeled('Contraseña')).autofillHints,
        [AutofillHints.password],
      );
      final password = tester.widget<TextField>(fieldLabeled('Contraseña'));
      expect(password.autocorrect, isFalse);
      expect(password.enableSuggestions, isFalse);
      expect(password.obscureText, isTrue);
      expect(password.textInputAction, TextInputAction.done);
      expect(
        tester
            .widget<TextField>(fieldLabeled('Correo o usuario'))
            .textInputAction,
        TextInputAction.next,
      );
    });

    testWidgets('al salir se limpian los campos de texto', (tester) async {
      await pumpAuth(tester, start: Routes.login);
      await type(tester, 'Correo o usuario', AuthSamples.login);
      await type(tester, 'Contraseña', AuthSamples.password);
      final controllers = [
        tester.widget<TextField>(fieldLabeled('Correo o usuario')).controller!,
        tester.widget<TextField>(fieldLabeled('Contraseña')).controller!,
      ];
      await tester.pumpWidget(const SizedBox());
      for (final controller in controllers) {
        expect(controller.text, isEmpty);
      }
    });

    testWidgets('texto al 200 %: sin desbordes y el botón se alcanza', (
      tester,
    ) async {
      await pumpAuth(
        tester,
        start: Routes.login,
        textScale: 2,
        size: const Size(360, 640),
      );
      expect(tester.takeException(), isNull);
      await tapVisible(tester, submitButton);
      expect(tester.takeException(), isNull);
      expect(find.text('Escribe tu correo o tu usuario.'), findsOneWidget);
    });

    testWidgets(
      'teclado abierto: el contenido sigue siendo desplazable hasta el botón',
      (tester) async {
        await pumpAuth(tester, start: Routes.login, size: const Size(360, 640));
        tester.view.viewInsets = const FakeViewPadding(bottom: 320);
        await tester.pump();
        expect(find.byType(SingleChildScrollView), findsWidgets);
        await tapVisible(tester, submitButton);
        expect(tester.takeException(), isNull);
        expect(find.text('Escribe tu contraseña.'), findsOneWidget);
      },
    );

    testWidgets(
      'guías de accesibilidad: objetivos táctiles, etiquetas y contraste',
      (tester) async {
        final handle = tester.ensureSemantics();
        await pumpAuth(tester, start: Routes.login);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      },
    );

    testWidgets('los errores se anuncian (liveRegion) y llevan ícono + texto', (
      tester,
    ) async {
      await pumpAuth(
        tester,
        start: Routes.login,
        repo: FakeAuthRepository(autoLogin: const Err(Unauthorized())),
      );
      await fillAndSubmit(tester);
      await tester.pump();

      expect(
        find.ancestor(
          of: find.text(credentialsError),
          matching: find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.liveRegion == true,
          ),
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });
}
