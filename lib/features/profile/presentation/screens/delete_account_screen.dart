import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ipr_mobile/features/profile/domain/rules/profile_validation.dart';
import 'package:ipr_mobile/features/profile/presentation/controllers/delete_account_controller.dart';
import 'package:ipr_mobile/features/profile/presentation/widgets/profile_form_widgets.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Eliminación de cuenta con confirmación explícita y contraseña actual
/// (`/account/delete`, RF-110).
///
/// El texto de qué se elimina y qué se conserva viene exclusivamente de
/// `/config` (`accountDeletionNotice`, D-12): nunca se inventan plazos ni
/// textos legales.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _password = TextEditingController();
  bool _confirmed = false;
  bool _retryingNotice = false;

  @override
  void dispose() {
    _password
      ..clear()
      ..dispose();
    super.dispose();
  }

  Future<void> _retryNotice() async {
    if (_retryingNotice) return;
    setState(() => _retryingNotice = true);
    try {
      await ref.read(deleteAccountProvider.notifier).retryNotice();
    } finally {
      if (mounted) setState(() => _retryingNotice = false);
    }
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref
        .read(deleteAccountProvider.notifier)
        .submit(confirmed: _confirmed, currentPassword: _password.text);
    if (!mounted) return;
    if (!ok) {
      final state = ref.read(deleteAccountProvider);
      if (state.serverMessages.containsKey(ProfileField.currentPassword)) {
        _password.clear();
      }
      return;
    }
    _password.clear();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.profileDeleteSuccess)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(deleteAccountProvider);
    final notice = ref.watch(profileDeletionNoticeProvider);
    final confirmError = profileFieldError(
      l10n,
      state,
      ProfileField.deleteConfirm,
    );

    return ProfileFormScaffold(
      title: l10n.profileDeleteTitle,
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(IprSpace.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ProfileFailureBanner(state: state),
            DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(IprRadius.md),
                border: Border.all(color: theme.colorScheme.outline),
              ),
              child: Padding(
                padding: const EdgeInsets.all(IprSpace.s4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ExcludeSemantics(
                          child: Icon(
                            Icons.warning_amber_rounded,
                            color: theme.colorScheme.error,
                          ),
                        ),
                        const SizedBox(width: IprSpace.s2),
                        Expanded(
                          child: Semantics(
                            header: true,
                            child: Text(
                              l10n.profileDeleteWarningTitle,
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: IprSpace.s3),
                    // Texto plano servido por /config; si falta no se inventa
                    // ningún plazo ni detalle legal (D-12).
                    Text(
                      notice ?? l10n.profileDeleteNoticeUnavailable,
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (notice == null) ...[
                      const SizedBox(height: IprSpace.s3),
                      OutlinedButton(
                        onPressed: _retryingNotice ? null : _retryNotice,
                        child: Text(l10n.profileDeleteNoticeRetry),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: IprSpace.s4),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _confirmed,
              onChanged: state.submitting
                  ? null
                  : (v) => setState(() => _confirmed = v ?? false),
              title: Text(l10n.profileDeleteConfirmCheckbox),
            ),
            if (confirmError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: IprSpace.s3),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    confirmError,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: IprSpace.s2),
            Text(
              l10n.profileDeletePasswordIntro,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: IprSpace.s3),
            ProfilePasswordField(
              controller: _password,
              label: l10n.profileCurrentPasswordLabel,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              errorText: profileFieldError(
                l10n,
                state,
                ProfileField.currentPassword,
              ),
              onSubmitted: (_) => unawaited(_submit()),
            ),
            const SizedBox(height: IprSpace.s5),
            ProfileSubmitButton(
              label: state.submitting
                  ? l10n.profileDeleteDeleting
                  : l10n.profileDeleteSubmit,
              state: state,
              destructive: true,
              onPressed: () => unawaited(_submit()),
            ),
            const SizedBox(height: IprSpace.s3),
            ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: IprSpace.minTapTarget,
              ),
              child: OutlinedButton(
                onPressed: state.submitting
                    ? null
                    : () {
                        if (context.canPop()) context.pop();
                      },
                child: Text(l10n.profileDeleteCancel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
