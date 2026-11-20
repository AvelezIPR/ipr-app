import 'package:ipr_mobile/core/network/api_client.dart';
import 'package:ipr_mobile/core/network/api_request.dart';
import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/profile/data/dtos/profile_dtos.dart';

/// Fuente remota de `/me`, `/me/email`, `/me/password`, `/me/addresses/{type}`
/// y `/me/deletion`.
final class ProfileRemoteDataSource {
  const new(this._client);

  final ApiClient _client;

  Future<Result<UserProfileDto>> getMe({RequestCancellation? cancellation}) =>
      _client.sendDecoded(
        const ApiRequest.get('/me', requiresAuth: true),
        UserProfileDto.fromEnvelope,
        cancellation: cancellation,
      );

  Future<Result<UserProfileDto>> updateNames(
    UpdateProfileRequestDto body, {
    RequestCancellation? cancellation,
  }) => _client.sendDecoded(
    ApiRequest(
      method: 'PATCH',
      path: '/me',
      body: body.toJson(),
      requiresAuth: true,
    ),
    UserProfileDto.fromEnvelope,
    cancellation: cancellation,
  );

  Future<Result<ChangeEmailResponseDto>> changeEmail(
    ChangeEmailRequestDto body, {
    RequestCancellation? cancellation,
  }) => _client.sendDecoded(
    ApiRequest.post('/me/email', body: body.toJson(), requiresAuth: true),
    ChangeEmailResponseDto.fromEnvelope,
    cancellation: cancellation,
  );

  Future<Result<ChangePasswordResponseDto>> changePassword(
    ChangePasswordRequestDto body, {
    RequestCancellation? cancellation,
  }) => _client.sendDecoded(
    ApiRequest.post('/me/password', body: body.toJson(), requiresAuth: true),
    ChangePasswordResponseDto.fromEnvelope,
    cancellation: cancellation,
  );

  Future<Result<UserProfileDto>> putAddress(
    String type,
    AddressInputDto body, {
    RequestCancellation? cancellation,
  }) => _client.sendDecoded(
    ApiRequest(
      method: 'PUT',
      path: '/me/addresses/$type',
      body: body.toJson(),
      requiresAuth: true,
    ),
    UserProfileDto.fromEnvelope,
    cancellation: cancellation,
  );

  /// `POST /me/deletion` con `Idempotency-Key` obligatoria (CR-005).
  Future<Result<AccountDeletionStatusDto>> requestDeletion(
    AccountDeletionRequestDto body, {
    required String idempotencyKey,
    RequestCancellation? cancellation,
  }) => _client.sendDecoded(
    ApiRequest.post(
      '/me/deletion',
      body: body.toJson(),
      requiresAuth: true,
      idempotencyKey: idempotencyKey,
      requiresIdempotency: true,
    ),
    AccountDeletionStatusDto.fromEnvelope,
    cancellation: cancellation,
  );
}
