import 'package:ipr_mobile/core/network/api_client.dart';
import 'package:ipr_mobile/core/network/api_request.dart';
import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/authentication/data/dtos/auth_dtos.dart';

/// Acceso HTTP a `/auth/login`, `/auth/register` y `/auth/password/forgot`.
///
/// Las tres son públicas (`requiresAuth: false`): no llevan `Authorization`.
/// La contraseña va únicamente en el cuerpo (nunca en la URL) y estas llamadas
/// no usan `Idempotency-Key` (solo checkout, eliminación y PQRS). Un `POST`
/// nunca se reintenta automáticamente.
final class AuthRemoteDataSource {
  const new(this._client);

  final ApiClient _client;

  Future<Result<AuthSessionDto>> login(
    LoginRequestDto body, {
    RequestCancellation? cancellation,
  }) => _client.sendDecoded(
    ApiRequest.post('/auth/login', body: body.toJson()),
    AuthSessionDto.fromJson,
    cancellation: cancellation,
  );

  Future<Result<AuthSessionDto>> register(
    RegisterRequestDto body, {
    RequestCancellation? cancellation,
  }) => _client.sendDecoded(
    ApiRequest.post('/auth/register', body: body.toJson()),
    AuthSessionDto.fromJson,
    cancellation: cancellation,
  );

  /// `202` siempre (exista o no la cuenta): el cuerpo no se interpreta.
  Future<Result<void>> requestPasswordReset(
    ForgotPasswordRequestDto body, {
    RequestCancellation? cancellation,
  }) async {
    final result = await _client.send(
      ApiRequest.post('/auth/password/forgot', body: body.toJson()),
      cancellation: cancellation,
    );
    return result.map((_) {});
  }
}
