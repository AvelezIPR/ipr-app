import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ipr_mobile/features/profile/domain/rules/profile_validation.dart';
import 'package:ipr_mobile/features/profile/presentation/controllers/profile_controllers.dart';
import 'package:ipr_mobile/features/profile/presentation/widgets/profile_form_widgets.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Cambio de contraseña exigiendo la actual (`/account/password`, RF-105).
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  final _nextFocus = FocusNode();
  final _confirmFocus = FocusNode();

  @override
  void dispose() {
    _current.clear();
    _next.clear();
    _confirm.clear();
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    _nextFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref
        .read(changePasswordProvider.notifier)
        .submit(
          currentPassword: _current.text,
          newPassword: _next.text,
          confirmPassword: _confirm.text,
        );
    if (!mounted) return;
    if (!ok) {
      final state = ref.read(changePasswordProvider);
      if (state.serverMessages.containsKey(ProfileField.currentPassword)) {
        _current.clear();
      }
      return;
    }
    _current.clear();
    _next.clear();
    _confirm.clear();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.profilePasswordSaved)));
    if (context.canPop()) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(changePasswordProvider);

    return ProfileFormScaffold(
      title: l10n.profilePasswordTitle,
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(IprSpace.s4),
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ProfileFailureBanner(state: state),
              Text(
                l10n.profilePasswordIntro,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: IprSpace.s4),
              ProfilePasswordField(
                controller: _current,
                label: l10n.profileCurrentPasswordLabel,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.next,
                errorText: profileFieldError(
                  l10n,
                  state,
                  ProfileField.currentPassword,
                ),
                onSubmitted: (_) => _nextFocus.requestFocus(),
              ),
              const SizedBox(height: IprSpace.s3),
              ProfilePasswordField(
                controller: _next,
                focusNode: _nextFocus,
                label: l10n.profileNewPasswordLabel,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
                errorText: profileFieldError(
                  l10n,
                  state,
                  ProfileField.newPassword,
                ),
                onSubmitted: (_) => _confirmFocus.requestFocus(),
              ),
              const SizedBox(height: IprSpace.s3),
              ProfilePasswordField(
                controller: _confirm,
                focusNode: _confirmFocus,
                label: l10n.profileConfirmPasswordLabel,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                errorText: profileFieldError(
                  l10n,
                  state,
                  ProfileField.confirmPassword,
                ),
                onSubmitted: (_) => unawaited(_submit()),
              ),
              const SizedBox(height: IprSpace.s5),
              ProfileSubmitButton(
                label: l10n.profilePasswordSave,
                state: state,
                onPressed: () => unawaited(_submit()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
