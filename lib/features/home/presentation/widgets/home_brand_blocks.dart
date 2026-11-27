import 'package:ipr_mobile/core/config/home_content.dart';
import 'package:ipr_mobile/features/home/domain/entities/home_city.dart';
import 'package:ipr_mobile/features/home/presentation/widgets/home_blocks.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/effect_tokens.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:ipr_mobile/shared/widgets/gradient_panel.dart';
import 'package:ipr_mobile/shared/widgets/ipr_card.dart';
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
    return IprGradientPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const IprGlassIcon(icon: Icons.ac_unit),
          const SizedBox(height: IprSpace.s3),
          Semantics(
            header: true,
            child: Text(
              l10n.homeHeroTitle,
              style: theme.textTheme.headlineMedium?.copyWith(
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
          const SizedBox(height: IprSpace.s4),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.surface,
              foregroundColor: scheme.primary,
              shape: const StadiumBorder(),
            ),
            onPressed: onCatalog,
            iconAlignment: IconAlignment.end,
            icon: const ExcludeSemantics(child: Icon(Icons.arrow_forward)),
            label: Text(l10n.homeHeroCta),
          ),
        ],
      ),
    );
  }
}

/// Resumen de sedes por ciudad: totales calculados con lo que entrega
/// `/stores` (nada fijo en la app), en una banda de cifras como la de la web,
/// y un acceso por ciudad al directorio. [brandCount] (las marcas que entrega
/// el servidor) suma una tercera cifra cuando se conoce.
class HomeBranchesSummary extends StatelessWidget {
  const new({
    required this.cities,
    required this.onTap,
    super.key,
    this.brandCount,
    this.showStats = true,
  });

  final List<HomeCity> cities;
  final VoidCallback onTap;
  final int? brandCount;

  /// `false` cuando la portada ya muestra las cifras institucionales que
  /// entrega el servidor (W2-02): no se repiten las calculadas aquí.
  final bool showStats;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final open = cities.where((c) => !c.upcoming).toList(growable: false);
    final branches = open.fold<int>(0, (sum, c) => sum + c.branchCount);
    final stats = <_Stat>[
      if (showStats) ...[
        if (open.isNotEmpty) ...[
          _Stat(
            icon: Icons.storefront_outlined,
            value: '$branches',
            label: l10n.homeStatBranches(branches),
          ),
          _Stat(
            icon: Icons.location_on_outlined,
            value: '${open.length}',
            label: l10n.homeStatCities(open.length),
          ),
        ],
        if (brandCount != null && brandCount! > 0)
          _Stat(
            icon: Icons.verified_outlined,
            value: '$brandCount',
            label: l10n.homeStatBrands(brandCount!),
          ),
      ],
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (stats.isNotEmpty) ...[
          _StatsBand(stats: stats),
          const SizedBox(height: IprSpace.s3),
        ],
        Wrap(
          spacing: IprSpace.s2,
          runSpacing: IprSpace.s2,
          children: [
            for (final city in cities)
              if (city.upcoming)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: scheme.secondaryContainer,
                    foregroundColor: scheme.onSecondaryContainer,
                    side: BorderSide(color: scheme.outline),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: onTap,
                  icon: const ExcludeSemantics(
                    child: Icon(Icons.schedule_outlined, size: 18),
                  ),
                  label: Text(l10n.homeBranchesCityUpcoming(city.name)),
                )
              else
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: scheme.surface,
                    shape: const StadiumBorder(),
                  ),
                  onPressed: onTap,
                  child: Text(
                    l10n.homeBranchesCity(city.name, city.branchCount),
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

/// Una cifra de la banda: cifra grande, etiqueta y su ícono. [value] ya viene
/// redactado ("14", "+30 años", "Líder del sector HVAC-R*").
class _Stat {
  const new({
    required this.icon,
    required this.value,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String value;
  final String label;
  final VoidCallback? onTap;

  /// Cifras largas (frases) usan un tipo más pequeño para no romper la banda.
  bool get isPhrase => value.length > 10;
}

/// Cifras institucionales que entrega el servidor (`/config` → `home.stats`,
/// W2-02, D-07): las mismas de la portada de la web ("+30 años", "31 sedes",
/// "+10.000 referencias"…), redactadas por Marketing y **no fijas en la app**.
class HomeInstitutionalStats extends StatelessWidget {
  const new({required this.stats, super.key, this.onOpenTarget});

  final List<HomeStat> stats;
  final ValueChanged<HomeTarget>? onOpenTarget;

  @override
  Widget build(BuildContext context) {
    final open = onOpenTarget;
    return _StatsBand(
      columns: 2,
      stats: [
        for (final stat in stats)
          _Stat(
            icon: _iconFor(stat),
            value: stat.spoken,
            label: stat.label,
            onTap: open != null && stat.target != null
                ? () => open(stat.target!)
                : null,
          ),
      ],
    );
  }

  /// Ícono decorativo deducido del identificador de la cifra.
  static IconData _iconFor(HomeStat stat) {
    final id = stat.id.toLowerCase();
    if (id.contains('sede') || id.contains('branch')) {
      return Icons.place_outlined;
    }
    if (id.contains('ref') || id.contains('product')) {
      return Icons.inventory_2_outlined;
    }
    if (id.contains('lider') || id.contains('leader')) {
      return Icons.workspace_premium_outlined;
    }
    if (id.contains('year') || id.contains('ano')) {
      return Icons.verified_user_outlined;
    }
    return Icons.verified_outlined;
  }
}

/// Banda azul de cifras (como la de la web). Cada cifra se lee junta ("14
/// sedes"). Se reparte en [columns] columnas; a texto grande se apila en una
/// sola para que nada se corte.
class _StatsBand extends StatelessWidget {
  const new({required this.stats, this.columns = 0});

  final List<_Stat> stats;

  /// 0 = todas en una fila (2–3 cifras cortas).
  final int columns;

  @override
  Widget build(BuildContext context) {
    final stacked = MediaQuery.textScalerOf(context).scale(14) / 14 >= 1.5;
    final perRow = columns == 0 ? stats.length : columns;
    final items = [
      for (final stat in stats) _StatItem(stat: stat, horizontal: stacked),
    ];
    return IprGradientPanel(
      gradient: IprGradients.band,
      padding: const EdgeInsets.symmetric(
        horizontal: IprSpace.s4,
        vertical: IprSpace.s4,
      ),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, item) in items.indexed) ...[
                  if (i > 0) const SizedBox(height: IprSpace.s4),
                  item,
                ],
              ],
            )
          : Column(
              children: [
                for (var start = 0; start < items.length; start += perRow) ...[
                  if (start > 0) const SizedBox(height: IprSpace.s4),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var c = 0; c < perRow; c++) ...[
                          if (c > 0) const _StatDivider(),
                          Expanded(
                            child: start + c < items.length
                                ? items[start + c]
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: IprSpace.s2),
    child: VerticalDivider(width: 1, thickness: 1, color: Color(0x33FFFFFF)),
  );
}

class _StatItem extends StatelessWidget {
  const new({required this.stat, required this.horizontal});

  final _Stat stat;

  /// Ícono a la izquierda de la cifra (diseño apilado) en lugar de arriba.
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onPrimary = theme.colorScheme.onPrimary;
    final onTap = stat.onTap;
    final interactive = onTap != null;
    final number = Text(
      stat.value,
      style:
          (stat.isPhrase
                  ? theme.textTheme.titleMedium
                  : theme.textTheme.headlineMedium)
              ?.copyWith(color: onPrimary),
    );
    final label = Text(
      stat.label,
      style: theme.textTheme.bodySmall?.copyWith(color: onPrimary),
    );
    final body = horizontal
        ? Row(
            children: [
              IprGlassIcon(icon: stat.icon, size: 40),
              const SizedBox(width: IprSpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [number, label],
                ),
              ),
              if (interactive) ...[
                const SizedBox(width: IprSpace.s2),
                Icon(Icons.arrow_forward, size: 18, color: onPrimary),
              ],
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IprGlassIcon(icon: stat.icon, size: 36),
                  if (interactive) ...[
                    const Spacer(),
                    Icon(Icons.arrow_forward, size: 18, color: onPrimary),
                  ],
                ],
              ),
              const SizedBox(height: IprSpace.s2),
              number,
              label,
            ],
          );
    final content = ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: IprSpace.minTapTarget,
        minWidth: IprSpace.minTapTarget,
      ),
      child: Padding(padding: const EdgeInsets.all(IprSpace.s1), child: body),
    );
    if (onTap == null) {
      return Semantics(
        container: true,
        label: '${stat.value} ${stat.label}',
        excludeSemantics: true,
        child: content,
      );
    }
    return Semantics(
      container: true,
      button: true,
      label: '${stat.value} ${stat.label}',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        type: MaterialType.transparency,
        borderRadius: BorderRadius.circular(IprRadius.lg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: const Color(0x26FFFFFF),
          highlightColor: const Color(0x14FFFFFF),
          child: content,
        ),
      ),
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
      child: IprCard(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(IprSpace.s4),
          child: Row(
            children: [
              const IconBadge(icon: Icons.calculate_outlined, size: 56),
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
                    Text(l10n.homeBtuTagline, style: theme.textTheme.bodySmall),
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
    );
  }
}
