import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ipr_mobile/core/providers.dart';
import 'package:ipr_mobile/features/branches/domain/entities/branch.dart';
import 'package:ipr_mobile/features/branches/domain/rules/branch_maps_uri.dart';
import 'package:ipr_mobile/features/branches/presentation/controllers/branches_controller.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:ipr_mobile/shared/widgets/product_image.dart';
import 'package:ipr_mobile/shared/widgets/state_widgets.dart';
import 'package:ipr_mobile/shared/widgets/whatsapp_button.dart';
import 'package:material_ui/material_ui.dart';

/// Ficha de una sede (`/branches/:slug`, RF-073..075).
///
/// Omite teléfonos ausentes sin mostrar `"null"` (`AC-073-2`), sustituye la
/// imagen ausente con marcador (`AC-073-3`) y si `upcoming` es verdadero no
/// muestra llamar, WhatsApp ni "Cómo llegar" (`AC-072-2`, `AC-074-5`).
class BranchDetailScreen extends ConsumerWidget {
  const new({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(branchBySlugProvider(slug));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.branchesDetailTitle)),
      body: SafeArea(
        top: false,
        child: AsyncView<Branch>(
          state: state,
          onRetry: () => unawaited(ref.read(branchesProvider.notifier).retry()),
          builder: (context, branch) => _BranchDetailBody(branch: branch),
        ),
      ),
    );
  }
}

class _BranchDetailBody extends ConsumerWidget {
  const new({required this.branch});

  final Branch branch;

  Future<void> _launchExternal(
    BuildContext context,
    WidgetRef ref,
    Uri uri,
    String errorText,
  ) async {
    final opened = await ref.read(externalLauncherProvider).open(uri);
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(errorText)));
  }

  static String _phoneTypeLabel(AppLocalizations l10n, BranchPhoneType type) =>
      switch (type) {
        BranchPhoneType.landline => l10n.branchesPhoneLandline,
        BranchPhoneType.salesParts => l10n.branchesPhoneSalesParts,
        BranchPhoneType.salesAc => l10n.branchesPhoneSalesAc,
        BranchPhoneType.mobile => l10n.branchesPhoneMobile,
        BranchPhoneType.mobileSecondary => l10n.branchesPhoneMobileSecondary,
        BranchPhoneType.other => l10n.branchesPhonesLabel,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final mapsUri = branch.upcoming ? null : buildBranchMapsUri(branch);
    final whatsapp = branch.upcoming ? null : branch.whatsappNumber;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(IprSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(IprRadius.lg),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: ProductImage(image: branch.image, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: IprSpace.s4),
          Text(branch.city, style: theme.textTheme.labelLarge),
          const SizedBox(height: IprSpace.s1),
          Semantics(
            header: true,
            child: Text(branch.name, style: theme.textTheme.headlineSmall),
          ),
          if (branch.address.isNotEmpty) ...[
            const SizedBox(height: IprSpace.s3),
            Text(l10n.branchesAddressLabel, style: theme.textTheme.labelMedium),
            const SizedBox(height: IprSpace.s1),
            Text(branch.address, style: theme.textTheme.bodyLarge),
          ],
          if (branch.upcoming) ...[
            const SizedBox(height: IprSpace.s4),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(IprSpace.s4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.branchesUpcomingBadge,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: IprSpace.s1),
                    Text(
                      l10n.branchesUpcomingBody,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            if (mapsUri != null) ...[
              const SizedBox(height: IprSpace.s4),
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: IprSpace.minTapTarget,
                ),
                child: FilledButton.icon(
                  onPressed: () => unawaited(
                    _launchExternal(
                      context,
                      ref,
                      mapsUri,
                      l10n.branchesMapsFailed,
                    ),
                  ),
                  icon: const ExcludeSemantics(child: Icon(Icons.map_outlined)),
                  label: Text(l10n.branchesDirectionsAction),
                ),
              ),
            ],
            if (whatsapp != null) ...[
              const SizedBox(height: IprSpace.s3),
              WhatsAppButton(
                label: l10n.branchesWhatsappAction,
                message: l10n.branchesWhatsappMessage(branch.name),
                phoneOverride: whatsapp,
              ),
            ],
            if (branch.phones.isNotEmpty) ...[
              const SizedBox(height: IprSpace.s5),
              Semantics(
                header: true,
                child: Text(
                  l10n.branchesPhonesLabel,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: IprSpace.s2),
              for (final phone in branch.phones) ...[
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: IprSpace.minTapTarget,
                  ),
                  child: OutlinedButton.icon(
                    onPressed: () => unawaited(
                      _launchExternal(
                        context,
                        ref,
                        Uri(scheme: 'tel', path: phone.dial),
                        l10n.branchesCallFailed,
                      ),
                    ),
                    icon: const ExcludeSemantics(
                      child: Icon(Icons.phone_outlined),
                    ),
                    label: Text(
                      '${_phoneTypeLabel(l10n, phone.type)}: ${phone.display}',
                    ),
                  ),
                ),
                const SizedBox(height: IprSpace.s2),
              ],
            ],
          ],
        ],
      ),
    );
  }
}
