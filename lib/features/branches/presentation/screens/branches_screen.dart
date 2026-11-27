import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ipr_mobile/features/branches/branches_providers.dart';
import 'package:ipr_mobile/features/branches/domain/entities/branch.dart';
import 'package:ipr_mobile/features/branches/domain/entities/colombia_map.dart';
import 'package:ipr_mobile/features/branches/presentation/controllers/branches_controller.dart';
import 'package:ipr_mobile/features/branches/presentation/widgets/branches_map.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:ipr_mobile/shared/navigation/routes.dart';
import 'package:ipr_mobile/shared/widgets/state_widgets.dart';
import 'package:ipr_mobile/shared/widgets/whatsapp_button.dart';
import 'package:material_ui/material_ui.dart';

/// Listado de sedes agrupado por ciudad (`/branches`, RF-072, AC-072-1..6), con
/// un mapa de Colombia y botones de ciudad para filtrar (W3-03).
class BranchesScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<BranchesScreen> createState() => _BranchesScreenState();
}

class _BranchesScreenState extends ConsumerState<BranchesScreen> {
  /// Ciudad elegida en el mapa o en los botones; `null` = todas.
  String? _city;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(branchesProvider);
    final controller = ref.read(branchesProvider.notifier);
    final map = ref.watch(colombiaMapProvider).value ?? ColombiaMap.empty;

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
            // Si la ciudad elegida ya no existe (datos nuevos), se vuelve a todas.
            final city = groups.any((g) => g.city == _city) ? _city : null;
            final visible = city == null
                ? groups
                : [
                    for (final g in groups)
                      if (g.city == city) g,
                  ];
            final pins = [
              for (final group in groups)
                MapPin(
                  city: group.city,
                  branchCount: group.branches.where((b) => !b.upcoming).length,
                  upcoming: group.branches.every((b) => b.upcoming),
                ),
            ];
            return RefreshIndicator(
              onRefresh: controller.refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(IprSpace.s4),
                children: [
                  BranchesMap(
                    map: map,
                    pins: pins,
                    selected: city,
                    onSelect: (value) => setState(() => _city = value),
                  ),
                  if (!map.isEmpty) const SizedBox(height: IprSpace.s3),
                  _CityChips(
                    pins: pins,
                    selected: city,
                    onSelect: (value) => setState(() => _city = value),
                  ),
                  const SizedBox(height: IprSpace.s4),
                  for (final group in visible) ...[
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

/// Botones de ciudad: el control accesible del filtro (el mapa es una ayuda
/// visual). Cada uno mide al menos 48 dp y dice cuántas sedes tiene.
class _CityChips extends StatelessWidget {
  const new({
    required this.pins,
    required this.selected,
    required this.onSelect,
  });

  final List<MapPin> pins;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: IprSpace.s2,
      runSpacing: IprSpace.s2,
      children: [
        ChoiceChip(
          label: Text(l10n.branchesCityAll),
          selected: selected == null,
          onSelected: (_) => onSelect(null),
        ),
        for (final pin in pins)
          ChoiceChip(
            label: Text(
              pin.upcoming
                  ? l10n.branchesCityChipUpcoming(pin.city)
                  : l10n.branchesCityChip(pin.city, pin.branchCount),
            ),
            selected: selected == pin.city,
            onSelected: (isSelected) => onSelect(isSelected ? pin.city : null),
          ),
      ],
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
