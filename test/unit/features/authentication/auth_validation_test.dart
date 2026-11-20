import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/features/authentication/domain/entities/authenticated_session.dart';
import 'package:ipr_mobile/features/authentication/domain/entities/login_credentials.dart';
import 'package:ipr_mobile/features/authentication/domain/entities/registration.dart';
import 'package:ipr_mobile/features/authentication/domain/rules/auth_validation.dart';
import 'package:ipr_mobile/features/authentication/domain/rules/register_conflict_policy.dart';

import 'support/auth_fakes.dart';

RegistrationForm form({
  String email = AuthSamples.email,
  String firstName = 'Cliente',
  String lastName = 'Prueba',
  String password = AuthSamples.password,
  String? confirm,
  bool accepted = true,
}) => RegistrationForm(
  email: email,
  firstName: firstName,
  lastName: lastName,
  password: password,
  confirmPassword: confirm ?? password,
  acceptedLegal: accepted,
);

void main() {
  group('TC-001 · AC-038-2 · contraseña nueva', () {
    test('7 caracteres se rechaza y 8 se acepta', () {
      expect(
        AuthValidation.newPassword('Qa12345'),
        FieldIssue.passwordTooShort,
      );
      expect(AuthValidation.newPassword('Qa123456'), isNull);
    });

    test('vacía es obligatoria; 128 pasa y 129 es demasiado larga', () {
      expect(AuthValidation.newPassword(''), FieldIssue.required);
      expect(AuthValidation.newPassword('a' * 128), isNull);
      expect(AuthValidation.newPassword('a' * 129), FieldIssue.tooLong);
    });

    test('no recorta espacios (cuentan como caracteres)', () {
      expect(
        AuthValidation.newPassword('       '),
        FieldIssue.passwordTooShort,
      );
      expect(AuthValidation.newPassword('        '), isNull);
    });

    test('cuenta caracteres, no unidades UTF-16 (emoji = 1)', () {
      // 8 emojis = 8 caracteres aunque ocupen 16 unidades UTF-16.
      expect(AuthValidation.newPassword('😀' * 8), isNull);
      expect(AuthValidation.newPassword('😀' * 7), FieldIssue.passwordTooShort);
    });
  });

  group('TC-001 · AC-038-3 · correo', () {
    test('a@, a@b, sin arroba y vacío se rechazan; uno válido pasa', () {
      expect(AuthValidation.email('a@'), FieldIssue.emailInvalid);
      expect(AuthValidation.email('a@b'), FieldIssue.emailInvalid);
      expect(
        AuthValidation.email('qa.sin.arroba.test'),
        FieldIssue.emailInvalid,
      );
      expect(AuthValidation.email(''), FieldIssue.required);
      expect(AuthValidation.email('   '), FieldIssue.required);
      expect(AuthValidation.email('qa.cliente.nuevo@example.test'), isNull);
    });

    test('con espacios alrededor se recorta; con espacios dentro no', () {
      expect(AuthValidation.email('  qa@example.test  '), isNull);
      expect(AuthValidation.email('qa @example.test'), FieldIssue.emailInvalid);
    });

    test('más de 120 caracteres es demasiado largo', () {
      final long = '${'a' * 110}@example.test';
      expect(AuthValidation.email(long), FieldIssue.tooLong);
    });
  });

  group('TC-001 · AC-038-3 · registro completo', () {
    test('un formulario válido no tiene errores', () {
      expect(AuthValidation.forRegistration(form()), isEmpty);
    });

    test('cada campo obligatorio vacío marca solo su campo', () {
      expect(AuthValidation.forRegistration(form(email: '')).keys, [
        AuthField.email,
      ]);
      expect(AuthValidation.forRegistration(form(firstName: ' ')).keys, [
        AuthField.firstName,
      ]);
      expect(AuthValidation.forRegistration(form(lastName: '')).keys, [
        AuthField.lastName,
      ]);
      final noPassword = AuthValidation.forRegistration(
        form(password: '', confirm: ''),
      );
      expect(noPassword[AuthField.password], FieldIssue.required);
      expect(noPassword[AuthField.confirmPassword], FieldIssue.required);
    });

    test('nombres de más de 60 caracteres', () {
      expect(AuthValidation.forRegistration(form(firstName: 'a' * 61)), {
        AuthField.firstName: FieldIssue.tooLong,
      });
    });

    test('M2 · RF-038 · la confirmación debe coincidir', () {
      expect(AuthValidation.forRegistration(form(confirm: 'Qa123457')), {
        AuthField.confirmPassword: FieldIssue.passwordMismatch,
      });
    });

    test('AC-039-2 · sin aceptar los términos hay un error de aceptación', () {
      expect(AuthValidation.forRegistration(form(accepted: false)), {
        AuthField.acceptance: FieldIssue.acceptanceRequired,
      });
    });
  });

  group('TC-009 · AC-040-3 · login', () {
    test('usuario o contraseña vacíos marcan su campo', () {
      expect(
        AuthValidation.forLogin(login: '', password: AuthSamples.password),
        {AuthField.login: FieldIssue.required},
      );
      expect(AuthValidation.forLogin(login: AuthSamples.login, password: ''), {
        AuthField.password: FieldIssue.required,
      });
      expect(AuthValidation.forLogin(login: '  ', password: ''), {
        AuthField.login: FieldIssue.required,
        AuthField.password: FieldIssue.required,
      });
    });

    test('no exige el mínimo de 8 en el login (contraseñas antiguas)', () {
      expect(AuthValidation.forLogin(login: 'ana', password: 'corta'), isEmpty);
    });

    test('límites del contrato: 120 y 128', () {
      expect(AuthValidation.login('a' * 121), FieldIssue.tooLong);
      expect(AuthValidation.loginPassword('a' * 129), FieldIssue.tooLong);
    });
  });

  group('TC-025 · AC-042-1 · recuperación', () {
    test('valida el correo', () {
      expect(AuthValidation.forRecovery(''), {
        AuthField.email: FieldIssue.required,
      });
      expect(AuthValidation.forRecovery('a@b'), {
        AuthField.email: FieldIssue.emailInvalid,
      });
      expect(AuthValidation.forRecovery(AuthSamples.login), isEmpty);
    });
  });

  group('M2 · RF-045 · errores del servidor por campo', () {
    test('AuthField.fromServer reconoce los campos del contrato', () {
      expect(AuthField.fromServer('email'), AuthField.email);
      expect(AuthField.fromServer('firstName'), AuthField.firstName);
      expect(AuthField.fromServer('lastName'), AuthField.lastName);
      expect(AuthField.fromServer('password'), AuthField.password);
      expect(AuthField.fromServer('login'), AuthField.login);
      expect(AuthField.fromServer('body.email'), AuthField.email);
      expect(
        AuthField.fromServer('acceptance.termsVersion'),
        AuthField.acceptance,
      );
      expect(AuthField.fromServer('acceptance'), AuthField.acceptance);
      expect(AuthField.fromServer('algoNuevo'), isNull);
      expect(AuthField.fromServer(''), isNull);
    });

    test('maxFor entrega el límite de cada campo', () {
      expect(AuthLimits.maxFor(AuthField.email), 120);
      expect(AuthLimits.maxFor(AuthField.firstName), 60);
      expect(AuthLimits.maxFor(AuthField.password), 128);
      expect(AuthLimits.maxFor(AuthField.login), 120);
    });
  });

  group('M2 · RF-039 · LegalAcceptance falla cerrado', () {
    test('con ambas versiones se crea (y se recortan)', () {
      final value = LegalAcceptance.tryCreate(
        termsVersion: ' 2026-01 ',
        privacyPolicyVersion: '2026-02',
      );
      expect(value!.termsVersion, '2026-01');
      expect(value.privacyPolicyVersion, '2026-02');
    });

    test('faltan, vacías o en blanco: null (nunca se inventa una versión)', () {
      for (final (terms, privacy) in <(String?, String?)>[
        (null, null),
        ('2026-01', null),
        (null, '2026-01'),
        ('', '2026-01'),
        ('2026-01', '   '),
      ]) {
        expect(
          LegalAcceptance.tryCreate(
            termsVersion: terms,
            privacyPolicyVersion: privacy,
          ),
          isNull,
          reason: '$terms / $privacy',
        );
      }
    });

    test('una versión de más de 20 caracteres no cabe en el contrato', () {
      expect(
        LegalAcceptance.tryCreate(
          termsVersion: 'v' * 21,
          privacyPolicyVersion: '1',
        ),
        isNull,
      );
    });
  });

  group('M2 · RF-038 · política de conflicto (H-03 pendiente)', () {
    test(
      'cualquier 409 es conflicto de cuenta y se resuelve con aviso neutral',
      () {
        expect(
          RegisterConflictPolicy.appliesTo(
            const Conflict(code: 'email_in_use'),
          ),
          isTrue,
        );
        expect(
          RegisterConflictPolicy.appliesTo(const Conflict(code: 'conflict')),
          isTrue,
        );
        expect(RegisterConflictPolicy.appliesTo(const NoConnection()), isFalse);
        expect(RegisterConflictPolicy.appliesTo(const Unauthorized()), isFalse);
        expect(
          RegisterConflictPolicy.resolution,
          RegisterConflictResolution.neutralNotice,
        );
      },
    );
  });

  group('AC-038-8 · AC-040-6 · la contraseña no se imprime', () {
    test('toString de las entidades no contiene valores', () {
      const secret = 'Sup3r-Secreta-9';
      final objects = <Object>[
        const LoginCredentials(login: AuthSamples.login, password: secret),
        form(password: secret),
        RegistrationRequest(
          email: AuthSamples.email,
          firstName: 'Cliente',
          lastName: 'Prueba',
          password: secret,
          acceptance: LegalAcceptance.tryCreate(
            termsVersion: '1',
            privacyPolicyVersion: '1',
          )!,
        ),
        fixtureSession(),
      ];
      for (final object in objects) {
        final text = object.toString();
        expect(text, isNot(contains(secret)), reason: text);
        expect(text, isNot(contains(AuthSamples.email)), reason: text);
        expect(text, isNot(contains(AuthSamples.login)), reason: text);
        expect(text, contains('<redacted>'), reason: text);
      }
      expect(fixtureSession().toString(), isNot(contains('ipra_')));
      expect(fixtureSession(), isA<AuthenticatedSession>());
    });
  });
}
