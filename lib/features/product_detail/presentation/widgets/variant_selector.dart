import 'package:ipr_mobile/features/product_detail/domain/rules/variant_selection.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Selector de opciones de un producto variable (W1-01), como el de la web:
/// un grupo de botones por cada eje (medida, voltaje, volumen…).
///
/// * La opción elegida se marca con relleno **y** con un ícono de visto, no
///   solo con color (RNF-076); tocarla de nuevo la quita.
/// * Una opción que no existe combinada con lo ya elegido sale deshabilitada
///   y el lector de pantalla lo dice.
/// * Cada botón mide al menos 48 dp.
class VariantSelector extends StatelessWidget {
  const new({required this.selection, required this.onToggle, super.key});

  final VariantSelection selection;
  final void Function(String axisSlug, String value) onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final axis in selection.axes) ...[
          Semantics(
            header: true,
            child: Text(axis.name, style: theme.textTheme.titleSmall),
          ),
          const SizedBox(height: IprSpace.s2),
          Wrap(
            spacing: IprSpace.s2,
            runSpacing: IprSpace.s2,
            children: [
              for (final option in axis.options)
                _OptionButton(
                  label: option.label,
                  selected: selection.chosen[axis.slug] == option.value,
                  enabled: selection.isOptionAvailable(axis.slug, option.value),
                  onTap: () => onToggle(axis.slug, option.value),
                ),
            ],
          ),
          const SizedBox(height: IprSpace.s3),
        ],
      ],
    );
  }
}

class _OptionButton extends StatelessWidget {
  const new({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final background = selected
        ? scheme.primary
        : enabled
        ? scheme.surface
        : scheme.surfaceContainer;
    final foreground = selected
        ? scheme.onPrimary
        : enabled
        ? scheme.onSurface
        : scheme.onSurfaceVariant;
    final border = selected
        ? scheme.primary
        : enabled
        ? scheme.outline
        : scheme.outlineVariant;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      excludeSemantics: true,
      label: label,
      hint: !enabled
          ? l10n.productDetailVariantUnavailable
          : selected
          ? l10n.productDetailVariantRemoveHint
          : null,
      onTap: enabled || selected ? onTap : null,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(IprRadius.lg),
          side: BorderSide(color: border, width: selected ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          // Una opción elegida siempre se puede quitar, aunque ya no figure
          // como disponible.
          onTap: enabled || selected ? onTap : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: IprSpace.minTapTarget,
              minHeight: IprSpace.minTapTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: IprSpace.s4,
                vertical: IprSpace.s2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selected) ...[
                    Icon(Icons.check, size: 18, color: foreground),
                    const SizedBox(width: IprSpace.s1),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: foreground,
                        decoration: enabled || selected
                            ? null
                            : TextDecoration.lineThrough,
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
