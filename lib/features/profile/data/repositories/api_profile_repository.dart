import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/core/session/session_tokens.dart';
import 'package:ipr_mobile/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:ipr_mobile/features/profile/data/dtos/profile_dtos.dart';
import 'package:ipr_mobile/features/profile/data/mappers/profile_mappers.dart';
import 'package:ipr_mobile/features/profile/domain/entities/profile_entities.dart';
import 'package:ipr_mobile/features/profile/domain/repositories/profile_repository.dart';

/// Implementación sobre `/mobile/v1`. Nunca persiste datos personales ni
/// contraseñas en disco, caché ni logs (RNF-062).
final class ApiProfileRepository implements ProfileRepository {
  const new(this._remote);

  final ProfileRemoteDataSource _remote;

  @override
  Future<Result<UserProfile>> getMe({
    RequestCancellation? cancellation,
  }) async =>
      (await _remote.getMe(cancellation: cancellation)).map(mapUserProfile);

  @override
  Future<Result<UserProfile>> updateNames({
    required String firstName,
    required String lastName,
    RequestCancellation? cancellation,
  }) async => (await _remote.updateNames(
    UpdateProfileRequestDto(
      firstName: firstName.trim(),
      lastName: lastName.trim(),
    ),
    cancellation: cancellation,
  )).map(mapUserProfile);

  @override
  Future<Result<EmailChangeResult>> changeEmail({
    required String newEmail,
    required String currentPassword,
    RequestCancellation? cancellation,
  }) async => (await _remote.changeEmail(
    ChangeEmailRequestDto(
      newEmail: newEmail.trim(),
      currentPassword: currentPassword,
    ),
    cancellation: cancellation,
  )).map(mapEmailChange);

  @override
  Future<Result<SessionTokens>> changePassword({
    required String currentPassword,
    required String newPassword,
    RequestCancellation? cancellation,
  }) async => (await _remote.changePassword(
    ChangePasswordRequestDto(
      currentPassword: currentPassword,
      newPassword: newPassword,
    ),
    cancellation: cancellation,
  )).map((dto) => dto.tokens);

  @override
  Future<Result<UserProfile>> putAddress({
    required AddressType type,
    required AddressInput input,
    RequestCancellation? cancellation,
  }) async => (await _remote.putAddress(
    type.contractValue,
    addressInputDtoOf(input),
    cancellation: cancellation,
  )).map(mapUserProfile);

  @override
  Future<Result<AccountDeletionStatus>> requestDeletion({
    required String currentPassword,
    required String idempotencyKey,
    RequestCancellation? cancellation,
  }) async => (await _remote.requestDeletion(
    AccountDeletionRequestDto(currentPassword: currentPassword),
    idempotencyKey: idempotencyKey,
    cancellation: cancellation,
  )).map(mapAccountDeletionStatus);
}
