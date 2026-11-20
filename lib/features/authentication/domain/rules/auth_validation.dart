import 'package:ipr_mobile/features/authentication/domain/entities/registration.dart';

/// Campos de los formularios de autenticación.
enum AuthField {
  login,
  email,
  firstName,
  lastName,
  password,
  confirmPassword,
  acceptance;

  /// Campo del formulario que corresponde al `field` de un error del servidor
  /// (`Problem.errors[].field`), o `null` si no coincide con ninguno.
  static AuthField? fromServer(String field) {
    final name = field.trim();
    if (name.toLowerCase().startsWith('acceptance')) return acceptance;
    final last = name.split('.').last.toLowerCase();
    return switch (last) {
      'login' => login,
      'email' => email,
      'firstname' => firstName,
      'lastname' => lastName,
      'password' => password,
      _ => null,
    };
  }
}

/// Motivo por el que un campo no pasa la validación local.
enum FieldIssue {
  required,
  emailInvalid,
  tooLong,
  passwordTooShort,
  passwordMismatch,
  acceptanceRequired,
}

/// Límites del contrato (`RegisterRequest`, `LoginRequest`,
/// `ForgotPasswordRequest`).
abstract final class AuthLimits {
  static const loginMax = 120;
  static const emailMax = 120;
  static const nameMax = 60;
  static const passwordMin = 8;
  static const passwordMax = 128;

  /// Longitud máxima de [field] para el mensaje "demasiado largo".
  static int maxFor(AuthField field) => switch (field) {
    AuthField.login => loginMax,
    AuthField.email => emailMax,
    AuthField.firstName || AuthField.lastName => nameMax,
    AuthField.password || AuthField.confirmPassword => passwordMax,
    AuthField.acceptance => 0,
  };
}

int _length(String value) => value.runes.length;

/// Validación local previa al envío. NO es la única defensa: el servidor
/// valida de nuevo y sus errores por campo se muestran igualmente.
abstract final class AuthValidation {
  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  /// Correo o usuario del login: obligatorio y ≤ 120.
  static FieldIssue? login(String value) {
    final text = value.trim();
    if (text.isEmpty) return FieldIssue.required;
    if (_length(text) > AuthLimits.loginMax) return FieldIssue.tooLong;
    return null;
  }

  /// Contraseña del login: solo obligatoria y ≤ 128 (no se exige el mínimo:
  /// una contraseña antigua más corta debe poder intentarse).
  static FieldIssue? loginPassword(String value) {
    if (value.isEmpty) return FieldIssue.required;
    if (_length(value) > AuthLimits.passwordMax) return FieldIssue.tooLong;
    return null;
  }

  static FieldIssue? email(String value) {
    final text = value.trim();
    if (text.isEmpty) return FieldIssue.required;
    if (_length(text) > AuthLimits.emailMax) return FieldIssue.tooLong;
    if (!_email.hasMatch(text)) return FieldIssue.emailInvalid;
    return null;
  }

  static FieldIssue? name(String value) {
    final text = value.trim();
    if (text.isEmpty) return FieldIssue.required;
    if (_length(text) > AuthLimits.nameMax) return FieldIssue.tooLong;
    return null;
  }

  /// Contraseña nueva: 8 a 128 caracteres. No se recorta (los espacios
  /// cuentan) ni se juzga su complejidad: eso lo decide el servidor (SC-075).
  static FieldIssue? newPassword(String value) {
    if (value.isEmpty) return FieldIssue.required;
    if (_length(value) < AuthLimits.passwordMin) {
      return FieldIssue.passwordTooShort;
    }
    if (_length(value) > AuthLimits.passwordMax) return FieldIssue.tooLong;
    return null;
  }

  static FieldIssue? confirmPassword(String password, String confirm) {
    if (confirm.isEmpty) return FieldIssue.required;
    if (confirm != password) return FieldIssue.passwordMismatch;
    return null;
  }

  static Map<AuthField, FieldIssue> forLogin({
    required String login,
    required String password,
  }) => _collect({
    AuthField.login: AuthValidation.login(login),
    AuthField.password: loginPassword(password),
  });

  static Map<AuthField, FieldIssue> forRecovery(String email) =>
      _collect({AuthField.email: AuthValidation.email(email)});

  static Map<AuthField, FieldIssue> forRegistration(RegistrationForm form) =>
      _collect({
        AuthField.email: email(form.email),
        AuthField.firstName: name(form.firstName),
        AuthField.lastName: name(form.lastName),
        AuthField.password: newPassword(form.password),
        AuthField.confirmPassword: confirmPassword(
          form.password,
          form.confirmPassword,
        ),
        AuthField.acceptance: form.acceptedLegal
            ? null
            : FieldIssue.acceptanceRequired,
      });

  static Map<AuthField, FieldIssue> _collect(
    Map<AuthField, FieldIssue?> issues,
  ) => {
    for (final entry in issues.entries)
      if (entry.value != null) entry.key: entry.value!,
  };
}
