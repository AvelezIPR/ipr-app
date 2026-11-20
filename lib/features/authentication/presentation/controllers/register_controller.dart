import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ipr_mobile/core/config/remote_config_controller.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/authentication/authentication_providers.dart';
import 'package:ipr_mobile/features/authentication/domain/entities/authenticated_session.dart';
import 'package:ipr_mobile/features/authentication/domain/entities/registration.dart';
import 'package:ipr_mobile/features/authentication/domain/rules/auth_validation.dart';
import 'package:ipr_mobile/features/authentication/domain/rules/register_conflict_policy.dart';
import 'package:ipr_mobile/features/authentication/presentation/controllers/auth_form_controller.dart';
import 'package:ipr_mobile/features/authentication/presentation/controllers/auth_form_state.dart';

/// Versiones vigentes de términos y política (`GET /config`, RF-039).
///
/// `null` si faltan: el registro **no** se permite (falla cerrado) y nunca se
/// inventa una versión.
final Provider<LegalAcceptance?> legalAcceptanceProvider =
    Provider.autoDispose<LegalAcceptance?>((ref) {
      final versions = ref.watch(
        remoteConfigProvider.select(
          (s) => (s.config.termsVersion, s.config.privacyPolicyVersion),
        ),
      );
      return LegalAcceptance.tryCreate(
        termsVersion: versions.$1,
        privacyPolicyVersion: versions.$2,
      );
    });

final NotifierProvider<RegisterController, AuthFormState>
registerControllerProvider =
    NotifierProvider.autoDispose<RegisterController, AuthFormState>(
      RegisterController.new,
    );

/// Registro de cliente (RF-038, RF-039, RF-045).
class RegisterController extends AuthFormController {
  /// Reintenta cargar `/config` (versiones legales) sin salir del formulario.
  Future<void> reloadLegalVersions() =>
      ref.read(remoteConfigProvider.notifier).refresh();

  /// Valida y envía. Devuelve `true` solo si la sesión quedó guardada.
  Future<bool> submit(RegistrationForm form) async {
    if (busy) return false;

    // Falla cerrado: sin versiones vigentes no hay forma de registrar la
    // aceptación, así que ni siquiera se valida ni se envía.
    final acceptance = ref.read(legalAcceptanceProvider);
    if (acceptance == null) {
      state = const AuthFormState(problem: AuthProblem.legalUnavailable);
      return false;
    }

    final issues = AuthValidation.forRegistration(form);
    if (issues.isNotEmpty) {
      rejectLocally(issues);
      return false;
    }

    final cancellation = startRequest();
    final result = await ref
        .read(authRepositoryProvider)
        .register(
          RegistrationRequest(
            email: form.email,
            firstName: form.firstName,
            lastName: form.lastName,
            password: form.password,
            acceptance: acceptance,
          ),
          cancellation: cancellation,
        );
    if (!ref.mounted) return false;
    switch (result) {
      case Ok<AuthenticatedSession>(:final value):
        return await establishSession(value);
      case Err<AuthenticatedSession>(:final failure):
        if (RegisterConflictPolicy.appliesTo(failure)) {
          switch (RegisterConflictPolicy.resolution) {
            case RegisterConflictResolution.neutralNotice:
              state = const AuthFormState(problem: AuthProblem.accountConflict);
          }
        } else {
          failWith(failure);
        }
        return false;
    }
  }
}
