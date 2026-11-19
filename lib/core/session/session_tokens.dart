/// Par de tokens de una sesión de dispositivo (`openapi.yaml` → `Session`).
final class SessionTokens {
  const new({
    required this.accessToken,
    required this.accessTokenExpiresIn,
    required this.refreshToken,
    this.sessionId,
  });

  /// Lee `data.session` de las respuestas de login, registro y refresh.
  /// Lanza [FormatException] si falta un campo o no tiene el prefijo esperado
  /// (`ipra_` para access, `iprr_` para refresh).
  factory fromSessionJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('session no es un objeto');
    }
    final access = json['accessToken'];
    final refresh = json['refreshToken'];
    final expires = json['accessTokenExpiresIn'];
    if (access is! String || !access.startsWith('ipra_')) {
      throw const FormatException('accessToken inválido');
    }
    if (refresh is! String || !refresh.startsWith('iprr_')) {
      throw const FormatException('refreshToken inválido');
    }
    if (expires is! int || expires <= 0) {
      throw const FormatException('accessTokenExpiresIn inválido');
    }
    final sessionId = json['sessionId'];
    return SessionTokens(
      accessToken: access,
      accessTokenExpiresIn: expires,
      refreshToken: refresh,
      sessionId: sessionId is String ? sessionId : null,
    );
  }

  /// `ipra_*`, 15 min. Solo en memoria, jamás en disco (CR-019).
  final String accessToken;
  final int accessTokenExpiresIn;

  /// `iprr_*`. Va en el almacén seguro.
  final String refreshToken;
  final String? sessionId;

  // Nunca se imprimen los tokens.
  @override
  String toString() => 'SessionTokens(<redacted>)';
}
