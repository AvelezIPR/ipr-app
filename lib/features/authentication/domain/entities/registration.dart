import 'package:meta/meta.dart';

/// Versiones de los documentos legales vigentes que la persona acepta
/// (`RegisterRequest.acceptance`, RF-039). Las publica `GET /config`; la app
/// **nunca** inventa una versión.
@immutable
final class LegalAcceptance {
  const new _internal({
    required this.termsVersion,
    required this.privacyPolicyVersion,
  });

  /// Longitud máxima de cada versión según el contrato (`maxLength: 20`).
  static const maxVersionLength = 20;

  /// `null` si falta alguna versión (configuración sin cargar o vacía) o no
  /// cabe en el contrato: el registro queda bloqueado (falla cerrado).
  static LegalAcceptance? tryCreate({
    required String? termsVersion,
    required String? privacyPolicyVersion,
  }) {
    final terms = termsVersion?.trim() ?? '';
    final privacy = privacyPolicyVersion?.trim() ?? '';
    if (terms.isEmpty || privacy.isEmpty) return null;
    if (terms.length > maxVersionLength || privacy.length > maxVersionLength) {
      return null;
    }
    return LegalAcceptance._internal(
      termsVersion: terms,
      privacyPolicyVersion: privacy,
    );
  }

  final String termsVersion;
  final String privacyPolicyVersion;
}

/// Lo que la persona escribió en el formulario de registro (antes de validar).
/// La confirmación de contraseña solo existe en la app: no viaja al servidor.
@immutable
final class RegistrationForm {
  const new({
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.password,
    required this.confirmPassword,
    required this.acceptedLegal,
  });

  final String email;
  final String firstName;
  final String lastName;
  final String password;
  final String confirmPassword;
  final bool acceptedLegal;

  @override
  String toString() => 'RegistrationForm(<redacted>)';
}

/// Cuerpo validado de `POST /auth/register`.
@immutable
final class RegistrationRequest {
  const new({
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.password,
    required this.acceptance,
  });

  final String email;
  final String firstName;
  final String lastName;
  final String password;
  final LegalAcceptance acceptance;

  @override
  String toString() => 'RegistrationRequest(<redacted>)';
}
