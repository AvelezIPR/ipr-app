import 'package:meta/meta.dart';

/// Credenciales de `POST /auth/login`. [login] es el correo o el nombre de
/// usuario. La contraseña vive solo mientras dura la solicitud: nunca se
/// guarda ni se imprime (AC-040-6, AC-040-7).
@immutable
final class LoginCredentials {
  const new({required this.login, required this.password});

  final String login;
  final String password;

  /// Sin valores: ni el usuario ni la contraseña salen en logs ni reportes.
  @override
  String toString() => 'LoginCredentials(<redacted>)';
}
