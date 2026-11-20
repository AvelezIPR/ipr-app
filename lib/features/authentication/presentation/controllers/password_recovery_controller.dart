import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/authentication/authentication_providers.dart';
import 'package:ipr_mobile/features/authentication/domain/rules/auth_validation.dart';
import 'package:ipr_mobile/features/authentication/presentation/controllers/auth_form_controller.dart';
import 'package:ipr_mobile/features/authentication/presentation/controllers/auth_form_state.dart';

final NotifierProvider<PasswordRecoveryController, AuthFormState>
passwordRecoveryControllerProvider =
    NotifierProvider.autoDispose<PasswordRecoveryController, AuthFormState>(
      PasswordRecoveryController.new,
    );

/// Recuperación de contraseña (RF-042, RF-045). El servidor responde `202`
/// exista o no la cuenta y la app muestra siempre la misma confirmación; el
/// restablecimiento se completa en WordPress (no hay pantalla de nueva
/// contraseña en la app).
class PasswordRecoveryController extends AuthFormController {
  /// Valida y envía. Devuelve `true` si el servidor aceptó la solicitud.
  Future<bool> submit(String email) async {
    if (busy) return false;
    final issues = AuthValidation.forRecovery(email);
    if (issues.isNotEmpty) {
      rejectLocally(issues);
      return false;
    }
    final cancellation = startRequest();
    final result = await ref
        .read(authRepositoryProvider)
        .requestPasswordReset(email, cancellation: cancellation);
    if (!ref.mounted) return false;
    switch (result) {
      case Ok<void>():
        complete();
        return true;
      case Err<void>(:final failure):
        failWith(failure);
        return false;
    }
  }
}
