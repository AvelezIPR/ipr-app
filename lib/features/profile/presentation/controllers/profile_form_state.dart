import 'dart:async';

import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/features/profile/domain/rules/profile_validation.dart';
import 'package:meta/meta.dart';

/// Estado de un formulario de perfil, direcciones, contraseña o eliminación.
/// Nunca almacena valores escritos ni contraseñas.
@immutable
final class ProfileFormState {
  const new({
    this.submitting = false,
    this.cooldownSeconds = 0,
    this.fieldIssues = const {},
    this.serverMessages = const {},
    this.failure,
    this.emailConflict = false,
    this.saved = false,
  });

  final bool submitting;
  final int cooldownSeconds;
  final Map<ProfileField, ProfileFieldIssue> fieldIssues;
  final Map<ProfileField, String> serverMessages;
  final AppFailure? failure;
  final bool emailConflict;
  final bool saved;

  bool get coolingDown => cooldownSeconds > 0;
  bool get canSubmit => !submitting && !coolingDown;

  ProfileFormState withCooldown(int seconds) => ProfileFormState(
    cooldownSeconds: seconds,
    failure: seconds == 0 ? null : failure,
  );
}

/// Cuenta regresiva de un segundo para `429 Retry-After`.
final class ProfileCooldown {
  new({required this.onTick});

  final void Function(int remaining) onTick;
  Timer? _timer;
  int _remaining = 0;

  void start(int seconds) {
    cancel();
    _remaining = seconds;
    onTick(_remaining);
    if (_remaining <= 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _remaining--;
      if (_remaining <= 0) {
        cancel();
        onTick(0);
      } else {
        onTick(_remaining);
      }
    });
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}

/// Convierte [AppFailure] en [ProfileFormState] mapeando `Validation.fields`
/// y `RateLimited.retryAfter`.
ProfileFormState mapProfileFailure(
  AppFailure failure, {
  void Function(int seconds)? startCooldown,
  bool isEmailChange = false,
}) {
  switch (failure) {
    case RateLimited(:final retryAfter):
      if (retryAfter != null && retryAfter > 0 && startCooldown != null) {
        startCooldown(retryAfter);
      }
      return ProfileFormState(
        cooldownSeconds: (retryAfter != null && retryAfter > 0)
            ? retryAfter
            : 0,
        failure: failure,
      );
    case Conflict(code: 'email_in_use') when isEmailChange:
      return ProfileFormState(failure: failure, emailConflict: true);
    case Validation(:final fields):
      final mapped = <ProfileField, String>{};
      var unmapped = false;
      for (final err in fields) {
        final field = ProfileField.fromServer(err.field);
        if (field == null) {
          unmapped = true;
        } else {
          mapped[field] = err.message.trim();
        }
      }
      return (mapped.isNotEmpty && !unmapped)
          ? ProfileFormState(serverMessages: mapped)
          : ProfileFormState(serverMessages: mapped, failure: failure);
    default:
      return ProfileFormState(failure: failure);
  }
}
