import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/features/authentication/domain/rules/auth_validation.dart';
import 'package:ipr_mobile/features/authentication/presentation/controllers/auth_form_state.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/widgets/failure_messages.dart';

/// Espera como `m:ss` (p. ej. `1:05`).
String formatWait(int seconds) {
  final safe = seconds < 0 ? 0 : seconds;
  final minutes = safe ~/ 60;
  final rest = (safe % 60).toString().padLeft(2, '0');
  return '$minutes:$rest';
}

/// Texto del error de un campo o `null` si no hay. Gana el error de la
/// validación local; si no, el que devolvió el servidor para ese campo.
///
/// [newPassword] distingue la contraseña nueva (registro) de la del login.
String? authFieldError(
  AppLocalizations l10n,
  AuthFormState state,
  AuthField field, {
  bool newPassword = false,
}) {
  final issue = state.fieldIssues[field];
  if (issue != null) {
    return switch (issue) {
      FieldIssue.required => switch (field) {
        AuthField.login => l10n.authenticationErrorLoginRequired,
        AuthField.email => l10n.authenticationErrorEmailRequired,
        AuthField.firstName => l10n.authenticationErrorFirstNameRequired,
        AuthField.lastName => l10n.authenticationErrorLastNameRequired,
        AuthField.password =>
          newPassword
              ? l10n.authenticationErrorNewPasswordRequired
              : l10n.authenticationErrorPasswordRequired,
        AuthField.confirmPassword => l10n.authenticationErrorConfirmRequired,
        AuthField.acceptance => l10n.authenticationErrorAcceptanceRequired,
      },
      FieldIssue.emailInvalid => l10n.authenticationErrorEmailInvalid,
      FieldIssue.tooLong => l10n.authenticationErrorTooLong(
        AuthLimits.maxFor(field),
      ),
      FieldIssue.passwordTooShort => l10n.authenticationErrorPasswordTooShort(
        AuthLimits.passwordMin,
      ),
      FieldIssue.passwordMismatch => l10n.authenticationErrorPasswordMismatch,
      FieldIssue.acceptanceRequired =>
        l10n.authenticationErrorAcceptanceRequired,
    };
  }
  final server = state.serverMessages[field];
  if (server == null) return null;
  return server.isEmpty ? l10n.authenticationErrorServerField : server;
}

/// Texto del aviso de formulario o `null` si no hay (o si es el aviso de
/// documentos legales, que tiene su propio bloque).
String? authProblemText(AppLocalizations l10n, AuthFormState state) {
  final problem = state.problem;
  if (problem == null) return null;
  return switch (problem) {
    AuthProblem.invalidCredentials =>
      l10n.authenticationLoginInvalidCredentials,
    AuthProblem.rateLimited => l10n.authenticationRateLimitedMessage,
    AuthProblem.accountConflict => l10n.authenticationRegisterConflictNotice,
    AuthProblem.legalUnavailable => null,
    AuthProblem.other => failureText(
      l10n,
      state.failure ?? const UnknownFailure(),
    ),
  };
}
