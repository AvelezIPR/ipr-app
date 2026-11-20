import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ipr_mobile/features/authentication/domain/entities/registration.dart';
import 'package:ipr_mobile/features/authentication/domain/rules/auth_validation.dart';
import 'package:ipr_mobile/features/authentication/presentation/controllers/auth_form_state.dart';
import 'package:ipr_mobile/features/authentication/presentation/controllers/register_controller.dart';
import 'package:ipr_mobile/features/authentication/presentation/screens/auth_routes.dart';
import 'package:ipr_mobile/features/authentication/presentation/widgets/auth_form_widgets.dart';
import 'package:ipr_mobile/features/authentication/presentation/widgets/auth_texts.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:ipr_mobile/shared/navigation/routes.dart';
import 'package:material_ui/material_ui.dart';

/// Registro `/register` (PT-15; RF-038, RF-039, RF-045).
///
/// * Nombres, Apellidos, Correo, Contraseña y Confirmar contraseña, más la
///   casilla OBLIGATORIA (sin marcar por defecto) de términos y política de
///   datos, con enlaces a `Routes.legal`: el formulario conserva lo escrito.
/// * El cuerpo lleva `acceptance` con las versiones de `GET /config`; si no
///   hay versiones el registro queda bloqueado y se explica (falla cerrado).
/// * `409`: mensaje NEUTRAL (`RegisterConflictPolicy`, pendiente de H-03).
/// * Tras `201` la sesión queda guardada y el router navega solo.
/// * Con datos escritos, salir pide confirmar el descarte.
class RegisterScreen extends ConsumerStatefulWidget {
  const new({super.key, this.from});

  /// Ruta interna de origen: solo se reenvía al login (ver `LoginScreen`).
  final String? from;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _email = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _emailFocus = FocusNode();
  final _firstNameFocus = FocusNode();
  final _lastNameFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();
  final _acceptanceFocus = FocusNode();

  bool _accepted = false;
  bool _discardConfirmed = false;

  late final Listenable _inputs = Listenable.merge([
    _email,
    _firstName,
    _lastName,
    _password,
    _confirm,
  ]);

  bool get _dirty =>
      _accepted ||
      _email.text.isNotEmpty ||
      _firstName.text.isNotEmpty ||
      _lastName.text.isNotEmpty ||
      _password.text.isNotEmpty ||
      _confirm.text.isNotEmpty;

  @override
  void dispose() {
    // Limpia lo escrito (la contraseña no debe sobrevivir a la pantalla).
    for (final controller in [
      _email,
      _firstName,
      _lastName,
      _password,
      _confirm,
    ]) {
      controller
        ..clear()
        ..dispose();
    }
    for (final focus in [
      _emailFocus,
      _firstNameFocus,
      _lastNameFocus,
      _passwordFocus,
      _confirmFocus,
      _acceptanceFocus,
    ]) {
      focus.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = await ref
        .read(registerControllerProvider.notifier)
        .submit(
          RegistrationForm(
            email: _email.text,
            firstName: _firstName.text,
            lastName: _lastName.text,
            password: _password.text,
            confirmPassword: _confirm.text,
            acceptedLegal: _accepted,
          ),
        );
    if (!mounted || ok) return;
    final issues = ref.read(registerControllerProvider).fieldIssues;
    // Foco en el primer campo con error, en orden de pantalla.
    final order = <(AuthField, FocusNode)>[
      (AuthField.firstName, _firstNameFocus),
      (AuthField.lastName, _lastNameFocus),
      (AuthField.email, _emailFocus),
      (AuthField.password, _passwordFocus),
      (AuthField.confirmPassword, _confirmFocus),
      (AuthField.acceptance, _acceptanceFocus),
    ];
    for (final (field, focus) in order) {
      if (issues.containsKey(field)) {
        focus.requestFocus();
        return;
      }
    }
  }

  Future<void> _confirmDiscard() async {
    final l10n = AppLocalizations.of(context);
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.authenticationDiscardTitle),
        content: Text(l10n.authenticationDiscardBody),
        actions: [
          // "Seguir editando" es la acción segura y recibe el foco inicial.
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(l10n.authenticationDiscardCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(l10n.authenticationDiscardConfirm),
          ),
        ],
      ),
    );
    if (discard != true || !mounted) return;
    setState(() => _discardConfirmed = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(registerControllerProvider);
    final legalReady = ref.watch(legalAcceptanceProvider) != null;
    final acceptanceError = authFieldError(l10n, state, AuthField.acceptance);

    return ListenableBuilder(
      listenable: _inputs,
      builder: (context, _) => PopScope(
        canPop: _discardConfirmed || !_dirty,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) unawaited(_confirmDiscard());
        },
        child: AuthFormScaffold(
          title: l10n.authenticationRegisterTitle,
          children: [
            if (!legalReady)
              AuthBanner(
                message:
                    '${l10n.authenticationLegalUnavailableTitle}. '
                    '${l10n.authenticationLegalUnavailableBody}',
                actions: [
                  AuthLinkButton(
                    label: l10n.actionRetry,
                    onPressed: () => ref
                        .read(registerControllerProvider.notifier)
                        .reloadLegalVersions(),
                  ),
                ],
              ),
            AuthProblemBanner(
              state: state,
              actions: state.problem == AuthProblem.accountConflict
                  ? [
                      AuthLinkButton(
                        label: l10n.authenticationRegisterConflictLogin,
                        onPressed: () => context.pushReplacement(
                          authLocation(Routes.login, widget.from),
                        ),
                      ),
                      AuthLinkButton(
                        label: l10n.authenticationRegisterConflictRecover,
                        onPressed: () => context.push(Routes.passwordRecovery),
                      ),
                    ]
                  : const [],
            ),
            AuthTextField(
              controller: _firstName,
              focusNode: _firstNameFocus,
              label: l10n.authenticationFieldFirstName,
              autofillHints: AuthAutofill.givenName,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              errorText: authFieldError(l10n, state, AuthField.firstName),
            ),
            const SizedBox(height: IprSpace.s4),
            AuthTextField(
              controller: _lastName,
              focusNode: _lastNameFocus,
              label: l10n.authenticationFieldLastName,
              autofillHints: AuthAutofill.familyName,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              errorText: authFieldError(l10n, state, AuthField.lastName),
            ),
            const SizedBox(height: IprSpace.s4),
            AuthTextField(
              controller: _email,
              focusNode: _emailFocus,
              label: l10n.authenticationFieldEmail,
              autofillHints: AuthAutofill.email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              errorText: authFieldError(l10n, state, AuthField.email),
            ),
            const SizedBox(height: IprSpace.s4),
            PasswordField(
              controller: _password,
              focusNode: _passwordFocus,
              label: l10n.authenticationFieldNewPassword,
              autofillHints: AuthAutofill.newPassword,
              textInputAction: TextInputAction.next,
              errorText: authFieldError(
                l10n,
                state,
                AuthField.password,
                newPassword: true,
              ),
            ),
            const SizedBox(height: IprSpace.s4),
            PasswordField(
              controller: _confirm,
              focusNode: _confirmFocus,
              label: l10n.authenticationFieldConfirmPassword,
              autofillHints: AuthAutofill.newPassword,
              textInputAction: TextInputAction.done,
              errorText: authFieldError(l10n, state, AuthField.confirmPassword),
              onSubmitted: (_) => _acceptanceFocus.requestFocus(),
            ),
            const SizedBox(height: IprSpace.s3),
            CheckboxListTile(
              focusNode: _acceptanceFocus,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _accepted,
              onChanged: (value) => setState(() => _accepted = value ?? false),
              title: Text(l10n.authenticationAcceptanceLabel),
              isError: acceptanceError != null,
            ),
            if (acceptanceError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: IprSpace.s2),
                child: Semantics(
                  liveRegion: true,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ExcludeSemantics(
                        child: Icon(
                          Icons.error_outline,
                          size: 20,
                          color: theme.colorScheme.error,
                        ),
                      ),
                      const SizedBox(width: IprSpace.s2),
                      Expanded(
                        child: Text(
                          acceptanceError,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            AuthLinkButton(
              label: l10n.authenticationTermsLink,
              onPressed: () => context.push(Routes.legal),
            ),
            AuthLinkButton(
              label: l10n.authenticationPrivacyLink,
              onPressed: () => context.push(Routes.legal),
            ),
            const SizedBox(height: IprSpace.s4),
            AuthSubmitButton(
              label: l10n.authenticationRegisterSubmit,
              state: state,
              enabled: legalReady,
              onPressed: _submit,
            ),
            const SizedBox(height: IprSpace.s3),
            AuthLinkButton(
              label: l10n.authenticationRegisterLoginLink,
              onPressed: () => context.pushReplacement(
                authLocation(Routes.login, widget.from),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
