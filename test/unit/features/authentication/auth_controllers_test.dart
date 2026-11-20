import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/config/remote_config.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/core/session/session_controller.dart';
import 'package:ipr_mobile/core/session/session_state.dart';
import 'package:ipr_mobile/core/storage/secure_key_value.dart';
import 'package:ipr_mobile/features/authentication/domain/entities/registration.dart';
import 'package:ipr_mobile/features/authentication/domain/rules/auth_validation.dart';
import 'package:ipr_mobile/features/authentication/presentation/controllers/auth_form_controller.dart';
import 'package:ipr_mobile/features/authentication/presentation/controllers/auth_form_state.dart';
import 'package:ipr_mobile/features/authentication/presentation/controllers/login_controller.dart';
import 'package:ipr_mobile/features/authentication/presentation/controllers/password_recovery_controller.dart';
import 'package:ipr_mobile/features/authentication/presentation/controllers/register_controller.dart';

import 'support/auth_fakes.dart';

AuthHarness loginHarness({FakeAuthRepository? repo}) {
  final h = AuthHarness(repo: repo);
  addTearDown(h.dispose);
  h.keepAlive(loginControllerProvider);
  return h;
}

AuthHarness registerHarness({
  FakeAuthRepository? repo,
  RemoteConfig config = legalConfig,
}) {
  final h = AuthHarness(repo: repo, config: config);
  addTearDown(h.dispose);
  h.keepAlive(registerControllerProvider);
  return h;
}

AuthHarness recoveryHarness({FakeAuthRepository? repo}) {
  final h = AuthHarness(repo: repo);
  addTearDown(h.dispose);
  h.keepAlive(passwordRecoveryControllerProvider);
  return h;
}

RegistrationForm registration({
  String email = AuthSamples.email,
  String password = AuthSamples.password,
  String? confirm,
  bool accepted = true,
}) => RegistrationForm(
  email: email,
  firstName: 'Cliente',
  lastName: 'Prueba',
  password: password,
  confirmPassword: confirm ?? password,
  acceptedLegal: accepted,
);

void main() {
  group('LoginController', () {
    test(
      'TC-009 · AC-040-3 · campos vacíos: errores por campo y 0 solicitudes',
      () async {
        final h = loginHarness();
        final ctrl = h.container.read(loginControllerProvider.notifier);

        expect(
          await ctrl.submit(login: '', password: AuthSamples.password),
          isFalse,
        );
        expect(h.container.read(loginControllerProvider).fieldIssues, {
          AuthField.login: FieldIssue.required,
        });
        expect(
          await ctrl.submit(login: AuthSamples.login, password: ''),
          isFalse,
        );
        expect(h.container.read(loginControllerProvider).fieldIssues, {
          AuthField.password: FieldIssue.required,
        });
        expect(h.repo.totalCalls, 0);
      },
    );

    test(
      'TC-009 · AC-040-4 · doble toque emite exactamente una solicitud',
      () async {
        final h = loginHarness();
        final ctrl = h.container.read(loginControllerProvider.notifier);

        final first = ctrl.submit(
          login: AuthSamples.login,
          password: AuthSamples.password,
        );
        final second = ctrl.submit(
          login: AuthSamples.login,
          password: AuthSamples.password,
        );
        expect(await second, isFalse);
        expect(h.repo.loginCalls, hasLength(1));
        expect(h.container.read(loginControllerProvider).submitting, isTrue);
        expect(h.container.read(loginControllerProvider).canSubmit, isFalse);

        h.repo.loginCalls.single.$2.ok(fixtureSession());
        expect(await first, isTrue);
        expect(h.repo.loginCalls, hasLength(1));
      },
    );

    test('TC-010 · AC-040-1 · éxito: setSession guarda la sesión (userId del servidor)', () async {
      final h = loginHarness(
        repo: FakeAuthRepository(autoLogin: Ok(fixtureSession())),
      );
      final ctrl = h.container.read(loginControllerProvider.notifier);
      final session = h.container.read(sessionControllerProvider.notifier);
      expect(
        h.container.read(sessionControllerProvider),
        isA<SessionUnknown>(),
      );

      final ok = await ctrl.submit(
        login: AuthSamples.login,
        password: AuthSamples.password,
      );

      expect(ok, isTrue);
      final state = h.container.read(sessionControllerProvider);
      expect(state, isA<SessionAuthenticated>());
      expect((state as SessionAuthenticated).userId, 4821);
      expect(session.accessToken, fixtureTokens().accessToken);
      expect(h.container.read(loginControllerProvider).completed, isTrue);
      // Y no se puede volver a enviar.
      expect(h.container.read(loginControllerProvider).canSubmit, isFalse);
    });

    test('TC-010 · AC-040-6 · AC-044-1 · solo el refresh va al almacén seguro; el access y la contraseña no se guardan', () async {
      final h = loginHarness(
        repo: FakeAuthRepository(autoLogin: Ok(fixtureSession())),
      );
      await h.container
          .read(loginControllerProvider.notifier)
          .submit(login: AuthSamples.login, password: AuthSamples.password);

      final tokens = fixtureTokens();
      // Almacén seguro: únicamente el refresh token.
      expect(h.secure.data[SecureKeys.refreshToken], tokens.refreshToken);
      for (final value in h.secure.data.values) {
        expect(value, isNot(contains(tokens.accessToken)));
        expect(value, isNot(contains(AuthSamples.password)));
        expect(value, isNot(contains(AuthSamples.login)));
      }
      // El access token vive solo en memoria.
      expect(
        h.container.read(sessionControllerProvider.notifier).accessToken,
        tokens.accessToken,
      );
    });

    test('TC-011 · AC-040-2 · AC-045-5 · cuenta inexistente, rol bloqueado y 403 dan EL MISMO estado', () async {
      final states = <String>[];
      for (final failure in <AppFailure>[
        const Unauthorized(code: 'invalid_credentials'),
        const Unauthorized(),
        const Forbidden(code: 'account_locked'),
      ]) {
        final h = loginHarness(
          repo: FakeAuthRepository(autoLogin: Err(failure)),
        );
        final ok = await h.container
            .read(loginControllerProvider.notifier)
            .submit(
              login: 'cualquiera@example.test',
              password: AuthSamples.wrongPassword,
            );
        expect(ok, isFalse);
        final state = h.container.read(loginControllerProvider);
        expect(state.problem, AuthProblem.invalidCredentials);
        expect(
          h.container.read(sessionControllerProvider),
          isNot(isA<SessionAuthenticated>()),
        );
        states.add(state.toString());
      }
      expect(states.toSet(), hasLength(1));
    });

    test('TC-013 · AC-048-1 · la sesión no se guarda ante rechazo', () async {
      final h = loginHarness(
        repo: FakeAuthRepository(
          autoLogin: const Err(Unauthorized(code: 'invalid_credentials')),
        ),
      );
      await h.container
          .read(loginControllerProvider.notifier)
          .submit(login: 'admin@example.test', password: AuthSamples.password);
      expect(h.secure.data, isEmpty);
      expect(
        h.container.read(sessionControllerProvider.notifier).accessToken,
        isNull,
      );
    });

    test(
      'TC-012 · AC-040-5 · sin red NO es "credenciales incorrectas"',
      () async {
        for (final failure in <AppFailure>[
          const NoConnection(),
          const RequestTimeout(),
          const ServiceUnavailable(),
          const ServerFailure(),
        ]) {
          final h = loginHarness(
            repo: FakeAuthRepository(autoLogin: Err(failure)),
          );
          await h.container
              .read(loginControllerProvider.notifier)
              .submit(login: AuthSamples.login, password: AuthSamples.password);
          final state = h.container.read(loginControllerProvider);
          expect(state.problem, AuthProblem.other, reason: '$failure');
          expect(state.failure, same(failure));
          // Tras un error de red se puede reintentar de inmediato.
          expect(state.canSubmit, isTrue);
        }
      },
    );

    testWidgets(
      'AC-045-1 · AC-045-8 · 429 con Retry-After: cuenta regresiva y vuelve a habilitar',
      (tester) async {
        final h = loginHarness(
          repo: FakeAuthRepository(
            autoLogin: const Err(RateLimited(retryAfter: 3)),
          ),
        );
        final ctrl = h.container.read(loginControllerProvider.notifier);
        await ctrl.submit(
          login: AuthSamples.login,
          password: AuthSamples.password,
        );

        var state = h.container.read(loginControllerProvider);
        expect(state.problem, AuthProblem.rateLimited);
        expect(state.cooldownSeconds, 3);
        expect(state.canSubmit, isFalse);

        // Mientras dura la espera no se emite ninguna solicitud.
        expect(
          await ctrl.submit(
            login: AuthSamples.login,
            password: AuthSamples.password,
          ),
          isFalse,
        );
        expect(h.repo.loginCalls, hasLength(1));

        await tester.pump(const Duration(seconds: 1));
        expect(h.container.read(loginControllerProvider).cooldownSeconds, 2);
        await tester.pump(const Duration(seconds: 2));

        state = h.container.read(loginControllerProvider);
        expect(state.cooldownSeconds, 0);
        expect(state.canSubmit, isTrue);
        // Pasada la espera desaparece el aviso de bloqueo.
        expect(state.problem, isNull);
      },
    );

    test('AC-045-1 · 429 sin Retry-After: aviso sin cuenta regresiva ni bloqueo del botón', () async {
      final h = loginHarness(
        repo: FakeAuthRepository(autoLogin: const Err(RateLimited())),
      );
      await h.container
          .read(loginControllerProvider.notifier)
          .submit(login: AuthSamples.login, password: AuthSamples.password);
      final state = h.container.read(loginControllerProvider);
      expect(state.problem, AuthProblem.rateLimited);
      expect(state.coolingDown, isFalse);
      expect(state.canSubmit, isTrue);
    });

    test('M2 · RF-045 · 400 con errors[]: el mensaje queda junto al campo que coincide', () async {
      final h = loginHarness(
        repo: FakeAuthRepository(
          autoLogin: const Err(
            Validation(
              fields: [
                FieldError(
                  field: 'login',
                  code: 'invalid',
                  message: 'Usuario no válido.',
                ),
                FieldError(field: 'password', code: 'invalid', message: ''),
              ],
            ),
          ),
        ),
      );
      await h.container
          .read(loginControllerProvider.notifier)
          .submit(login: AuthSamples.login, password: AuthSamples.password);
      final state = h.container.read(loginControllerProvider);
      expect(state.serverMessages, {
        AuthField.login: 'Usuario no válido.',
        AuthField.password: '',
      });
      expect(state.problem, isNull);
    });

    test('M2 · RF-045 · 400 con un campo desconocido: aviso general, no se pierde el error', () async {
      final h = loginHarness(
        repo: FakeAuthRepository(
          autoLogin: const Err(
            Validation(
              fields: [FieldError(field: 'algoNuevo', code: 'x', message: 'm')],
            ),
          ),
        ),
      );
      await h.container
          .read(loginControllerProvider.notifier)
          .submit(login: AuthSamples.login, password: AuthSamples.password);
      final state = h.container.read(loginControllerProvider);
      expect(state.problem, AuthProblem.other);
      expect(state.failure, isA<Validation>());
    });

    test(
      'M2 · un fallo del almacén seguro no deja la sesión a medias',
      () async {
        final h = AuthHarness(
          repo: FakeAuthRepository(autoLogin: Ok(fixtureSession())),
          secureStore: const ThrowingSecureKeyValue(),
        );
        addTearDown(h.dispose);
        h.keepAlive(loginControllerProvider);
        final ok = await h.container
            .read(loginControllerProvider.notifier)
            .submit(login: AuthSamples.login, password: AuthSamples.password);
        expect(ok, isFalse);
        expect(
          h.container.read(loginControllerProvider).problem,
          AuthProblem.other,
        );
        expect(
          h.container.read(sessionControllerProvider),
          isNot(isA<SessionAuthenticated>()),
        );
      },
    );

    test('M2 · salir de la pantalla cancela la petición en vuelo', () async {
      final h = AuthHarness();
      final sub = h.container.listen(loginControllerProvider, (_, _) {});
      unawaited(
        h.container
            .read(loginControllerProvider.notifier)
            .submit(login: AuthSamples.login, password: AuthSamples.password),
      );
      await flush();
      final call = h.repo.loginCalls.single.$2;
      expect(call.cancellation!.isCancelled, isFalse);
      sub.close();
      await flush();
      expect(call.cancellation!.isCancelled, isTrue);
      h.dispose();
    });

    test('AC-040-7 · AC-044-9 · el estado nunca contiene la contraseña ni el usuario', () async {
      final h = loginHarness(
        repo: FakeAuthRepository(autoLogin: const Err(Unauthorized())),
      );
      await h.container
          .read(loginControllerProvider.notifier)
          .submit(
            login: AuthSamples.login,
            password: AuthSamples.wrongPassword,
          );
      final text = h.container.read(loginControllerProvider).toString();
      expect(text, isNot(contains(AuthSamples.wrongPassword)));
      expect(text, isNot(contains(AuthSamples.login)));
    });
  });

  group('RegisterController', () {
    test(
      'TC-001 · AC-038-3 · datos inválidos: errores por campo y 0 solicitudes',
      () async {
        final h = registerHarness();
        final ctrl = h.container.read(registerControllerProvider.notifier);
        expect(await ctrl.submit(registration(password: 'Qa12345')), isFalse);
        expect(
          h.container
              .read(registerControllerProvider)
              .fieldIssues[AuthField.password],
          FieldIssue.passwordTooShort,
        );
        expect(await ctrl.submit(registration(email: 'a@b')), isFalse);
        expect(
          h.container
              .read(registerControllerProvider)
              .fieldIssues[AuthField.email],
          FieldIssue.emailInvalid,
        );
        expect(
          await ctrl.submit(registration(confirm: 'otra-clave-1')),
          isFalse,
        );
        expect(
          h.container
              .read(registerControllerProvider)
              .fieldIssues[AuthField.confirmPassword],
          FieldIssue.passwordMismatch,
        );
        expect(h.repo.totalCalls, 0);
      },
    );

    test('TC-002 · AC-039-2 · sin aceptar términos no se envía', () async {
      final h = registerHarness();
      expect(
        await h.container
            .read(registerControllerProvider.notifier)
            .submit(registration(accepted: false)),
        isFalse,
      );
      expect(h.container.read(registerControllerProvider).fieldIssues, {
        AuthField.acceptance: FieldIssue.acceptanceRequired,
      });
      expect(h.repo.totalCalls, 0);
    });

    test('TC-005 · AC-039-3 · éxito: acceptance con las versiones de /config y sesión guardada', () async {
      final h = registerHarness(
        repo: FakeAuthRepository(autoRegister: Ok(fixtureSession(userId: 77))),
        config: const RemoteConfig(
          termsVersion: 'T-7',
          privacyPolicyVersion: 'P-9',
        ),
      );
      final ok = await h.container
          .read(registerControllerProvider.notifier)
          .submit(registration());

      expect(ok, isTrue);
      final request = h.repo.registerCalls.single.$1;
      expect(request.acceptance.termsVersion, 'T-7');
      expect(request.acceptance.privacyPolicyVersion, 'P-9');
      expect(request.email, AuthSamples.email);
      final session = h.container.read(sessionControllerProvider);
      expect((session as SessionAuthenticated).userId, 77);
      expect(
        h.secure.data[SecureKeys.refreshToken],
        fixtureTokens().refreshToken,
      );
      expect(h.container.read(registerControllerProvider).completed, isTrue);
    });

    test('AC-039-4 · sin versiones legales NO se registra (falla cerrado) y se explica', () async {
      for (final config in const [
        RemoteConfig(),
        RemoteConfig(termsVersion: '1'),
        RemoteConfig(privacyPolicyVersion: '1'),
        RemoteConfig(termsVersion: '', privacyPolicyVersion: ''),
      ]) {
        final h = registerHarness(config: config);
        expect(h.container.read(legalAcceptanceProvider), isNull);
        final ok = await h.container
            .read(registerControllerProvider.notifier)
            .submit(registration());
        expect(ok, isFalse);
        expect(h.repo.totalCalls, 0);
        expect(
          h.container.read(registerControllerProvider).problem,
          AuthProblem.legalUnavailable,
        );
      }
    });

    test(
      'AC-039-5 · reintentar la carga de /config habilita el registro',
      () async {
        final h = registerHarness(
          repo: FakeAuthRepository(autoRegister: Ok(fixtureSession())),
          config: const RemoteConfig(),
        );
        expect(h.container.read(legalAcceptanceProvider), isNull);
        h.remoteConfig.onRefresh = legalConfig;
        await h.container
            .read(registerControllerProvider.notifier)
            .reloadLegalVersions();
        expect(h.remoteConfig.refreshes, 1);
        expect(h.container.read(legalAcceptanceProvider), isNotNull);
        expect(
          await h.container
              .read(registerControllerProvider.notifier)
              .submit(registration()),
          isTrue,
        );
      },
    );

    test(
      'TC-003 · AC-038-6 · doble toque emite exactamente una solicitud',
      () async {
        final h = registerHarness();
        final ctrl = h.container.read(registerControllerProvider.notifier);
        final first = ctrl.submit(registration());
        expect(await ctrl.submit(registration()), isFalse);
        expect(h.repo.registerCalls, hasLength(1));
        h.repo.registerCalls.single.$2.ok(fixtureSession());
        expect(await first, isTrue);
      },
    );

    test('TC-007 · AC-038-5 · 409 muestra el aviso NEUTRAL, igual sea cual sea el code', () async {
      final states = <String>[];
      for (final code in ['email_in_use', 'conflict', 'otro_codigo']) {
        final h = registerHarness(
          repo: FakeAuthRepository(autoRegister: Err(Conflict(code: code))),
        );
        final ok = await h.container
            .read(registerControllerProvider.notifier)
            .submit(registration());
        expect(ok, isFalse);
        final state = h.container.read(registerControllerProvider);
        expect(state.problem, AuthProblem.accountConflict);
        expect(state.canSubmit, isTrue);
        expect(
          h.container.read(sessionControllerProvider),
          isNot(isA<SessionAuthenticated>()),
        );
        states.add(state.toString());
      }
      expect(states.toSet(), hasLength(1));
      expect(states.first, isNot(contains(AuthSamples.email)));
    });

    test(
      'TC-004 · AC-038-7 · sin red: mensaje de conexión y se puede reintentar',
      () async {
        final h = registerHarness(
          repo: FakeAuthRepository(autoRegister: const Err(NoConnection())),
        );
        await h.container
            .read(registerControllerProvider.notifier)
            .submit(registration());
        final state = h.container.read(registerControllerProvider);
        expect(state.problem, AuthProblem.other);
        expect(state.failure, isA<NoConnection>());
        expect(state.completed, isFalse);
        expect(state.canSubmit, isTrue);
      },
    );

    testWidgets('AC-045-3 · 429 en registro: cuenta regresiva', (tester) async {
      final h = registerHarness(
        repo: FakeAuthRepository(
          autoRegister: const Err(RateLimited(retryAfter: 2)),
        ),
      );
      await h.container
          .read(registerControllerProvider.notifier)
          .submit(registration());
      expect(h.container.read(registerControllerProvider).cooldownSeconds, 2);
      expect(h.container.read(registerControllerProvider).canSubmit, isFalse);
      await tester.pump(const Duration(seconds: 2));
      expect(h.container.read(registerControllerProvider).canSubmit, isTrue);
    });

    test('M2 · RF-045 · 400 con errors[]: mensajes junto a email, contraseña y aceptación', () async {
      final h = registerHarness(
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
                FieldError(
                  field: 'acceptance.termsVersion',
                  code: 'outdated',
                  message: 'Versión desactualizada.',
                ),
              ],
            ),
          ),
        ),
      );
      await h.container
          .read(registerControllerProvider.notifier)
          .submit(registration());
      final state = h.container.read(registerControllerProvider);
      expect(state.serverMessages[AuthField.email], 'El correo no es válido.');
      expect(
        state.serverMessages[AuthField.password],
        'Esa contraseña es muy común.',
      );
      expect(
        state.serverMessages[AuthField.acceptance],
        'Versión desactualizada.',
      );
      expect(state.problem, isNull);
    });

    test(
      'AC-038-8 · el estado y los errores nunca incluyen la contraseña',
      () async {
        final h = registerHarness(
          repo: FakeAuthRepository(autoRegister: const Err(ServerFailure())),
        );
        await h.container
            .read(registerControllerProvider.notifier)
            .submit(registration(password: 'Clave-Muy-Secreta-1'));
        expect(
          h.container.read(registerControllerProvider).toString(),
          isNot(contains('Clave-Muy-Secreta-1')),
        );
      },
    );
  });

  group('PasswordRecoveryController', () {
    test(
      'TC-025 · correo inválido: error en el campo y 0 solicitudes',
      () async {
        final h = recoveryHarness();
        expect(
          await h.container
              .read(passwordRecoveryControllerProvider.notifier)
              .submit('a@b'),
          isFalse,
        );
        expect(
          h.container.read(passwordRecoveryControllerProvider).fieldIssues,
          {AuthField.email: FieldIssue.emailInvalid},
        );
        expect(h.repo.totalCalls, 0);
      },
    );

    test(
      'TC-026 · AC-042-4 · correo registrado y no registrado: estado idéntico',
      () async {
        final states = <String>[];
        for (final email in [
          'qa.cliente.01@example.test',
          'qa.nadie@example.test',
        ]) {
          final h = recoveryHarness(
            repo: FakeAuthRepository(autoReset: const Ok(null)),
          );
          expect(
            await h.container
                .read(passwordRecoveryControllerProvider.notifier)
                .submit(email),
            isTrue,
          );
          final state = h.container.read(passwordRecoveryControllerProvider);
          expect(state.completed, isTrue);
          states.add(state.toString());
          expect(h.repo.resetCalls.single.$1, email);
        }
        expect(states.toSet(), hasLength(1));
      },
    );

    test('AC-042-8 · sin red: mensaje de conexión, sin avanzar', () async {
      final h = recoveryHarness(
        repo: FakeAuthRepository(autoReset: const Err(NoConnection())),
      );
      await h.container
          .read(passwordRecoveryControllerProvider.notifier)
          .submit(AuthSamples.login);
      final state = h.container.read(passwordRecoveryControllerProvider);
      expect(state.completed, isFalse);
      expect(state.failure, isA<NoConnection>());
    });

    testWidgets('AC-042-5 · AC-045-3 · 429: cuenta regresiva', (tester) async {
      final h = recoveryHarness(
        repo: FakeAuthRepository(
          autoReset: const Err(RateLimited(retryAfter: 5)),
        ),
      );
      await h.container
          .read(passwordRecoveryControllerProvider.notifier)
          .submit(AuthSamples.login);
      expect(
        h.container.read(passwordRecoveryControllerProvider).cooldownSeconds,
        5,
      );
      await tester.pump(const Duration(seconds: 5));
      expect(
        h.container.read(passwordRecoveryControllerProvider).canSubmit,
        isTrue,
      );
    });

    test('M2 · una solicitud a la vez (doble toque)', () async {
      final h = recoveryHarness();
      final ctrl = h.container.read(
        passwordRecoveryControllerProvider.notifier,
      );
      final first = ctrl.submit(AuthSamples.login);
      expect(await ctrl.submit(AuthSamples.login), isFalse);
      expect(h.repo.resetCalls, hasLength(1));
      h.repo.resetCalls.single.$2.ok(null);
      expect(await first, isTrue);
    });

    test('M2 · 400 con errors[email]: mensaje junto al campo', () async {
      final h = recoveryHarness(
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
      await h.container
          .read(passwordRecoveryControllerProvider.notifier)
          .submit(AuthSamples.login);
      expect(
        h.container.read(passwordRecoveryControllerProvider).serverMessages,
        {AuthField.email: 'Correo no válido.'},
      );
    });
  });

  group('Cooldown y estado', () {
    testWidgets('Cooldown cuenta cada segundo y termina en 0', (tester) async {
      final ticks = <int>[];
      Cooldown(onTick: ticks.add).start(3);
      await tester.pump(const Duration(seconds: 5));
      expect(ticks, [3, 2, 1, 0]);
    });

    testWidgets('Cooldown con 0 segundos no programa nada; cancelar detiene', (
      tester,
    ) async {
      final ticks = <int>[];
      final cooldown = Cooldown(onTick: ticks.add)..start(0);
      expect(ticks, [0]);
      cooldown
        ..start(10)
        ..cancel();
      await tester.pump(const Duration(seconds: 20));
      expect(ticks, [0, 10]);
    });

    test('toString del estado no incluye valores', () {
      const state = AuthFormState(
        problem: AuthProblem.invalidCredentials,
        serverMessages: {AuthField.email: 'correo@secreto.test'},
      );
      expect(state.toString(), isNot(contains('secreto')));
    });
  });
}
