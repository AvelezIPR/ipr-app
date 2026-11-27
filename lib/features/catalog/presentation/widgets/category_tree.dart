import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/category_node.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/category_icons.dart';
import 'package:ipr_mobile/shared/design_system/tokens/color_tokens.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:ipr_mobile/shared/navigation/routes.dart';
import 'package:material_ui/material_ui.dart';

/// Árbol de categorías desplegable, como el menú móvil de la web: cada fila
/// lleva a su listado de productos y, si tiene subcategorías, un botón de
/// chevron aparte las despliega o las contrae en el mismo lugar.
///
/// * Acordeón: solo hay una rama abierta por nivel; abrir otra cierra la
///   anterior (y sus descendientes).
/// * La jerarquía y el orden son los del servidor (AC-010-5).
/// * El estado de apertura vive aquí: se conserva al entrar a un listado y
///   volver a la pestaña.
class CategoryTree extends StatefulWidget {
  const new({required this.roots, super.key});

  final List<CategoryNode> roots;

  @override
  State<CategoryTree> createState() => _CategoryTreeState();
}

class _CategoryTreeState extends State<CategoryTree> {
  /// Ids de la rama abierta, de la raíz hacia abajo.
  List<int> _open = const [];

  bool _isOpen(CategoryNode node, int depth) =>
      _open.length > depth && _open[depth] == node.id;

  void _toggle(CategoryNode node, int depth) {
    setState(() {
      _open = _isOpen(node, depth)
          ? _open.sublist(0, depth)
          : [..._open.take(depth), node.id];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final root in widget.roots)
          _CategoryBranch(
            node: root,
            depth: 0,
            isOpen: _isOpen,
            onToggle: _toggle,
          ),
      ],
    );
  }
}

/// Colores de cada nivel cuando su rama está abierta (los de la web).
class _LevelStyle {
  const new({
    required this.background,
    required this.accent,
    required this.text,
  });

  final Color background;
  final Color accent;
  final Color? text;

  static const _levels = <_LevelStyle>[
    _LevelStyle(
      background: Color(0xFFF3F8FB),
      accent: IprPalette.blue700,
      text: IprPalette.blue700,
    ),
    _LevelStyle(
      background: Color(0xFFF6FAFE),
      accent: Color(0xFF2980B9),
      text: Color(0xFF0D6399),
    ),
    _LevelStyle(
      background: Color(0xFFF9FCFF),
      accent: Color(0xFF48BFE3),
      text: Color(0xFF028090),
    ),
    _LevelStyle(
      background: IprPalette.white,
      accent: Color(0xFFA2D2FF),
      text: null,
    ),
  ];

  static _LevelStyle of(int depth) =>
      _levels[depth < _levels.length ? depth : _levels.length - 1];
}

class _CategoryBranch extends StatelessWidget {
  const new({
    required this.node,
    required this.depth,
    required this.isOpen,
    required this.onToggle,
  });

  final CategoryNode node;
  final int depth;
  final bool Function(CategoryNode node, int depth) isOpen;
  final void Function(CategoryNode node, int depth) onToggle;

  @override
  Widget build(BuildContext context) {
    final open = isOpen(node, depth);
    final expandable = !node.isLeaf;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 200);
    final children = open && expandable
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SeeAllRow(node: node, depth: depth),
              for (final child in node.children)
                _CategoryBranch(
                  node: child,
                  depth: depth + 1,
                  isOpen: isOpen,
                  onToggle: onToggle,
                ),
            ],
          )
        : const SizedBox(width: double.infinity);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CategoryRow(
          node: node,
          depth: depth,
          open: open,
          onToggle: () => onToggle(node, depth),
          duration: duration,
        ),
        // Movimiento reducido (RNF-074): sin animación. `AnimatedSize` con
        // duración cero falla en Flutter, así que no se usa en ese caso.
        if (reduceMotion)
          children
        else
          AnimatedSize(
            duration: duration,
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: children,
          ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const new({
    required this.node,
    required this.depth,
    required this.open,
    required this.onToggle,
    required this.duration,
  });

  final CategoryNode node;
  final int depth;
  final bool open;
  final VoidCallback onToggle;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = _LevelStyle.of(depth);
    final nameStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: open ? FontWeight.w700 : FontWeight.w600,
      color: open ? style.text : null,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: open ? style.background : scheme.surface,
        border: Border(
          left: BorderSide(
            width: 4,
            color: open ? style.accent : Colors.transparent,
          ),
          bottom: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Semantics(
                button: true,
                excludeSemantics: true,
                label: node.isLeaf
                    ? node.name
                    : l10n.catalogCategoryItemSemantics(node.name),
                onTap: () => _openList(context),
                child: InkWell(
                  onTap: () => _openList(context),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: IprSpace.minTapTarget,
                    ),
                    child: Padding(
                      padding: EdgeInsetsDirectional.only(
                        start: IprSpace.s4 + IprSpace.s3 * depth,
                        end: IprSpace.s2,
                        top: IprSpace.s3,
                        bottom: IprSpace.s3,
                      ),
                      child: Row(
                        children: [
                          if (depth == 0) ...[
                            ExcludeSemantics(
                              child: Icon(
                                categoryIconForName(node.slug, node.name),
                                size: 20,
                                color: scheme.primary,
                              ),
                            ),
                            const SizedBox(width: IprSpace.s2),
                          ],
                          Expanded(child: Text(node.name, style: nameStyle)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (!node.isLeaf)
              Semantics(
                button: true,
                expanded: open,
                excludeSemantics: true,
                label: open
                    ? l10n.catalogCategoryCollapseSemantics(node.name)
                    : l10n.catalogCategoryExpandSemantics(node.name),
                onTap: onToggle,
                child: InkWell(
                  key: ValueKey('category-toggle-${node.slug}'),
                  onTap: onToggle,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: BorderDirectional(
                        start: BorderSide(color: scheme.outlineVariant),
                      ),
                    ),
                    child: SizedBox(
                      width: IprSpace.minTapTarget,
                      child: Center(
                        child: AnimatedRotation(
                          turns: open ? 0.25 : 0,
                          duration: duration,
                          child: Icon(
                            Icons.chevron_right,
                            color: open
                                ? (style.text ?? scheme.primary)
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openList(BuildContext context) =>
      unawaited(context.push(Routes.categoryList(node.slug)));
}

class _SeeAllRow extends StatelessWidget {
  const new({required this.node, required this.depth});

  final CategoryNode node;
  final int depth;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = _LevelStyle.of(depth);
    final label = l10n.catalogSeeAllIn(node.name);
    void openAll() => unawaited(context.push(Routes.categoryList(node.slug)));

    return DecoratedBox(
      decoration: BoxDecoration(
        color: style.background,
        border: Border(
          left: BorderSide(width: 4, color: style.accent),
          bottom: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      child: Semantics(
        button: true,
        excludeSemantics: true,
        label: label,
        onTap: openAll,
        child: InkWell(
          key: ValueKey('category-see-all-${node.slug}'),
          onTap: openAll,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: IprSpace.minTapTarget),
            child: Padding(
              padding: EdgeInsetsDirectional.only(
                start: IprSpace.s4 + IprSpace.s3 * (depth + 1),
                end: IprSpace.s4,
                top: IprSpace.s3,
                bottom: IprSpace.s3,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: IprSpace.s2),
                  ExcludeSemantics(
                    child: Icon(
                      Icons.arrow_forward,
                      size: 18,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
