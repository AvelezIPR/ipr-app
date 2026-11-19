import 'package:ipr_mobile/core/network/api_client.dart';
import 'package:ipr_mobile/core/network/api_request.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/core/session/session_tokens.dart';

/// Operaciones de sesión contra el BFF. Interfaz para poder simularla.
abstract interface class SessionRemote {
  /// `POST /auth/refresh` con el refresh token en el cuerpo.
  Future<Result<SessionTokens>> refresh(String refreshToken);

  /// `POST /auth/logout` con `Authorization: Bearer <accessToken>`.
  Future<Result<void>> logout({required String accessToken, bool all = false});
}

/// Implementación sobre un [ApiClient] **sin** `AuthInterceptor` (evita la
/// recursión del refresh sobre sí mismo).
final class ApiSessionRemote implements SessionRemote {
  new(this._bareClient);

  final ApiClient _bareClient;

  @override
  Future<Result<SessionTokens>> refresh(String refreshToken) {
    return _bareClient.sendDecoded(
      ApiRequest.post('/auth/refresh', body: {'refreshToken': refreshToken}),
      (json) {
        final data = (json! as Map<String, dynamic>)['data'];
        return SessionTokens.fromSessionJson(
          (data! as Map<String, dynamic>)['session'],
        );
      },
    );
  }

  @override
  Future<Result<void>> logout({
    required String accessToken,
    bool all = false,
  }) async {
    final result = await _bareClient.send(
      ApiRequest.post(
        '/auth/logout',
        body: {'scope': all ? 'all' : 'current'},
        headers: {'Authorization': 'Bearer $accessToken'},
      ),
    );
    return result.map((_) {});
  }
}
