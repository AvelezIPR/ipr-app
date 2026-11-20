import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ipr_mobile/features/authentication/domain/rules/auth_validation.dart';
import 'package:ipr_mobile/features/authentication/presentation/controllers/password_recovery_controller.dart';
import 'package:ipr_mobile/features/authentication/presentation/widgets/auth_form_widgets.dart';
import 'package:ipr_mobile/features/authentication/presentation/widgets/auth_texts.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:ipr_mobile/shared/navigation/routes.dart';
import 'package:material_ui/material_ui.dart';

/// Recuperación de contraseña `/password-recovery` (PT-17; RF-042, RF-045).
///
/// El servidor responde `202` exista o no la cuenta y la pantalla de
/// confirmación es SIEMPRE la misma ("si existe una cuenta recibirás un
/// correo"). El restablecimiento se completa en WordPress: no hay pantalla de
/// nueva contraseña en la app.
class PasswordRecoveryScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<PasswordRecoveryScreen> createState() =>
      _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState
    extends ConsumerState<PasswordRecoveryScreen> {
  final _email = TextEditingController();
  final _emailFocus = FocusNode();

  @override
  void dispose() {
    _email
      ..clear()
      ..dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = await ref
        .read(passwordRecoveryControllerProvider.notifier)
        .submit(_email.text);
    if (!mounted || ok) return;
    if (ref
        .read(passwordRecoveryControllerProvider)
        .fieldIssues
        .containsKey(AuthField.email)) {
      _emailFocus.requestFocus();
    }
  }

  void _backToLogin() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(passwordRecoveryControllerProvider);

    if (state.completed) {
      return AuthFormScaffold(
        title: l10n.authenticationRecoveryTitle,
        children: [
          Semantics(
            liveRegion: true,
            container: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.mark_email_read_outlined,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: IprSpace.s3),
                Text(
                  l10n.authenticationRecoverySentTitle,
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: IprSpace.s2),
                Text(
                  l10n.authenticationRecoverySentBody,
                  style: theme.textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: IprSpace.s5),
          AuthLinkButton(
            label: l10n.authenticationBackToLogin,
            onPressed: _backToLogin,
          ),
        ],
      );
    }

    return AuthFormScaffold(
      title: l10n.authenticationRecoveryTitle,
      children: [
        Text(
          l10n.authenticationRecoveryIntro,
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: IprSpace.s4),
        AuthProblemBanner(state: state),
        AuthTextField(
          controller: _email,
          focusNode: _emailFocus,
          label: l10n.authenticationFieldEmail,
          autofillHints: AuthAutofill.email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          errorText: authFieldError(l10n, state, AuthField.email),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: IprSpace.s5),
        AuthSubmitButton(
          label: l10n.authenticationRecoverySubmit,
          state: state,
          onPressed: _submit,
        ),
        const SizedBox(height: IprSpace.s3),
        AuthLinkButton(
          label: l10n.authenticationBackToLogin,
          onPressed: _backToLogin,
        ),
      ],
    );
  }
}
