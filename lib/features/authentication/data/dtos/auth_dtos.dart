import 'package:ipr_mobile/core/session/session_tokens.dart';

/// `AuthSessionResponse` (`openapi.yaml`): solo se leen `data.session` y
/// `data.user.id`. El resto del perfil (correo, nombre, direcciones) se ignora
/// a propósito: no se conserva nada personal (CR-065).
///
/// Lanza [FormatException] si falta lo imprescindible; `ApiClient` lo
/// convierte en `ContractFailure` sin volcar el cuerpo.
final class AuthSessionDto {
  const new({required this.tokens, required this.userId});

  factory fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('respuesta no es un objeto');
    }
    final data = json['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('falta data');
    }
    final tokens = SessionTokens.fromSessionJson(data['session']);
    final user = data['user'];
    final id = user is Map<String, dynamic> ? user['id'] : null;
    if (id is! int) throw const FormatException('falta user.id');
    return AuthSessionDto(tokens: tokens, userId: id);
  }

  final SessionTokens tokens;
  final int userId;

  @override
  String toString() => 'AuthSessionDto(<redacted>)';
}

/// Cuerpo de `LoginRequest`.
final class LoginRequestDto {
  const new({required this.login, required this.password});

  final String login;
  final String password;

  Map<String, Object?> toJson() => {'login': login, 'password': password};

  @override
  String toString() => 'LoginRequestDto(<redacted>)';
}

/// Cuerpo de `RegisterRequest` (`additionalProperties: false`: no se añade
/// ningún campo fuera del contrato).
final class RegisterRequestDto {
  const new({
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.password,
    required this.termsVersion,
    required this.privacyPolicyVersion,
  });

  final String email;
  final String firstName;
  final String lastName;
  final String password;
  final String termsVersion;
  final String privacyPolicyVersion;

  Map<String, Object?> toJson() => {
    'email': email,
    'firstName': firstName,
    'lastName': lastName,
    'password': password,
    'acceptance': {
      'termsVersion': termsVersion,
      'privacyPolicyVersion': privacyPolicyVersion,
      'accepted': true,
    },
  };

  @override
  String toString() => 'RegisterRequestDto(<redacted>)';
}

/// Cuerpo de `ForgotPasswordRequest`.
final class ForgotPasswordRequestDto {
  const new({required this.email});

  final String email;

  Map<String, Object?> toJson() => {'email': email};

  @override
  String toString() => 'ForgotPasswordRequestDto(<redacted>)';
}
