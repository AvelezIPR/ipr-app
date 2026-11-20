import 'package:ipr_mobile/features/cart/domain/entities/cart.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Selector de cantidad de una línea del carrito: `−` / valor / `+`, de 1 a 99
/// (RF-049, AC-049-2). Cada botón mide al menos 48 dp y lleva una etiqueta con
/// el nombre del producto; bajar de 1 está deshabilitado (quitar es otra
/// acción explícita). El valor es una región viva: el lector de pantalla
/// anuncia cada cambio.
class CartQuantityStepper extends StatelessWidget {
  const new({
    required this.quantity,
    required this.productName,
    required this.onChanged,
    super.key,
  });

  final int quantity;
  final String productName;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    const constraints = BoxConstraints(
      minWidth: IprSpace.minTapTarget,
      minHeight: IprSpace.minTapTarget,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton.outlined(
              tooltip: l10n.cartQuantityDecrease(productName),
              constraints: constraints,
              onPressed: quantity > CartLimits.minQuantity
                  ? () => onChanged(quantity - 1)
                  : null,
              icon: const Icon(Icons.remove),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: IprSpace.minTapTarget,
              ),
              child: Semantics(
                container: true,
                liveRegion: true,
                label: l10n.cartQuantitySemantics(productName, quantity),
                excludeSemantics: true,
                child: Text(
                  '$quantity',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ),
            IconButton.outlined(
              tooltip: l10n.cartQuantityIncrease(productName),
              constraints: constraints,
              onPressed: quantity < CartLimits.maxQuantity
                  ? () => onChanged(quantity + 1)
                  : null,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        if (quantity >= CartLimits.maxQuantity)
          Padding(
            padding: const EdgeInsets.only(top: IprSpace.s1),
            child: Text(
              l10n.cartQuantityMaxNote(CartLimits.maxQuantity),
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}
