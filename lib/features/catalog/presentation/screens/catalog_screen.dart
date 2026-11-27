import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ipr_mobile/features/catalog/presentation/controllers/taxonomy_controllers.dart';
import 'package:ipr_mobile/features/catalog/presentation/widgets/category_tiles.dart';
import 'package:ipr_mobile/features/catalog/presentation/widgets/category_tree.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/navigation/routes.dart';
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
            CatalogLinkTile(
              icon: Icons.local_offer_outlined,
              label: l10n.catalogSaleLink,
              onTap: () => context.push(Routes.sale),
            ),
          ],
        ),
      ),
    );
  }
}
