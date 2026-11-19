import 'package:go_router/go_router.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/category_node.dart';
import 'package:ipr_mobile/features/catalog/presentation/widgets/category_tiles.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/navigation/routes.dart';
import 'package:material_ui/material_ui.dart';

/// Un nivel intermedio del árbol (la misma pantalla "Catálogo", un nivel más
/// abajo): título = nombre de la categoría tocada; atrás sube un nivel y
/// conserva el desplazamiento (AC-010-1, AC-010-2). Los hijos se muestran en
/// el orden del servidor.
class CategoryLevelScreen extends StatelessWidget {
  const new({required this.node, super.key});

  final CategoryNode node;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(node.name),
        actions: [
          IconButton(
            tooltip: l10n.catalogSearchTooltip,
            icon: const Icon(Icons.search),
            onPressed: () => context.push(Routes.search),
          ),
        ],
      ),
      body: ListView(
        children: [
          CatalogLinkTile(
            icon: Icons.grid_view,
            label: l10n.catalogSeeAllIn(node.name),
            onTap: () => context.push(Routes.categoryList(node.slug)),
          ),
          const Divider(height: 1),
          for (final child in node.children) CategoryTile(node: child),
        ],
      ),
    );
  }
}
