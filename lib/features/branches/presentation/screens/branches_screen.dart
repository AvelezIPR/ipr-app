import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ipr_mobile/features/branches/domain/entities/branch.dart';
import 'package:ipr_mobile/features/branches/presentation/controllers/branches_controller.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:ipr_mobile/shared/navigation/routes.dart';
import 'package:ipr_mobile/shared/widgets/state_widgets.dart';
import 'package:ipr_mobile/shared/widgets/whatsapp_button.dart';
import 'package:material_ui/material_ui.dart';

/// Listado de sedes agrupado por ciudad (`/branches`, RF-072, AC-072-1..6).
class BranchesScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(branchesProvider);
    final controller = ref.read(branchesProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.branchesTitle)),
      body: SafeArea(
        top: false,
        child: AsyncView<List<Branch>>(
          state: state,
          onRetry: () => unawaited(controller.retry()),
          builder: (context, branches) {
            final groups = groupBranchesByCity(branches);
            if (groups.isEmpty) {
              return EmptyState(
                title: l10n.branchesEmptyTitle,
                body: l10n.branchesEmptyBody,
                action: WhatsAppButton(
                  label: l10n.actionContactWhatsApp,
                  message: l10n.sharedWhatsappMsgAdvice,
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: controller.refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(IprSpace.s4),
                children: [
                  for (final group in groups) ...[
                    _CitySection(group: group),
                    const SizedBox(height: IprSpace.s4),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CitySection extends StatelessWidget {
  const new({required this.group});

  final CityBranchGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(group.city, style: theme.textTheme.titleMedium),
        ),
        const SizedBox(height: IprSpace.s2),
        for (final branch in group.branches) ...[
          _BranchTile(branch: branch),
          const SizedBox(height: IprSpace.s2),
        ],
      ],
    );
  }
}

class _BranchTile extends StatelessWidget {
  const new({required this.branch});

  final Branch branch;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: branch.upcoming
            ? null
            : () => unawaited(context.push(Routes.branchDetail(branch.slug))),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: IprSpace.minTapTarget),
          child: Padding(
            padding: const EdgeInsets.all(IprSpace.s4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(branch.name, style: theme.textTheme.titleSmall),
                      if (branch.address.isNotEmpty) ...[
                        const SizedBox(height: IprSpace.s1),
                        Text(branch.address, style: theme.textTheme.bodyMedium),
                      ],
                      if (branch.upcoming) ...[
                        const SizedBox(height: IprSpace.s2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: IprSpace.s2,
                            vertical: IprSpace.s1,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(IprRadius.sm),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ExcludeSemantics(
                                child: Icon(
                                  Icons.schedule_outlined,
                                  size: 16,
                                  color: theme.colorScheme.onSecondaryContainer,
                                ),
                              ),
                              const SizedBox(width: IprSpace.s1),
                              Flexible(
                                child: Text(
                                  l10n.branchesUpcomingBadge,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color:
                                        theme.colorScheme.onSecondaryContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!branch.upcoming) ...[
                  const SizedBox(width: IprSpace.s2),
                  ExcludeSemantics(
                    child: Icon(
                      Icons.chevron_right,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
