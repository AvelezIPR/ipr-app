import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/config/remote_config.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/core/session/session_controller.dart';
import 'package:ipr_mobile/core/session/session_state.dart';
import 'package:ipr_mobile/shared/navigation/routes.dart';
import 'package:material_ui/material_ui.dart';

import '../../../unit/features/authentication/support/auth_fakes.dart';
import 'support/auth_widget_support.dart';

const _acceptanceLabel =
    'Acepto los términos y condiciones y la política de tratamiento de datos.';
const _passwordLabel = 'Contraseña (mínimo 8 caracteres)';
const _confirmLabel = 'Confirmar contraseña';
const _neutralNotice =
    'No pudimos completar el registro con estos datos. Si ya tienes una cuenta, inicia sesión o recupera tu contraseña.';

Future<void> fillValid(
  WidgetTester tester, {
  String email = AuthSamples.email,
  String password = AuthSamples.password,
  String? confirm,
  bool accept = true,
}) async {
  await type(tester, 'Nombres', 'Cliente');
  await type(tester, 'Apellidos', 'Prueba');
  await type(tester, 'Correo electrónico', email);
  await type(tester, _passwordLabel, password);
  await type(tester, _confirmLabel, confirm ?? password);
  if (accept) await tapVisible(tester, find.text(_acceptanceLabel));
}

bool checked(WidgetTester tester) =>
    tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value ??
    false;

void main() {
  group('TC-002 · RegisterScreen · campos y consentimiento', () {
    testWidgets(
      'AC-038-1 · AC-039-1 · pide nombres, apellidos, correo, contraseña y confirmación; casilla sin marcar con enlaces',
      (tester) async {
        await pumpAuth(tester, start: Routes.register);

        for (final label in [
          'Nombres',
          'Apellidos',
          'Correo electrónico',
          _passwordLabel,
          _confirmLabel,
        ]) {
          expect(fieldLabeled(label), findsOneWidget, reason: label);
        }
        expect(isObscured(tester, _passwordLabel), isTrue);
        expect(isObscured(tester, _confirmLabel), isTrue);
        expect(find.byTooltip('Mostrar contraseña'), findsNWidgets(2));

        expect(checked(tester), isFalse);
        expect(find.text('Leer los términos y condiciones'), findsOneWidget);
        expect(
          find.text('Leer la política de tratamiento de datos'),
          findsOneWidget,
        );
        expect(find.text('Registrarme'), findsOneWidget);
      },
    );

    testWidgets(
      'AC-039-2 · sin marcar la casilla no se envía y se explica por qué',
      (tester) async {
        final h = await pumpAuth(tester, start: Routes.register);
        await fillValid(tester, accept: false);
        await submit(tester);

        expect(h.repo.totalCalls, 0);
        expect(
          find.text(
            'Debes aceptar los términos y la política de tratamiento de datos para continuar.',
          ),
          findsOneWidget,
        );
        // Marcarla quita el aviso y habilita el envío.
        await tapVisible(tester, find.text(_acceptanceLabel));
        expect(checked(tester), isTrue);
      },
    );

    testWidgets(
      'AC-039-1 · los enlaces abren los documentos y el formulario conserva lo escrito',
      (tester) async {
        final h = await pumpAuth(tester, start: Routes.register);
        await fillValid(tester, accept: false);

        await tapVisible(tester, find.text('Leer los términos y condiciones'));
        await tester.pumpAndSettle();
        expect(find.text('PANTALLA LEGAL'), findsOneWidget);
        h.router.pop();
        await tester.pumpAndSettle();

        await tapVisible(
          tester,
          find.text('Leer la política de tratamiento de datos'),
        );
        await tester.pumpAndSettle();
        expect(find.text('PANTALLA LEGAL'), findsOneWidget);
        h.router.pop();
        await tester.pumpAndSettle();

        expect(
          tester.widget<TextField>(fieldLabeled('Nombres')).controller!.text,
          'Cliente',
        );
        expect(
          tester
              .widget<TextField>(fieldLabeled('Correo electrónico'))
              .controller!
              .text,
          AuthSamples.email,
        );
        expect(
          tester
              .widget<TextField>(fieldLabeled(_passwordLabel))
              .controller!
              .text,
          AuthSamples.password,
        );
      },
    );
  });

  group('TC-001 · RegisterScreen · validaciones', () {
    testWidgets(
      'AC-038-3 · campos vacíos: un error por campo y 0 solicitudes',
      (tester) async {
        final h = await pumpAuth(tester, start: Routes.register);
        await submit(tester);

        expect(find.text('Escribe tus nombres.'), findsOneWidget);
        expect(find.text('Escribe tus apellidos.'), findsOneWidget);
        expect(find.text('Escribe tu correo electrónico.'), findsOneWidget);
        expect(find.text('Crea una contraseña.'), findsOneWidget);
        expect(
          find.text('Repite la contraseña para confirmarla.'),
          findsOneWidget,
        );
        expect(find.textContaining('Debes aceptar'), findsOneWidget);
        expect(h.repo.totalCalls, 0);
      },
    );

    testWidgets(
      'AC-038-2 · AC-038-3 · contraseña de 7, correo inválido y confirmación distinta',
      (tester) async {
        final h = await pumpAuth(tester, start: Routes.register);
        await fillValid(
          tester,
          email: 'a@b',
          password: 'Qa12345',
          confirm: 'Qa12346',
        );
        await submit(tester);

        expect(
          find.text('La contraseña debe tener al menos 8 caracteres.'),
          findsOneWidget,
        );
        expect(
          find.text(
            'Revisa el correo: debe tener el formato nombre@dominio.com.',
          ),
          findsOneWidget,
        );
        expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
        expect(h.repo.totalCalls, 0);
      },
    );

    testWidgets('AC-038-2 · con 8 caracteres la contraseña se acepta', (
      tester,
    ) async {
      final h = await pumpAuth(tester, start: Routes.register);
      await fillValid(tester);
      await submit(tester);
      expect(
        find.text('La contraseña debe tener al menos 8 caracteres.'),
        findsNothing,
      );
      expect(h.repo.registerCalls, hasLength(1));
    });

    testWidgets('M2 · RF-045 · errores del servidor junto a cada campo', (
      tester,
    ) async {
      await pumpAuth(
        tester,
        start: Routes.register,
        repo: FakeAuthRepository(
          autoRegister: const Err(
            Validation(
              fields: [
                FieldError(
                  field: 'email',
                  code: 'invalid_email',
                  message: 'El correo no es válido.',
                ),
                FieldError(
                  field: 'password',
                  code: 'too_common',
                  message: 'Esa contraseña es muy común.',
                ),
              ],
            ),
          ),
        ),
      );
      await fillValid(tester);
      await submit(tester);

      expect(
        tester
            .widget<TextField>(fieldLabeled('Correo electrónico'))
            .decoration!
            .errorText,
        'El correo no es válido.',
      );
      expect(
        tester
            .widget<TextField>(fieldLabeled(_passwordLabel))
            .decoration!
            .errorText,
        'Esa contraseña es muy común.',
      );
      expect(
        tester.widget<TextField>(fieldLabeled('Nombres')).decoration!.errorText,
        isNull,
      );
    });
  });

  group('TC-005 · RegisterScreen · envío', () {
    testWidgets(
      'AC-038-4 · AC-039-3 · registro válido: acceptance con las versiones de /config y sesión guardada',
      (tester) async {
        final h = await pumpAuth(
          tester,
          start: Routes.register,
          repo: FakeAuthRepository(
            autoRegister: Ok(fixtureSession(userId: 90)),
          ),
          config: const RemoteConfig(
            termsVersion: 'T-3',
            privacyPolicyVersion: 'P-4',
          ),
        );
        await fillValid(tester);
        await submit(tester);
        await tester.pumpAndSettle();

        final request = h.repo.registerCalls.single.$1;
        expect(request.acceptance.termsVersion, 'T-3');
        expect(request.acceptance.privacyPolicyVersion, 'P-4');
        expect(request.email, AuthSamples.email);
        final state = h.container(tester).read(sessionControllerProvider);
        expect((state as SessionAuthenticated).userId, 90);
        expect(h.session(tester).accessToken, fixtureTokens().accessToken);
        expect(h.preferences.data, isEmpty);
        expect(h.cache.length, 0);
      },
    );

    testWidgets(
      'AC-038-6 · TC-003 · doble toque: una sola solicitud y botón deshabilitado',
      (tester) async {
        final h = await pumpAuth(tester, start: Routes.register);
        await fillValid(tester);
        await tapVisible(tester, submitButton);
        await tester.tap(submitButton, warnIfMissed: false);
        await tester.pump();

        expect(h.repo.registerCalls, hasLength(1));
        expect(isEnabled(tester, submitButton), isFalse);
      },
    );

    testWidgets(
      'AC-038-7 · TC-004 · sin red: mensaje de conexión y se conserva lo escrito',
      (tester) async {
        await pumpAuth(
          tester,
          start: Routes.register,
          repo: FakeAuthRepository(autoRegister: const Err(NoConnection())),
        );
        await fillValid(tester);
        await submit(tester);

        expect(
          find.text('No tienes conexión. Revisa tu internet.'),
          findsOneWidget,
        );
        expect(
          tester.widget<TextField>(fieldLabeled('Nombres')).controller!.text,
          'Cliente',
        );
        expect(
          tester.widget<TextField>(fieldLabeled('Apellidos')).controller!.text,
          'Prueba',
        );
        expect(
          tester
              .widget<TextField>(fieldLabeled('Correo electrónico'))
              .controller!
              .text,
          AuthSamples.email,
        );
        expect(checked(tester), isTrue);
        expect(isEnabled(tester, submitButton), isTrue);
      },
    );

    testWidgets('AC-045-1 · 429: cuenta regresiva y botón deshabilitado', (
      tester,
    ) async {
      await pumpAuth(
        tester,
        start: Routes.register,
        repo: FakeAuthRepository(
          autoRegister: const Err(RateLimited(retryAfter: 30)),
        ),
      );
      await fillValid(tester);
      await submit(tester);

      expect(find.text('Podrás volver a intentarlo en 0:30.'), findsOneWidget);
      expect(find.text('Disponible en 0:30'), findsOneWidget);
      expect(isEnabled(tester, submitButton), isFalse);
      await tester.pump(const Duration(seconds: 30));
      expect(isEnabled(tester, submitButton), isTrue);
    });
  });

  group('TC-007 · AC-038-5 · conflicto de cuenta (H-03 pendiente)', () {
    testWidgets(
      '409 muestra un aviso NEUTRAL con Iniciar sesión y Recuperar contraseña',
      (tester) async {
        await pumpAuth(
          tester,
          start: Routes.register,
          repo: FakeAuthRepository(
            autoRegister: const Err(Conflict(code: 'email_in_use')),
          ),
        );
        await fillValid(tester);
        await submit(tester);

        expect(find.text(_neutralNotice), findsOneWidget);
        // No confirma que la cuenta exista.
        expect(find.textContaining('ya existe'), findsNothing);
        expect(find.textContaining('ya está registrado'), findsNothing);
        expect(find.textContaining('en uso'), findsNothing);
        expect(find.text('Iniciar sesión'), findsOneWidget);
        expect(find.text('Recuperar contraseña'), findsOneWidget);
        // Y no se pierde lo escrito.
        expect(
          tester
              .widget<TextField>(fieldLabeled('Correo electrónico'))
              .controller!
              .text,
          AuthSamples.email,
        );
      },
    );

    testWidgets('el aviso es el mismo sea cual sea el code del 409', (
      tester,
    ) async {
      for (final code in ['email_in_use', 'conflict']) {
        await pumpAuth(
          tester,
          start: Routes.register,
          repo: FakeAuthRepository(autoRegister: Err(Conflict(code: code))),
        );
        await fillValid(tester);
        await submit(tester);
        expect(find.text(_neutralNotice), findsOneWidget, reason: code);
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('las acciones del aviso llevan al login y a la recuperación', (
      tester,
    ) async {
      final h = await pumpAuth(
        tester,
        start: '${Routes.register}?from=/orders',
        repo: FakeAuthRepository(
          autoRegister: const Err(Conflict(code: 'email_in_use')),
        ),
      );
      await fillValid(tester);
      await submit(tester);

      await tapVisible(
        tester,
        find.widgetWithText(TextButton, 'Recuperar contraseña'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Enviar enlace'), findsOneWidget);
      h.router.pop();
      await tester.pumpAndSettle();

      await tapVisible(
        tester,
        find.widgetWithText(TextButton, 'Iniciar sesión'),
      );
      await tester.pumpAndSettle();
      expect(h.router.state.uri.toString(), '${Routes.login}?from=%2Forders');
    });
  });

  group('AC-039-4 · RegisterScreen · falla cerrado sin versiones legales', () {
    testWidgets(
      'sin versiones: se explica, el botón queda deshabilitado y no se envía',
      (tester) async {
        final h = await pumpAuth(
          tester,
          start: Routes.register,
          config: const RemoteConfig(),
        );
        await fillValid(tester);

        expect(
          find.textContaining('No podemos crear la cuenta ahora'),
          findsOneWidget,
        );
        expect(isEnabled(tester, submitButton), isFalse);
        await tester.tap(submitButton, warnIfMissed: false);
        await tester.pump();
        expect(h.repo.totalCalls, 0);
      },
    );

    testWidgets(
      'AC-039-5 · "Reintentar" recarga la configuración y habilita el registro',
      (tester) async {
        final h = await pumpAuth(
          tester,
          start: Routes.register,
          config: const RemoteConfig(),
        );
        h.remoteConfig.onRefresh = legalConfig;
        await tapVisible(tester, find.widgetWithText(TextButton, 'Reintentar'));
        await tester.pump();

        expect(h.remoteConfig.refreshes, 1);
        expect(
          find.textContaining('No podemos crear la cuenta ahora'),
          findsNothing,
        );
        expect(isEnabled(tester, submitButton), isTrue);
      },
    );

    testWidgets('con versiones no aparece el aviso', (tester) async {
      await pumpAuth(tester, start: Routes.register);
      expect(
        find.textContaining('No podemos crear la cuenta ahora'),
        findsNothing,
      );
    });
  });

  group('M2 · RegisterScreen · navegación y datos escritos', () {
    testWidgets('"¿Ya tienes cuenta? Inicia sesión" reemplaza la pantalla', (
      tester,
    ) async {
      final h = await pumpAuth(tester, start: Routes.register);
      await tapVisible(tester, find.text('¿Ya tienes cuenta? Inicia sesión'));
      await tester.pumpAndSettle();
      expect(h.router.state.uri.path, Routes.login);
    });

    testWidgets('sin datos escritos se sale sin preguntar', (tester) async {
      await pumpAuth(tester, start: Routes.register);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('PANTALLA INICIO'), findsOneWidget);
    });

    testWidgets(
      'con datos escritos pide confirmar; "Seguir editando" conserva todo',
      (tester) async {
        await pumpAuth(tester, start: Routes.register);
        await type(tester, 'Nombres', 'Cliente');
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();

        expect(find.text('¿Descartar los cambios?'), findsOneWidget);
        await tester.tap(find.text('Seguir editando'));
        await tester.pumpAndSettle();
        expect(find.text('¿Descartar los cambios?'), findsNothing);
        expect(find.text('Crear cuenta'), findsWidgets);
        expect(
          tester.widget<TextField>(fieldLabeled('Nombres')).controller!.text,
          'Cliente',
        );
      },
    );

    testWidgets('con datos escritos, "Descartar" sale', (tester) async {
      await pumpAuth(tester, start: Routes.register);
      await type(tester, 'Nombres', 'Cliente');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Descartar'));
      await tester.pumpAndSettle();
      expect(find.text('PANTALLA INICIO'), findsOneWidget);
    });
  });

  group('RNF-073 · RegisterScreen · seguridad y accesibilidad', () {
    testWidgets('SC-035 · protege la captura mientras está visible', (
      tester,
    ) async {
      final h = await pumpAuth(tester, start: Routes.register);
      expect(h.protection.enabled, 1);
      h.router.go(Routes.home);
      await tester.pumpAndSettle();
      expect(h.protection.disabled, 1);
    });

    testWidgets('autofillHints correctos y contraseñas enmascaradas', (
      tester,
    ) async {
      await pumpAuth(tester, start: Routes.register);
      List<String>? hints(String label) =>
          tester.widget<TextField>(fieldLabeled(label)).autofillHints?.toList();
      expect(hints('Nombres'), [AutofillHints.givenName]);
      expect(hints('Apellidos'), [AutofillHints.familyName]);
      expect(hints('Correo electrónico'), [AutofillHints.email]);
      expect(hints(_passwordLabel), [AutofillHints.newPassword]);
      expect(hints(_confirmLabel), [AutofillHints.newPassword]);
      expect(find.byType(AutofillGroup), findsOneWidget);
      expect(
        tester
            .widget<TextField>(fieldLabeled('Correo electrónico'))
            .keyboardType,
        TextInputType.emailAddress,
      );
      expect(
        tester.widget<TextField>(fieldLabeled('Nombres')).textInputAction,
        TextInputAction.next,
      );
    });

    testWidgets(
      'AC-040-8 · la contraseña visible se enmascara al ir a segundo plano',
      (tester) async {
        await pumpAuth(tester, start: Routes.register);
        await tester.tap(find.byTooltip('Mostrar contraseña').first);
        await tester.pump();
        expect(isObscured(tester, _passwordLabel), isFalse);
        [
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
        ].forEach(tester.binding.handleAppLifecycleStateChanged);
        await tester.pump();
        expect(isObscured(tester, _passwordLabel), isTrue);
      },
    );

    testWidgets('al salir se limpian los campos de texto', (tester) async {
      await pumpAuth(tester, start: Routes.register);
      await fillValid(tester, accept: false);
      final controllers = [
        for (final label in [
          'Nombres',
          'Apellidos',
          'Correo electrónico',
          _passwordLabel,
          _confirmLabel,
        ])
          tester.widget<TextField>(fieldLabeled(label)).controller!,
      ];
      await tester.pumpWidget(const SizedBox());
      for (final controller in controllers) {
        expect(controller.text, isEmpty);
      }
    });

    testWidgets('texto al 200 %: sin desbordes y todo es alcanzable', (
      tester,
    ) async {
      await pumpAuth(
        tester,
        start: Routes.register,
        textScale: 2,
        size: const Size(360, 640),
      );
      expect(tester.takeException(), isNull);
      await submit(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Escribe tus nombres.'), findsOneWidget);
      await tapVisible(tester, find.text('¿Ya tienes cuenta? Inicia sesión'));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'con aviso de documentos no disponibles a 200 % tampoco desborda',
      (tester) async {
        await pumpAuth(
          tester,
          start: Routes.register,
          textScale: 2,
          size: const Size(360, 640),
          config: const RemoteConfig(),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'guías de accesibilidad: objetivos táctiles, etiquetas y contraste',
      (tester) async {
        final handle = tester.ensureSemantics();
        await pumpAuth(tester, start: Routes.register);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      },
    );

    testWidgets('guías de accesibilidad con errores visibles', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpAuth(tester, start: Routes.register);
      await submit(tester);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });

    testWidgets('el error de aceptación se anuncia y lleva ícono + texto', (
      tester,
    ) async {
      await pumpAuth(tester, start: Routes.register);
      await submit(tester);
      final message = find.text(
        'Debes aceptar los términos y la política de tratamiento de datos para continuar.',
      );
      expect(
        find.ancestor(
          of: message,
          matching: find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.liveRegion == true,
          ),
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.error_outline), findsWidgets);
    });
  });
}
