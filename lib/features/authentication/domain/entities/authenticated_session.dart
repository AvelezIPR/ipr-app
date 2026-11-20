import 'package:ipr_mobile/core/session/session_tokens.dart';
import 'package:meta/meta.dart';

/// Resultado de un login o registro correcto: los tokens de la sesión del
/// dispositivo y el identificador del usuario (no sensible).
///
/// Es TODO lo que la feature conserva de `AuthSessionResponse`: ni el correo,
/// ni el nombre ni las direcciones se guardan (CR-065). Los tokens los
/// entrega `SessionController.setSession`.
@immutable
final class AuthenticatedSession {
  const new({required this.tokens, required this.userId});

  final SessionTokens tokens;
  final int userId;

  @override
  String toString() => 'AuthenticatedSession(<redacted>)';
}
