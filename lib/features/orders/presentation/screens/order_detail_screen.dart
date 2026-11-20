import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/providers.dart';
import 'package:ipr_mobile/features/orders/domain/entities/order_entities.dart';
import 'package:ipr_mobile/features/orders/domain/rules/order_detail_display_policy.dart';
import 'package:ipr_mobile/features/orders/presentation/controllers/order_detail_controller.dart';
import 'package:ipr_mobile/features/orders/presentation/widgets/order_widgets.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:ipr_mobile/shared/domain/money.dart';
import 'package:ipr_mobile/shared/formatting/date_format.dart';
import 'package:ipr_mobile/shared/navigation/routes.dart';
import 'package:ipr_mobile/shared/widgets/sensitive_screen.dart';
import 'package:ipr_mobile/shared/widgets/state_widgets.dart';
import 'package:ipr_mobile/shared/widgets/ui_state.dart';
import 'package:material_ui/material_ui.dart';

/// Detalle de un pedido (`/orders/:orderId`, RF-108, CR-053/CR-054).
class OrderDetailScreen extends ConsumerWidget {
  const new({required this.orderId, super.key});

  final int orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(orderDetailProvider(orderId));
    final title = state is UiData<OrderDetail>
        ? l10n.ordersDetailTitle(state.value.summary.number)
        : l10n.ordersDetailFallbackTitle;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SensitiveScreen(
        protection: ref.watch(screenProtectionProvider),
        child: SafeArea(
          top: false,
          child: switch (state) {
            UiFailure<OrderDetail>(failure: NotFound()) => _OrderNotFound(
              onBack: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(Routes.orders);
                }
              },
            ),
            _ => AsyncView<OrderDetail>(
              state: state,
              onRetry: ref.read(orderDetailProvider(orderId).notifier).load,
              builder: (context, detail) => _DetailBody(detail: detail),
            ),
          },
        ),
      ),
    );
  }
}

class _OrderNotFound extends StatelessWidget {
  const new({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return EmptyState(
      title: l10n.ordersDetailNotFoundTitle,
      body: l10n.ordersDetailNotFoundBody,
      action: FilledButton(
        onPressed: onBack,
        child: Text(l10n.ordersDetailBackToList),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const new({required this.detail});

  final OrderDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    const policy = OrderDetailDisplayPolicy.current;
    final summary = detail.summary;
    final date = summary.createdAt;
    final shipping = detail.shippingTotal;
    final discount = detail.discountTotal;
    final tax = detail.taxTotal;

    return ListView(
      padding: const EdgeInsets.all(IprSpace.s4),
      children: [
        OrderStatusBadge(
          statusLabel: summary.statusLabel,
          paymentState: summary.paymentState,
        ),
        const SizedBox(height: IprSpace.s4),
        if (date != null)
          _InfoRow(label: l10n.ordersDetailDate, value: formatDateTime(date)),
        _InfoRow(
          label: l10n.ordersDetailPaymentMethod,
          value: detail.paymentMethodTitle.isEmpty
              ? l10n.ordersDetailPaymentFallback
              : detail.paymentMethodTitle,
        ),
        const Divider(height: IprSpace.s6),
        Semantics(
          header: true,
          container: true,
          child: Text(
            l10n.ordersDetailProductsSection,
            style: theme.textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: IprSpace.s2),
        for (final item in detail.items) ...[
          OrderItemRow(item: item, showImage: policy.showItemImage),
          const Divider(height: 1),
        ],
        const SizedBox(height: IprSpace.s4),
        _MoneyRow(label: l10n.ordersDetailSubtotal, amount: detail.subtotal),
        if (policy.showShipping && shipping != null && !shipping.isZero)
          _MoneyRow(label: l10n.ordersDetailShipping, amount: shipping),
        if (policy.showDiscount && discount != null && !discount.isZero)
          _MoneyRow(
            label: l10n.ordersDetailDiscount,
            amount: discount,
            negative: true,
          ),
        if (policy.showTax && tax != null && !tax.isZero)
          _MoneyRow(label: l10n.ordersDetailTax, amount: tax),
        const Divider(height: IprSpace.s4),
        _MoneyRow(
          label: l10n.ordersDetailTotal,
          amount: summary.total,
          emphasized: true,
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const new({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: IprSpace.s1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          const SizedBox(width: IprSpace.s3),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoneyRow extends StatelessWidget {
  const new({
    required this.label,
    required this.amount,
    this.emphasized = false,
    this.negative = false,
  });

  final String label;
  final Money amount;
  final bool emphasized;
  final bool negative;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = emphasized
        ? theme.textTheme.titleMedium
        : theme.textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: IprSpace.s1),
      child: SizedBox(
        width: double.infinity,
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: IprSpace.s3,
          runSpacing: IprSpace.s1,
          children: [
            Text(label, style: style),
            OrderMoneyText(amount: amount, style: style, negative: negative),
          ],
        ),
      ),
    );
  }
}
