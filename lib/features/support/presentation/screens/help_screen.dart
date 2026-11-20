import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ipr_mobile/core/config/remote_config_controller.dart';
import 'package:ipr_mobile/core/providers.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:ipr_mobile/shared/navigation/routes.dart';
import 'package:ipr_mobile/shared/widgets/whatsapp_button.dart';
import 'package:material_ui/material_ui.dart';

/// Pantalla de Ayuda y contacto (`/support`, RF-094, RF-095).
///
/// Agrupa canales corporativos sin requerir sesión (`AC-094-5`, `AC-095-4`),
/// sin prometer SLA (`AC-094-4`) y sin datos personales de asesores (`AC-095-3`).
class HelpScreen extends ConsumerWidget {
  const new({super.key});

  Future<void> _callPhone(
    BuildContext context,
    WidgetRef ref,
    String dial,
  ) async {
    final l10n = AppLocalizations.of(context);
    final opened = await ref
        .read(externalLauncherProvider)
        .open(Uri(scheme: 'tel', path: dial));
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.supportHelpCallFailed)));
  }

  Future<void> _writeEmail(
    BuildContext context,
    WidgetRef ref,
    String email,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final opened = await ref
        .read(externalLauncherProvider)
        .open(Uri(scheme: 'mailto', path: email));
    if (opened || !context.mounted) return;
    await Clipboard.setData(ClipboardData(text: email));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(l10n.supportHelpEmailCopied(email))),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final config = ref.watch(remoteConfigProvider.select((s) => s.config));
    final dial = config.phoneDial?.trim();
    final phoneDisplay = config.phoneDisplay?.trim();
    final salesEmail = config.salesEmail?.trim();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.supportHelpTitle)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(IprSpace.s4),
          children: [
            Text(l10n.supportHelpIntro, style: theme.textTheme.bodyLarge),
            const SizedBox(height: IprSpace.s4),
            WhatsAppButton(
              label: l10n.supportHelpWhatsapp,
              message: l10n.sharedWhatsappMsgAdvice,
            ),
            const SizedBox(height: IprSpace.s3),
            WhatsAppButton(
              label: l10n.supportHelpQuoteWhatsapp,
              message: l10n.sharedWhatsappMsgQuote,
              filled: false,
            ),
            const SizedBox(height: IprSpace.s5),
            Semantics(
              header: true,
              child: Text(
                l10n.supportHelpChannelsTitle,
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: IprSpace.s2),
            if (dial != null && dial.isNotEmpty)
              _ChannelTile(
                icon: Icons.phone_outlined,
                title: l10n.supportHelpPhone,
                subtitle: (phoneDisplay != null && phoneDisplay.isNotEmpty)
                    ? phoneDisplay
                    : dial,
                onTap: () => unawaited(_callPhone(context, ref, dial)),
              ),
            if (salesEmail != null && salesEmail.isNotEmpty)
              _ChannelTile(
                icon: Icons.email_outlined,
                title: l10n.supportHelpEmail,
                subtitle: salesEmail,
                onTap: () => unawaited(_writeEmail(context, ref, salesEmail)),
              ),
            _ChannelTile(
              icon: Icons.feedback_outlined,
              title: l10n.supportHelpPqrs,
              subtitle: l10n.supportHelpPqrsSubtitle,
              onTap: () => unawaited(context.push(Routes.pqrs)),
            ),
            _ChannelTile(
              icon: Icons.engineering_outlined,
              title: l10n.supportHelpEngineering,
              subtitle: l10n.supportHelpEngineeringSubtitle,
              onTap: () => unawaited(context.push(Routes.engineering)),
            ),
            _ChannelTile(
              icon: Icons.storefront_outlined,
              title: l10n.supportHelpBranches,
              subtitle: l10n.supportHelpBranchesSubtitle,
              onTap: () => unawaited(context.push(Routes.branches)),
            ),
            _ChannelTile(
              icon: Icons.gavel_outlined,
              title: l10n.supportHelpLegal,
              onTap: () => unawaited(context.push(Routes.legal)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: IprSpace.s2),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: IprSpace.minTapTarget),
          child: Padding(
            padding: const EdgeInsets.all(IprSpace.s4),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Icon(icon, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: IprSpace.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleSmall),
                      if (subtitle != null) ...[
                        const SizedBox(height: IprSpace.s1),
                        Text(subtitle!, style: theme.textTheme.bodyMedium),
                      ],
                    ],
                  ),
                ),
                ExcludeSemantics(
                  child: Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
