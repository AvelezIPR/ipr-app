import 'package:ipr_mobile/features/home/domain/entities/home_city.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Ícono de IPR de la cabecera. Es un activo propio de la app
/// (`assets/brand/`): no depende de la red. Si el archivo no se pudiera
/// leer, el título de la pantalla sigue identificando la marca.
class IprLogoMark extends StatelessWidget {
  const new({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Image.asset(
      'assets/brand/icono-ipr.png',
      width: size,
      height: size,
      semanticLabel: l10n.homeLogoSemantics,
      errorBuilder: (context, error, stackTrace) =>
          SizedBox.square(dimension: size),
    );
  }
}

/// Bloque de bienvenida del inicio: mensaje de marca y acceso al catálogo.
/// El texto es copia fija de la app; no lleva cifras ni promociones, que
/// pertenecen al servidor (D-07).
class HomeHeroCard extends StatelessWidget {
  const new({required this.onCatalog, super.key});

  final VoidCallback onCatalog;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.primary,
      borderRadius: BorderRadius.circular(IprRadius.xl),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(IprSpace.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.homeHeroTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: scheme.onPrimary,
                ),
              ),
            ),
            const SizedBox(height: IprSpace.s2),
            Text(
              l10n.homeHeroBody,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onPrimary,
              ),
            ),
            const SizedBox(height: IprSpace.s3),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.surface,
                foregroundColor: scheme.primary,
              ),
              onPressed: onCatalog,
              child: Text(l10n.homeHeroCta),
            ),
          ],
        ),
      ),
    );
  }
}

/// Resumen de sedes por ciudad: totales calculados con lo que entrega
/// `/stores` (nada fijo en la app) y un acceso por ciudad al directorio.
class HomeBranchesSummary extends StatelessWidget {
  const new({required this.cities, required this.onTap, super.key});

  final List<HomeCity> cities;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final open = cities.where((c) => !c.upcoming).toList(growable: false);
    final branches = open.fold<int>(0, (sum, c) => sum + c.branchCount);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (open.isNotEmpty)
          Text(
            l10n.homeBranchesSummary(branches, open.length),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        const SizedBox(height: IprSpace.s2),
        Wrap(
          spacing: IprSpace.s2,
          runSpacing: IprSpace.s2,
          children: [
            for (final city in cities)
              OutlinedButton(
                onPressed: onTap,
                child: Text(
                  city.upcoming
                      ? l10n.homeBranchesCityUpcoming(city.name)
                      : l10n.homeBranchesCity(city.name, city.branchCount),
                ),
              ),
          ],
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: onTap,
            child: Text(l10n.homeBranchesSeeAll),
          ),
        ),
      ],
    );
  }
}

/// Tarjeta de la calculadora de BTU. Toda la tarjeta es un solo botón.
class HomeBtuCard extends StatelessWidget {
  const new({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: '${l10n.homeShortcutBtu}. ${l10n.homeBtuTagline}',
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
          child: Padding(
            padding: const EdgeInsets.all(IprSpace.s4),
            child: Row(
              children: [
                Icon(
                  Icons.calculate_outlined,
                  size: 32,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: IprSpace.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.homeShortcutBtu,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: IprSpace.s1),
                      Text(
                        l10n.homeBtuTagline,
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: IprSpace.s2),
                      Text(
                        l10n.homeBtuCta,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
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
