import 'package:ipr_mobile/features/cart/domain/entities/cart_overview.dart';
import 'package:ipr_mobile/features/cart/domain/entities/cart_validation.dart';
import 'package:ipr_mobile/features/cart/presentation/widgets/cart_banners.dart';
import 'package:ipr_mobile/features/cart/presentation/widgets/quantity_stepper.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:ipr_mobile/shared/domain/price_status.dart';
import 'package:ipr_mobile/shared/formatting/cop_format.dart';
import 'package:ipr_mobile/shared/widgets/price_widgets.dart';
import 'package:ipr_mobile/shared/widgets/product_image.dart';
import 'package:ipr_mobile/shared/widgets/whatsapp_button.dart';
import 'package:material_ui/material_ui.dart';

/// Una línea del carrito (RF-049, RF-050): imagen, nombre, SKU, precio vigente,
/// aviso de estado o de cambio, cantidad y quitar.
///
/// El contenido se acomoda en varias líneas a texto de sistema al 200 %
/// (los controles pasan a la línea siguiente con `Wrap`).
class CartLineTile extends StatelessWidget {
  const new({
    required this.view,
    required this.onQuantityChanged,
    required this.onRemove,
    super.key,
  });

  final CartLineView view;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onRemove;

  static const _imageSize = 72.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final name = view.name ?? l10n.cartLineUnnamed(view.productId);
    final sku = view.sku;
    final brand = view.brandName;
    final price = view.unitPrice;
    final subtotal = view.lineSubtotal;
    final isPriceOnRequest =
        price is OnRequest || view.status == CartLineStatus.priceOnRequest;
    final showAdvisor =
        isPriceOnRequest ||
        view.status == CartLineStatus.outOfStock ||
        view.status == CartLineStatus.onBackorder;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: IprSpace.s1),
      child: Padding(
        padding: const EdgeInsets.all(IprSpace.s3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: _imageSize,
                  height: _imageSize,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(IprRadius.md),
                    child: ProductImage(image: view.image),
                  ),
                ),
                const SizedBox(width: IprSpace.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: theme.textTheme.titleSmall),
                      if (brand != null)
                        Text(brand, style: theme.textTheme.bodySmall),
                      if (sku != null && sku.isNotEmpty)
                        Text(
                          l10n.sharedProductSku(sku),
                          style: theme.textTheme.bodySmall,
                        ),
                      if (price is Priced) ...[
                        const SizedBox(height: IprSpace.s1),
                        PriceText(price: price),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (_statusText(l10n, view.status) case final status?) ...[
              const SizedBox(height: IprSpace.s2),
              CartNotice(icon: Icons.block, title: status, isError: true),
            ],
            if (showAdvisor) ...[
              const SizedBox(height: IprSpace.s2),
              WhatsAppButton(
                label: isPriceOnRequest
                    ? l10n.priceConsult
                    : l10n.sharedWhatsappAdvice,
                message: _whatsAppMessage(l10n, name, sku),
                filled: false,
                expand: false,
              ),
            ],
            if (_changeText(l10n, view.change) case final change?) ...[
              const SizedBox(height: IprSpace.s2),
              CartNotice(icon: Icons.sell_outlined, title: change),
            ],
            const SizedBox(height: IprSpace.s2),
            Wrap(
              spacing: IprSpace.s3,
              runSpacing: IprSpace.s1,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                CartQuantityStepper(
                  quantity: view.quantity,
                  productName: name,
                  range: view.quantityRange,
                  whatsAppMessage: _whatsAppMessage(l10n, name, sku),
                  onChanged: onQuantityChanged,
                ),
                IconButton(
                  tooltip: l10n.cartLineRemove(name),
                  constraints: const BoxConstraints(
                    minWidth: IprSpace.minTapTarget,
                    minHeight: IprSpace.minTapTarget,
                  ),
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            if (subtotal != null && view.quantity > 1)
              Semantics(
                label: l10n.cartLineSubtotalSemantics(
                  copSemanticsAmount(subtotal),
                ),
                excludeSemantics: true,
                child: Text(
                  l10n.cartLineSubtotal(formatCop(subtotal)),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Aviso de por qué la línea no se puede comprar. `available` no lleva aviso.
  static String? _statusText(AppLocalizations l10n, CartLineStatus? status) =>
      switch (status) {
        null || CartLineStatus.available => null,
        CartLineStatus.outOfStock => l10n.cartStatusOutOfStock,
        CartLineStatus.onBackorder => l10n.cartStatusOnBackorder,
        CartLineStatus.priceOnRequest => l10n.cartStatusPriceOnRequest,
        CartLineStatus.notFound => l10n.cartStatusNotFound,
      };

  /// Aviso de cambio de precio (anterior y nuevo, AC-050-2) o, si solo cambió
  /// la disponibilidad, un aviso general.
  static String? _changeText(AppLocalizations l10n, CartLineChange? change) {
    if (change == null || !change.hasChange) return null;
    final previous = change.previousPrice;
    final current = change.currentPrice;
    if (change.priceChanged) {
      if (previous is Priced && current is Priced) {
        return l10n.cartLinePriceChanged(
          formatCop(previous.amount),
          formatCop(current.amount),
        );
      }
      if (previous is Priced) {
        return l10n.cartLinePriceChangedToNone(formatCop(previous.amount));
      }
      if (current is Priced) {
        return l10n.cartLinePriceChangedFromNone(formatCop(current.amount));
      }
    }
    return l10n.cartLineAvailabilityChanged;
  }

  static String _whatsAppMessage(
    AppLocalizations l10n,
    String name,
    String? sku,
  ) {
    final cleanName = sanitizeWhatsAppTerm(name);
    final cleanSku = sanitizeWhatsAppTerm(sku ?? '');
    return cleanSku.isEmpty
        ? l10n.sharedWhatsappMsgAdvice
        : l10n.sharedWhatsappMsgProduct(cleanName, cleanSku);
  }
}
