import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/category_node.dart';
import 'package:ipr_mobile/features/catalog/presentation/screens/category_level_screen.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:ipr_mobile/shared/navigation/routes.dart';
import 'package:material_ui/material_ui.dart';

/// Fila de una categoría: con hijos baja un nivel (misma pantalla, título =
/// nombre tocado, AC-010-1); una hoja abre su listado de productos.
class CategoryTile extends StatelessWidget {
  const new({required this.node, super.key});

  final CategoryNode node;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: node.isLeaf
          ? node.name
          : l10n.catalogCategoryItemSemantics(node.name),
      onTap: () => _open(context),
      child: ListTile(
        minTileHeight: IprSpace.minTapTarget,
        title: Text(node.name),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _open(context),
      ),
    );
  }

  void _open(BuildContext context) {
    if (node.isLeaf) {
      unawaited(context.push(Routes.categoryList(node.slug)));
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CategoryLevelScreen(node: node),
        ),
      );
    }
  }
}

/// Acceso destacado ("Marcas", "Liquidaciones", "Ver todo en…").
class CatalogLinkTile extends StatelessWidget {
  const new({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    minTileHeight: IprSpace.minTapTarget,
    leading: ExcludeSemantics(child: Icon(icon)),
    title: Text(label),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}
