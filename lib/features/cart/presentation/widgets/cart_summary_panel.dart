import 'package:ipr_mobile/features/cart/domain/entities/cart_overview.dart';
import 'package:ipr_mobile/features/cart/domain/rules/checkout_gate.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:ipr_mobile/shared/formatting/cop_format.dart';
import 'package:material_ui/material_ui.dart';

/// Resumen del carrito y botón "Pagar" (RF-051, RF-050).
///
/// * Solo muestra el **subtotal informativo** (IVA incluido) y avisa de que
///   impuestos, envío y total final se confirman en el pago. Nunca una cifra
///   de "Total a pagar" ni un envío calculado (AC-051-2).
/// * "Pagar" no existe con el carrito vacío; está **deshabilitado**, con el
///   motivo a la vista, si hay líneas bloqueantes, cambios sin aceptar, el
///   servidor no lo permite o el interruptor `checkoutEnabled` está apagado.
///   Con datos sin verificar queda activo: al tocarlo se revalida y solo se
///   avanza si todo está bien (nunca se paga con datos sin verificar).
/// * El contenido es desplazable y con altura acotada: a texto al 200 % no
///   desborda ni tapa la lista.
class CartSummaryPanel extends StatelessWidget {
  const new({
    required this.subtotal,
    required this.readiness,
    required this.busy,
    required this.onPay,
    super.key,
  });

  final CartSubtotal subtotal;
  final CartReadiness readiness;

  /// Hay una verificación en curso (al abrir o al tocar "Pagar").
  final bool busy;
  final VoidCallback onPay;

  bool get _payEnabled =>
      !busy &&
      (readiness == CartReadiness.ready ||
          readiness == CartReadiness.unverified);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.5;
    final hint = _hint(l10n);

    return Material(
      elevation: 8,
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        bottom: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(IprSpace.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _SubtotalRow(subtotal: subtotal),
                if (!subtotal.verified) ...[
                  const SizedBox(height: IprSpace.s1),
                  Text(
                    l10n.cartSubtotalUnverified,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                if (subtotal.excludedLines > 0) ...[
                  const SizedBox(height: IprSpace.s1),
                  Text(
                    l10n.cartSubtotalExcluded(subtotal.excludedLines),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: IprSpace.s3),
                FilledButton(
                  onPressed: _payEnabled ? onPay : null,
                  child: Text(busy ? l10n.cartPayChecking : l10n.cartPayAction),
                ),
                if (hint != null) ...[
                  const SizedBox(height: IprSpace.s2),
                  Semantics(
                    liveRegion: true,
                    child: Text(hint, style: theme.textTheme.bodySmall),
                  ),
                ],
                // El aviso va tras el botón: en pantallas pequeñas con texto al 200 %
                // "Pagar" sigue a la vista y el aviso se desplaza dentro del panel.
                const SizedBox(height: IprSpace.s2),
                Text(l10n.cartSummaryNotice, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _hint(AppLocalizations l10n) => switch (readiness) {
    CartReadiness.ready || CartReadiness.empty => null,
    CartReadiness.unverified => l10n.cartPayHintUnverified,
    CartReadiness.blockedLines => l10n.cartPayHintBlocked,
    CartReadiness.pendingChanges => l10n.cartPayHintChanges,
    CartReadiness.serverDenied => l10n.cartPayHintServerDenied,
    CartReadiness.checkoutDisabled => l10n.cartPayHintDisabled,
  };
}

class _SubtotalRow extends StatelessWidget {
  const new({required this.subtotal});

  final CartSubtotal subtotal;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // Sin nada que sumar no se muestra "$ 0": se dice que no hay subtotal.
    final hasAmount = !subtotal.amount.isZero;
    return Semantics(
      label: hasAmount
          ? l10n.cartSubtotalSemantics(copSemanticsAmount(subtotal.amount))
          : '${l10n.cartSubtotalLabel}. ${l10n.cartSubtotalNone}',
      excludeSemantics: true,
      // `Wrap`: a texto al 200 % el importe pasa a la línea siguiente en vez de
      // desbordar la fila.
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: IprSpace.s2,
        children: [
          Text(l10n.cartSubtotalLabel, style: theme.textTheme.titleSmall),
          Text(
            hasAmount ? formatCop(subtotal.amount) : l10n.cartSubtotalNone,
            style: theme.textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}
