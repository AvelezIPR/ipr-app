import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/core/session/session_tokens.dart';
import 'package:ipr_mobile/features/profile/domain/entities/profile_entities.dart';

/// Operaciones de perfil, direcciones, cambio de credenciales y eliminación
/// de cuenta en `/mobile/v1`. Todo vive solo en memoria (RNF-062).
abstract interface class ProfileRepository {
  Future<Result<UserProfile>> getMe({RequestCancellation? cancellation});

  Future<Result<UserProfile>> updateNames({
    required String firstName,
    required String lastName,
    RequestCancellation? cancellation,
  });

  Future<Result<EmailChangeResult>> changeEmail({
    required String newEmail,
    required String currentPassword,
    RequestCancellation? cancellation,
  });

  Future<Result<SessionTokens>> changePassword({
    required String currentPassword,
    required String newPassword,
    RequestCancellation? cancellation,
  });

  Future<Result<UserProfile>> putAddress({
    required AddressType type,
    required AddressInput input,
    RequestCancellation? cancellation,
  });

  Future<Result<AccountDeletionStatus>> requestDeletion({
    required String currentPassword,
    required String idempotencyKey,
    RequestCancellation? cancellation,
  });
}
