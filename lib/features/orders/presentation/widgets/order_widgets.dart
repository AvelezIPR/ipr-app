import 'package:ipr_mobile/features/orders/domain/entities/order_entities.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/ipr_colors.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:ipr_mobile/shared/domain/money.dart';
import 'package:ipr_mobile/shared/formatting/cop_format.dart';
import 'package:ipr_mobile/shared/formatting/date_format.dart';
import 'package:ipr_mobile/shared/widgets/product_image.dart';
import 'package:material_ui/material_ui.dart';

/// Etiqueta de estado del pedido: prioriza `statusLabel` del servidor
/// (AC-107-1, AC-108-6) y usa un texto localizado si viene vacío.
String orderStatusText(
  AppLocalizations l10n,
  String statusLabel,
  OrderPaymentState paymentState,
) {
  final trimmed = statusLabel.trim();
  if (trimmed.isNotEmpty) return trimmed;
  return switch (paymentState) {
    OrderPaymentState.paid => l10n.ordersPaymentStatePaid,
    OrderPaymentState.pending => l10n.ordersPaymentStatePending,
    OrderPaymentState.failed => l10n.ordersPaymentStateFailed,
    OrderPaymentState.cancelled => l10n.ordersPaymentStateCancelled,
    OrderPaymentState.refunded => l10n.ordersPaymentStateRefunded,
    OrderPaymentState.unknown => l10n.ordersPaymentStateUnknown,
  };
}

/// Insignia accesible (ícono + texto, nunca solo color) del estado del pedido.
class OrderStatusBadge extends StatelessWidget {
  const new({required this.statusLabel, required this.paymentState, super.key});

  final String statusLabel;
  final OrderPaymentState paymentState;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final ipr = theme.extension<IprColors>();
    final label = orderStatusText(l10n, statusLabel, paymentState);

    final (icon, fg, bg) = switch (paymentState) {
      OrderPaymentState.paid => (
        Icons.check_circle_outline,
        ipr?.success ?? theme.colorScheme.primary,
        ipr?.successContainer ?? theme.colorScheme.surfaceContainer,
      ),
      OrderPaymentState.failed || OrderPaymentState.cancelled => (
        Icons.error_outline,
        theme.colorScheme.error,
        theme.colorScheme.errorContainer,
      ),
      OrderPaymentState.pending ||
      OrderPaymentState.refunded ||
      OrderPaymentState.unknown => (
        Icons.schedule,
        theme.colorScheme.onSurfaceVariant,
        theme.colorScheme.surfaceContainer,
      ),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(IprRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: IprSpace.s2,
          vertical: IprSpace.s1,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(child: Icon(icon, size: 16, color: fg)),
            const SizedBox(width: IprSpace.s1),
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Importe COP sin decimales y etiqueta accesible para lectores de pantalla.
class OrderMoneyText extends StatelessWidget {
  const new({
    required this.amount,
    super.key,
    this.style,
    this.negative = false,
  });

  final Money amount;
  final TextStyle? style;
  final bool negative;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final formatted = negative ? '-${formatCop(amount)}' : formatCop(amount);
    final semantics = negative
        ? '-${l10n.priceSemantics(copSemanticsAmount(amount))}'
        : l10n.priceSemantics(copSemanticsAmount(amount));
    return Semantics(
      label: semantics,
      excludeSemantics: true,
      child: Text(formatted, style: style),
    );
  }
}

/// Tarjeta de un pedido en el historial (`OrdersScreen`).
class OrderSummaryCard extends StatelessWidget {
  const new({required this.order, required this.onTap, super.key});

  final OrderSummary order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final date = order.createdAt;
    final dateText = date != null ? formatDateTime(date) : null;
    final statusText = orderStatusText(
      l10n,
      order.statusLabel,
      order.paymentState,
    );

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(IprRadius.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: IprSpace.minTapTarget),
          child: Padding(
            padding: const EdgeInsets.all(IprSpace.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        l10n.ordersOrderNumber(order.number),
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(width: IprSpace.s2),
                    ExcludeSemantics(
                      child: Icon(
                        Icons.chevron_right,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                if (dateText != null) ...[
                  const SizedBox(height: IprSpace.s1),
                  Text(dateText, style: theme.textTheme.bodySmall),
                ],
                const SizedBox(height: IprSpace.s2),
                Wrap(
                  spacing: IprSpace.s2,
                  runSpacing: IprSpace.s2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Semantics(
                      label: '${l10n.ordersDetailStatus}: $statusText',
                      excludeSemantics: true,
                      child: OrderStatusBadge(
                        statusLabel: order.statusLabel,
                        paymentState: order.paymentState,
                      ),
                    ),
                    Text(
                      l10n.ordersItemCount(order.itemCount),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: IprSpace.s3),
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: IprSpace.s2,
                    runSpacing: IprSpace.s1,
                    children: [
                      Text(
                        l10n.ordersDetailTotal,
                        style: theme.textTheme.bodyMedium,
                      ),
                      OrderMoneyText(
                        amount: order.total,
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Línea de producto dentro de `OrderDetailScreen`.
class OrderItemRow extends StatelessWidget {
  const new({required this.item, required this.showImage, super.key});

  final OrderItem item;
  final bool showImage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final image = showImage ? item.image : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: IprSpace.s2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (image != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(IprRadius.sm),
              child: SizedBox(
                width: 56,
                height: 56,
                child: ProductImage(image: image, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: IprSpace.s3),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: theme.textTheme.bodyLarge),
                const SizedBox(height: IprSpace.s1),
                Wrap(
                  spacing: IprSpace.s3,
                  runSpacing: IprSpace.s1,
                  children: [
                    Text(
                      l10n.ordersDetailQuantity(item.quantity),
                      style: theme.textTheme.bodySmall,
                    ),
                    if (item.sku != null)
                      Text(
                        l10n.ordersDetailSku(item.sku!),
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
                const SizedBox(height: IprSpace.s1),
                OrderMoneyText(
                  amount: item.total,
                  style: theme.textTheme.titleSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
