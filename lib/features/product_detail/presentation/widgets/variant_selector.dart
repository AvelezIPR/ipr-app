import 'package:ipr_mobile/features/product_detail/domain/rules/variant_selection.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Selector de opciones de un producto variable (W1-01), como el de la web:
/// un grupo de botones por cada eje (medida, voltaje, volumen…).
///
/// * La opción elegida se marca con relleno **y** con un ícono de visto, no
///   solo con color (RNF-076); tocarla de nuevo la quita.
/// * Una opción compatible en otra combinación sigue habilitada, muestra un
///   indicador de cambio y anuncia al lector de pantalla que requiere cambiar
///   otra opción. Solo se deshabilita una opción inexistente en todo el producto.
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
                _buildOption(axis.slug, option.value, option.label),
            ],
          ),
          const SizedBox(height: IprSpace.s3),
        ],
      ],
    );
  }

  Widget _buildOption(String axisSlug, String value, String label) {
    final selected = selection.chosen[axisSlug] == value;
    final enabled = selection.hasAnyVariantFor(axisSlug, value);
    final requiresAxisChange =
        enabled && !selected && !selection.isOptionAvailable(axisSlug, value);
    return _OptionButton(
      label: label,
      selected: selected,
      enabled: enabled,
      requiresAxisChange: requiresAxisChange,
      onTap: () => onToggle(axisSlug, value),
    );
  }
}

class _OptionButton extends StatelessWidget {
  const new({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.requiresAxisChange,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final bool requiresAxisChange;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final background = selected
        ? scheme.primary
        : !enabled
        ? scheme.surfaceContainer
        : requiresAxisChange
        ? scheme.surfaceContainerLow
        : scheme.surface;
    final foreground = selected
        ? scheme.onPrimary
        : !enabled || requiresAxisChange
        ? scheme.onSurfaceVariant
        : scheme.onSurface;
    final border = selected
        ? scheme.primary
        : !enabled || requiresAxisChange
        ? scheme.outlineVariant
        : scheme.outline;
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
          : requiresAxisChange
          ? l10n.productDetailVariantSwitchHint
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
                  ] else if (requiresAxisChange) ...[
                    Icon(Icons.swap_horiz, size: 16, color: foreground),
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
