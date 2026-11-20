import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ipr_mobile/core/config/remote_config_controller.dart';
import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/core/session/session_controller.dart';
import 'package:ipr_mobile/features/profile/domain/entities/profile_entities.dart';
import 'package:ipr_mobile/features/profile/domain/rules/profile_validation.dart';
import 'package:ipr_mobile/features/profile/presentation/controllers/profile_form_state.dart';
import 'package:ipr_mobile/features/profile/profile_providers.dart';

/// Aviso de retención/eliminación servido por `/config` (texto plano, D-12).
/// Nunca se inventa si el servidor no lo envió.
final Provider<String?> profileDeletionNoticeProvider = Provider<String?>((
  ref,
) {
  final raw = ref.watch(
    remoteConfigProvider.select((s) => s.config.accountDeletionNotice),
  );
  final trimmed = raw?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
});

final NotifierProvider<DeleteAccountController, ProfileFormState>
deleteAccountProvider =
    NotifierProvider.autoDispose<DeleteAccountController, ProfileFormState>(
      DeleteAccountController.new,
    );

/// Eliminación de cuenta (`POST /me/deletion`, RF-110, CR-005/CR-040).
///
/// * Exige confirmación explícita y contraseña actual.
/// * Envía `Idempotency-Key` generada una sola vez por envío.
/// * Tras `202` revoca la sesión local, regenera el `deviceId` y ejecuta los
///   ganchos (`CartRetentionPolicy` borra el carrito).
/// * Ante error de red/servidor, conserva la sesión activa y no borra nada.
class DeleteAccountController extends Notifier<ProfileFormState> {
  ProfileCooldown? _cooldown;
  RequestCancellation? _inflight;

  @override
  ProfileFormState build() {
    _cooldown = ProfileCooldown(
      onTick: (remaining) {
        if (ref.mounted) state = state.withCooldown(remaining);
      },
    );
    ref.onDispose(() {
      _cooldown?.cancel();
      _inflight?.cancel();
    });
    return const ProfileFormState();
  }

  Future<bool> submit({
    required bool confirmed,
    required String currentPassword,
  }) async {
    if (!state.canSubmit) return false;
    final issues = ProfileValidation.forDeletion(
      confirmed: confirmed,
      currentPassword: currentPassword,
    );
    if (issues.isNotEmpty) {
      state = ProfileFormState(fieldIssues: issues);
      return false;
    }

    _inflight?.cancel();
    final cancel = _inflight = RequestCancellation();
    final key = ref.read(profileUuidProvider)();
    state = const ProfileFormState(submitting: true);

    final result = await ref
        .read(profileRepositoryProvider)
        .requestDeletion(
          currentPassword: currentPassword,
          idempotencyKey: key,
          cancellation: cancel,
        );
    if (!ref.mounted) return false;
    switch (result) {
      case Ok<AccountDeletionStatus>():
        await ref.read(sessionControllerProvider.notifier).onAccountDeleted();
        if (ref.mounted) state = const ProfileFormState(saved: true);
        return true;
      case Err<AccountDeletionStatus>(:final failure):
        state = mapProfileFailure(failure, startCooldown: _cooldown?.start);
        return false;
    }
  }

  Future<bool> retryNotice() async {
    await ref.read(remoteConfigProvider.notifier).refresh();
    return ref.read(profileDeletionNoticeProvider) != null;
  }
}
