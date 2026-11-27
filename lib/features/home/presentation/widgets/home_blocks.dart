import 'package:ipr_mobile/features/home/domain/entities/home_brand.dart';
import 'package:ipr_mobile/features/home/domain/entities/home_category.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/category_icons.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:ipr_mobile/shared/widgets/ipr_card.dart';
import 'package:material_ui/material_ui.dart';

/// Acceso al buscador (RF-001): un solo objetivo táctil de 56 dp con etiqueta
/// accesible. No contiene la búsqueda: abre la pantalla de búsqueda.
///
/// Píldora con borde azul y un botón "Buscar" a la derecha, como la de la web.
/// El botón es decorativo: toda la píldora es el objetivo táctil.
class SearchEntry extends StatelessWidget {
  const new({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // A texto grande el botón queda solo con el ícono para no ahogar el hint.
    final compact = MediaQuery.textScalerOf(context).scale(14) / 14 >= 1.5;
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: l10n.homeSearchSemantics,
      onTap: onTap,
      child: Material(
        color: scheme.surface,
        elevation: 2,
        shadowColor: const Color(0x33053554),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(IprRadius.xl),
          side: BorderSide(color: scheme.primary, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                IprSpace.s4,
                IprSpace.s2,
                IprSpace.s2,
                IprSpace.s2,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.homeSearchHint,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: IprSpace.s2),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(IprRadius.lg),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: IprSpace.s3,
                        vertical: IprSpace.s2,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search, size: 20, color: scheme.onPrimary),
                          if (!compact) ...[
                            const SizedBox(width: IprSpace.s1),
                            Text(
                              l10n.homeSearchButton,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: scheme.onPrimary,
                              ),
                            ),
                          ],
                        ],
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

/// Ícono decorativo de una categoría de Inicio (ver [categoryIconForName]).
IconData categoryIconFor(HomeCategory category) =>
    categoryIconForName(category.slug, category.name);

/// Círculo tintado con un ícono (categorías y accesos).
class IconBadge extends StatelessWidget {
  const new({required this.icon, super.key, this.size = 44});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: SizedBox.square(
          dimension: size,
          child: Icon(icon, color: scheme.primary, size: size * 0.5),
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
      child: IprCard(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 96),
          // Ícono arriba y nombre debajo: el nombre usa todo el ancho de la
          // tarjeta y no se parte a mitad de palabra.
          child: Padding(
            padding: const EdgeInsets.all(IprSpace.s3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconBadge(icon: categoryIconFor(category)),
                const SizedBox(height: IprSpace.s2),
                Text(category.name, style: theme.textTheme.titleSmall),
              ],
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
              style: OutlinedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.surface,
                shape: const StadiumBorder(),
              ),
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
      child: IprCard(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: IprSpace.s4,
              vertical: IprSpace.s2,
            ),
            child: Row(
              children: [
                IconBadge(icon: icon, size: 40),
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
    );
  }
}
