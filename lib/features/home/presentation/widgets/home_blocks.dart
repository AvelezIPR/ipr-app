import 'package:ipr_mobile/features/home/domain/entities/home_brand.dart';
import 'package:ipr_mobile/features/home/domain/entities/home_category.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Acceso al buscador (RF-001): un solo objetivo táctil de 56 dp con etiqueta
/// accesible. No contiene la búsqueda: abre la pantalla de búsqueda.
class SearchEntry extends StatelessWidget {
  const new({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: l10n.homeSearchSemantics,
      onTap: onTap,
      child: Material(
        color: theme.colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(IprRadius.xl),
          side: BorderSide(color: theme.colorScheme.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: IprSpace.s4,
                vertical: IprSpace.s2,
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: IprSpace.s3),
                  Expanded(
                    child: Text(
                      l10n.homeSearchHint,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
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

/// Acceso a una categoría raíz (RF-002).
class CategoryTile extends StatelessWidget {
  const new({required this.category, required this.onTap, super.key});

  final HomeCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: l10n.homeCategorySemantics(category.name),
      onTap: onTap,
      child: Material(
        color: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(IprRadius.xl),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.all(IprSpace.s3),
              child: Row(
                children: [
                  Icon(
                    Icons.category_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: IprSpace.s2),
                  Expanded(
                    child: Text(
                      category.name,
                      style: theme.textTheme.titleSmall,
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

/// Marcas con página propia como botones (RF-004). Cantidad acotada: el
/// directorio completo está en el acceso "Ver todas las marcas".
class BrandChips extends StatelessWidget {
  const new({
    required this.brands,
    required this.onTap,
    super.key,
    this.maxShown = 12,
  });

  final List<HomeBrand> brands;
  final void Function(HomeBrand brand) onTap;

  /// Presentación provisional: cuántas marcas caben en el inicio no está
  /// definido en los requisitos.
  final int maxShown;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: IprSpace.s2,
      runSpacing: IprSpace.s2,
      children: [
        for (final brand in brands.take(maxShown))
          Semantics(
            button: true,
            excludeSemantics: true,
            label: l10n.homeBrandSemantics(brand.name),
            onTap: () => onTap(brand),
            child: OutlinedButton(
              onPressed: () => onTap(brand),
              child: Text(brand.name),
            ),
          ),
      ],
    );
  }
}

/// Fila de acceso (Marcas, Liquidaciones, Sedes, Llamar): ≥ 56 dp, texto +
/// ícono, el texto crece sin cortarse.
class ShortcutTile extends StatelessWidget {
  const new({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: subtitle == null ? label : '$label. $subtitle',
      onTap: onTap,
      child: Material(
        color: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(IprRadius.xl),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: IprSpace.s4,
                vertical: IprSpace.s2,
              ),
              child: Row(
                children: [
                  Icon(icon, color: theme.colorScheme.primary),
                  const SizedBox(width: IprSpace.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: theme.textTheme.titleSmall),
                        if (subtitle != null)
                          Text(subtitle!, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurfaceVariant,
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
