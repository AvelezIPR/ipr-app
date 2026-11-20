import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ipr_mobile/features/profile/presentation/controllers/data_rights_controller.dart';
import 'package:ipr_mobile/features/profile/presentation/widgets/profile_form_widgets.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:ipr_mobile/shared/navigation/routes.dart';
import 'package:ipr_mobile/shared/widgets/whatsapp_button.dart';
import 'package:material_ui/material_ui.dart';

/// Canal de derechos del titular (`/account/data-rights`, RF-111).
///
/// Informa que la supresión puede hacerse directamente desde la app (AC-111-3)
/// y expone el canal corporativo publicado en `/config` (`dataRightsChannel`,
/// D-12) sin inventar URLs ni correos.
class DataRightsScreen extends ConsumerWidget {
  const new({super.key});

  Future<void> _openPortal(
    BuildContext context,
    WidgetRef ref,
    String url,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final opened = await ref
        .read(dataRightsControllerProvider.notifier)
        .openPortal(url);
    if (opened || !context.mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.profileDataRightsOpenFailed)));
  }

  Future<void> _contactEmail(
    BuildContext context,
    WidgetRef ref,
    String email,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final opened = await ref
        .read(dataRightsControllerProvider.notifier)
        .openEmail(email);
    if (opened) return;
    await Clipboard.setData(ClipboardData(text: email));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(l10n.profileDataRightsEmailCopied(email))),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final channel = ref.watch(dataRightsChannelProvider);
    final busy = ref.watch(dataRightsControllerProvider);

    return ProfileFormScaffold(
      title: l10n.profileDataRightsTitle,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(IprSpace.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.profileDataRightsIntro, style: theme.textTheme.bodyLarge),
            const SizedBox(height: IprSpace.s5),
            Semantics(
              header: true,
              child: Text(
                l10n.profileDataRightsDirectDeletionTitle,
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: IprSpace.s2),
            Text(
              l10n.profileDataRightsDirectDeletionBody,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: IprSpace.s3),
            ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: IprSpace.minTapTarget,
              ),
              child: OutlinedButton.icon(
                onPressed: () => unawaited(context.push(Routes.deleteAccount)),
                icon: const ExcludeSemantics(child: Icon(Icons.delete_outline)),
                label: Text(l10n.profileDataRightsDirectDeletionButton),
              ),
            ),
            const Divider(height: IprSpace.s7),
            Semantics(
              header: true,
              child: Text(
                l10n.profileDataRightsChannelTitle,
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: IprSpace.s3),
            if (channel.url case final url?) ...[
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: IprSpace.minTapTarget,
                ),
                child: FilledButton.icon(
                  onPressed: busy
                      ? null
                      : () => unawaited(_openPortal(context, ref, url)),
                  icon: const ExcludeSemantics(child: Icon(Icons.open_in_new)),
                  label: Text(l10n.profileDataRightsOpenPortal),
                ),
              ),
              const SizedBox(height: IprSpace.s3),
            ],
            if (channel.email case final email?) ...[
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: IprSpace.minTapTarget,
                ),
                child: OutlinedButton.icon(
                  onPressed: () =>
                      unawaited(_contactEmail(context, ref, email)),
                  icon: const ExcludeSemantics(
                    child: Icon(Icons.email_outlined),
                  ),
                  label: Text(l10n.profileDataRightsEmailLabel(email)),
                ),
              ),
              const SizedBox(height: IprSpace.s2),
              TextButton.icon(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final msg = l10n.profileDataRightsEmailCopied(email);
                  await Clipboard.setData(ClipboardData(text: email));
                  messenger
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(content: Text(msg)));
                },
                icon: const ExcludeSemantics(child: Icon(Icons.copy, size: 18)),
                label: Text(l10n.profileDataRightsCopyEmail),
              ),
            ],
            if (!channel.hasAny) ...[
              Text(
                l10n.profileDataRightsUnavailable,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: IprSpace.s3),
              FilledButton(
                onPressed: busy
                    ? null
                    : () => unawaited(
                        ref
                            .read(dataRightsControllerProvider.notifier)
                            .retryConfig(),
                      ),
                child: Text(l10n.actionRetry),
              ),
              const SizedBox(height: IprSpace.s3),
              WhatsAppButton(
                label: l10n.actionContactWhatsApp,
                message: l10n.sharedWhatsappMsgAdvice,
                filled: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
