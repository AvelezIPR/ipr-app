import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/providers.dart';
import 'package:ipr_mobile/features/profile/domain/rules/email_change_conflict_policy.dart';
import 'package:ipr_mobile/features/profile/domain/rules/profile_validation.dart';
import 'package:ipr_mobile/features/profile/presentation/controllers/profile_form_state.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:ipr_mobile/shared/widgets/failure_messages.dart';
import 'package:ipr_mobile/shared/widgets/sensitive_screen.dart';
import 'package:material_ui/material_ui.dart';

/// Estructura común de pantallas sensibles de perfil (`SensitiveScreen`,
/// SC-035, RNF-035), desplazable y compatible con texto al 200 % (RNF-068).
class ProfileFormScaffold extends ConsumerWidget {
  const new({required this.title, required this.body, super.key});

  final String title;
  final Widget body;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: SensitiveScreen(
      protection: ref.watch(screenProtectionProvider),
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: body,
          ),
        ),
      ),
    ),
  );
}

/// Campo de contraseña enmascarado con botón accesible y re-enmascarado al
/// pasar a segundo plano (SC-035, RNF-073).
class ProfilePasswordField extends StatefulWidget {
  const new({
    required this.controller,
    required this.label,
    required this.autofillHints,
    super.key,
    this.focusNode,
    this.errorText,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final Iterable<String> autofillHints;
  final FocusNode? focusNode;
  final String? errorText;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  @override
  State<ProfilePasswordField> createState() => _ProfilePasswordFieldState();
}

class _ProfilePasswordFieldState extends State<ProfilePasswordField>
    with WidgetsBindingObserver {
  bool _obscured = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && !_obscured) {
      setState(() => _obscured = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      obscureText: _obscured,
      autofillHints: widget.autofillHints,
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: widget.textInputAction,
      onSubmitted: widget.onSubmitted,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        labelText: widget.label,
        errorText: widget.errorText,
        errorMaxLines: 4,
        suffixIcon: IconButton(
          tooltip: _obscured
              ? l10n.profilePasswordShow
              : l10n.profilePasswordHide,
          icon: Icon(_obscured ? Icons.visibility : Icons.visibility_off),
          constraints: const BoxConstraints(
            minWidth: IprSpace.minTapTarget,
            minHeight: IprSpace.minTapTarget,
          ),
          onPressed: () => setState(() => _obscured = !_obscured),
        ),
      ),
    );
  }
}

/// Aviso de error o espera en formularios de perfil (ícono + texto, nunca solo
/// color).
class ProfileBanner extends StatelessWidget {
  const new({
    required this.message,
    super.key,
    this.countdownText,
    this.isError = true,
  });

  final String message;
  final String? countdownText;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: IprSpace.s4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isError ? scheme.errorContainer : scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(IprRadius.md),
          border: Border.all(color: isError ? scheme.error : scheme.outline),
        ),
        child: Padding(
          padding: const EdgeInsets.all(IprSpace.s3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      isError ? Icons.error_outline : Icons.info_outline,
                      color: isError ? scheme.error : scheme.primary,
                    ),
                  ),
                  const SizedBox(width: IprSpace.s2),
                  Expanded(
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        message,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (countdownText != null) ...[
                const SizedBox(height: IprSpace.s2),
                Text(countdownText!, style: theme.textTheme.bodyMedium),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileFailureBanner extends StatelessWidget {
  const new({required this.state, super.key});

  final ProfileFormState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final message = profileFailureMessage(l10n, state);
    if (message == null) return const SizedBox.shrink();
    return ProfileBanner(
      message: message,
      countdownText: state.coolingDown
          ? l10n.profileRateLimitedWait(
              profileWaitText(l10n, state.cooldownSeconds),
            )
          : null,
    );
  }
}

class ProfileSubmitButton extends StatelessWidget {
  const new({
    required this.label,
    required this.state,
    required this.onPressed,
    super.key,
    this.destructive = false,
  });

  final String label;
  final ProfileFormState state;
  final VoidCallback onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final text = state.coolingDown
        ? l10n.profileSubmitWait(profileWaitText(l10n, state.cooldownSeconds))
        : label;
    final style = destructive
        ? FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          )
        : null;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: IprSpace.minTapTarget),
      child: FilledButton(
        style: style,
        onPressed: state.canSubmit ? onPressed : null,
        child: state.submitting
            ? Semantics(
                liveRegion: true,
                label: l10n.profileSubmitting,
                child: const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              )
            : Text(text, textAlign: TextAlign.center),
      ),
    );
  }
}

String profileWaitText(AppLocalizations l10n, int seconds) {
  final minutes = seconds ~/ 60;
  final rest = seconds % 60;
  if (minutes > 0) return l10n.profileWaitMinutesSeconds(minutes, rest);
  return l10n.profileWaitSeconds(seconds);
}

String? profileFieldError(
  AppLocalizations l10n,
  ProfileFormState state,
  ProfileField field,
) {
  final server = state.serverMessages[field];
  if (server != null && server.isNotEmpty) return server;
  if (server != null &&
      field == ProfileField.currentPassword &&
      state.failure is Validation) {
    return l10n.profileCurrentPasswordInvalid;
  }
  final issue = state.fieldIssues[field];
  if (issue == null) return null;
  return switch (issue) {
    ProfileFieldIssue.required => l10n.profileErrorRequired,
    ProfileFieldIssue.tooLong => l10n.profileErrorTooLong(
      ProfileLimits.maxFor(field),
    ),
    ProfileFieldIssue.emailInvalid => l10n.profileErrorEmailInvalid,
    ProfileFieldIssue.emailUnchanged => l10n.profileEmailUnchanged,
    ProfileFieldIssue.passwordTooShort => l10n.profileErrorPasswordShort,
    ProfileFieldIssue.passwordMismatch => l10n.profileErrorPasswordMismatch,
    ProfileFieldIssue.nationalIdInvalid => l10n.profileErrorNationalId,
    ProfileFieldIssue.phoneInvalid => l10n.profileErrorPhone,
    ProfileFieldIssue.departmentInvalid => l10n.profileErrorDepartment,
    ProfileFieldIssue.cityInvalid => l10n.profileErrorCity,
    ProfileFieldIssue.confirmationRequired => l10n.profileDeleteConfirmRequired,
  };
}

String? profileFailureMessage(AppLocalizations l10n, ProfileFormState state) {
  if (state.emailConflict) {
    return EmailChangeConflictPolicy.current.treatConflictAsNeutral
        ? l10n.profileEmailConflict
        : l10n.profileEmailConflict;
  }
  final failure = state.failure;
  if (failure == null) return null;
  if (failure is Validation &&
      failure.code == 'current_password_invalid' &&
      state.serverMessages.isNotEmpty) {
    return null; // Ya se muestra junto al campo de contraseña actual.
  }
  return failureText(l10n, failure);
}
