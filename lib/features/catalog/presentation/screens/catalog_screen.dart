import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ipr_mobile/features/catalog/presentation/controllers/taxonomy_controllers.dart';
import 'package:ipr_mobile/features/catalog/presentation/widgets/category_tiles.dart';
import 'package:ipr_mobile/features/catalog/presentation/widgets/category_tree.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:ipr_mobile/shared/navigation/routes.dart';
import 'package:ipr_mobile/shared/widgets/ipr_card.dart';
import 'package:ipr_mobile/shared/widgets/state_widgets.dart';
import 'package:material_ui/material_ui.dart';

/// Pestaña "Catálogo" (PT-02, RF-010): árbol de categorías desplegable en la
/// misma pantalla (como el menú de la web). Pública: sin sesión (RF-037). Datos de la caché de taxonomía
/// (1 h / 7 d) con aviso si están desactualizados.
class CatalogScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(categoriesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tabCatalog),
        actions: [
          IconButton(
            tooltip: l10n.catalogSearchTooltip,
            icon: const Icon(Icons.search),
            onPressed: () => context.push(Routes.search),
          ),
        ],
      ),
      body: AsyncView(
        state: state,
        onRetry: () => ref.read(categoriesProvider.notifier).retry(),
        empty: EmptyState(body: l10n.catalogCategoriesEmpty),
        builder: (context, roots) => ListView(
          children: [
            CategoryTree(roots: roots),
            const Divider(height: 1),
            CatalogLinkTile(
              icon: Icons.sell_outlined,
              label: l10n.catalogBrandsLink,
              onTap: () => context.push(Routes.brands),
            ),
            _SaleHighlightCard(onTap: () => context.push(Routes.sale)),
          ],
        ),
      ),
    );
  }
}

class _SaleHighlightCard extends StatelessWidget {
  const new({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        IprSpace.s4,
        IprSpace.s2,
        IprSpace.s4,
        IprSpace.s4,
      ),
      child: IprCard(
        color: scheme.errorContainer,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: IprSpace.minTapTarget),
          child: Padding(
            padding: const EdgeInsets.all(IprSpace.s4),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.error,
                      borderRadius: BorderRadius.circular(IprRadius.md),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(IprSpace.s2),
                      child: Icon(
                        Icons.local_offer_outlined,
                        color: scheme.onError,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: IprSpace.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: IprSpace.s2,
                        runSpacing: IprSpace.s1,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            l10n.catalogSaleLink,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: scheme.onErrorContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: scheme.error,
                              borderRadius: BorderRadius.circular(IprRadius.sm),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: IprSpace.s2,
                                vertical: 2,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ExcludeSemantics(
                                    child: Icon(
                                      Icons.local_offer,
                                      size: 12,
                                      color: scheme.onError,
                                    ),
                                  ),
                                  const SizedBox(width: IprSpace.s1),
                                  Text(
                                    l10n.catalogSaleHighlightBadge,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: scheme.onError,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: IprSpace.s1),
                      Text(
                        l10n.catalogSaleHighlightSubtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onErrorContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: IprSpace.s2),
                ExcludeSemantics(
                  child: Icon(
                    Icons.chevron_right,
                    color: scheme.onErrorContainer,
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
