import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/core/providers.dart';
import 'package:ipr_mobile/features/cart/cart.dart';
import 'package:ipr_mobile/features/product_detail/domain/entities/product_detail.dart';
import 'package:ipr_mobile/features/product_detail/presentation/controllers/add_to_cart_provider.dart';
import 'package:ipr_mobile/features/product_detail/presentation/widgets/quantity_selector.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:ipr_mobile/shared/domain/stock_status.dart';
import 'package:ipr_mobile/shared/navigation/routes.dart';
import 'package:ipr_mobile/shared/widgets/max_quantity_notice.dart';
import 'package:ipr_mobile/shared/widgets/whatsapp_button.dart';
import 'package:material_ui/material_ui.dart';

/// Zona de acción de la ficha (RF-029..031, RF-062; CR-017).
///
/// * **Comprable** (precio mayor que cero **y** en stock): con la costura del
///   carrito registrada (M3) muestra selector de cantidad y "Agregar al
///   carrito"; sin ella (M1) no hay botón de compra. Siempre ofrece además la
///   asesoría por WhatsApp.
/// * **No comprable** (sin precio, agotado, bajo pedido, desconocido): sin
///   selector ni compra; aviso del motivo y "Más información" → WhatsApp con
///   nombre y SKU (RF-062), con alternativa si falla (RF-063).
class PurchaseBox extends ConsumerStatefulWidget {
  const new({required this.product, super.key, this.needsSelection = false});

  final ProductDetail product;

  /// Producto variable al que aún no se le eligió una opción (W1-01): el
  /// botón de compra se muestra desactivado con "Selecciona una opción".
  final bool needsSelection;

  @override
  ConsumerState<PurchaseBox> createState() => _PurchaseBoxState();
}

class _PurchaseBoxState extends ConsumerState<PurchaseBox> {
  late int _quantity = widget.product.summary.quantityRange.min;
  bool _adding = false;

  @override
  void didUpdateWidget(PurchaseBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Otra variación puede tener otros límites (W1-06): la cantidad elegida se
    // lleva al nuevo rango.
    final range = widget.product.summary.quantityRange;
    if (range != oldWidget.product.summary.quantityRange) {
      _quantity = range.clamp(_quantity);
    }
  }

  Future<void> _add() async {
    final action = ref.read(addToCartActionProvider);
    if (action == null || _adding) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final router = GoRouter.maybeOf(context);
    setState(() => _adding = true);
    final result = await action.add(
      productId: widget.product.id,
      quantity: widget.product.summary.quantityRange.clamp(_quantity),
      snapshot: widget.product.summary,
    );
    if (!mounted) return;
    setState(() => _adding = false);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(switch (result) {
        Ok(:final value) => SnackBar(
          content: Text(
            value.quantityLimited
                ? cartQuantityLimitedText(l10n, max: value.maxQuantity)
                : l10n.productDetailAddedToCart,
          ),
          action: SnackBarAction(
            label: l10n.productDetailViewCart,
            onPressed: () => router?.go(Routes.cart),
          ),
        ),
        Err(:final failure) => SnackBar(
          content: Text(cartAddFailureText(l10n, failure)),
        ),
      });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final product = widget.product;
    final action = ref.watch(addToCartActionProvider);
    final canBuy = product.canAddToCart;
    final message = _whatsAppMessage(l10n, product);

    final notice = canBuy
        ? null
        : switch (product.summary.availability) {
            StockStatus.outOfStock => l10n.productDetailOutOfStockNotice,
            StockStatus.onBackorder => l10n.productDetailBackorderNotice,
            StockStatus.unknown when product.price.hasPrice =>
              l10n.productDetailUnknownStockNotice,
            _ => null,
          };

    if (widget.needsSelection) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (action != null) ...[
            FilledButton(
              onPressed: null,
              child: Text(l10n.productDetailSelectOption),
            ),
            const SizedBox(height: IprSpace.s2),
            Text(
              l10n.productDetailSelectOptionHint,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: IprSpace.s3),
          ],
          WhatsAppButton(
            label: l10n.sharedWhatsappAdvice,
            message: message,
            filled: false,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canBuy && action != null) ...[
          QuantitySelector(
            value: _quantity,
            minQuantity: product.summary.quantityRange.min,
            maxQuantity: product.summary.quantityRange.max,
            onChanged: (value) => setState(() => _quantity = value),
          ),
          if (product.summary.quantityRange.isAtMax(_quantity))
            MaxQuantityNotice(
              max: product.summary.quantityRange.max,
              productName: product.name,
              whatsAppMessage: message,
            ),
          const SizedBox(height: IprSpace.s3),
          FilledButton(
            onPressed: _adding ? null : () => unawaited(_add()),
            child: Text(l10n.productDetailAddToCart),
          ),
          const SizedBox(height: IprSpace.s3),
        ],
        if (notice != null) ...[
          Semantics(
            liveRegion: true,
            child: Text(notice, style: theme.textTheme.bodyMedium),
          ),
          const SizedBox(height: IprSpace.s3),
        ],
        if (canBuy)
          WhatsAppButton(
            label: l10n.sharedWhatsappAdvice,
            message: message,
            filled: false,
          )
        else
          WhatsAppButton(
            label: l10n.priceConsult,
            message: message,
            onBeforeOpen: product.price.hasPrice
                ? null
                : () => unawaited(_trackPriceInquiry(ref, product.id)),
          ),
      ],
    );
  }

  /// Medición agregada de "Más información" en productos sin precio (RF-065).
  /// Cero PII y nunca retrasa ni bloquea WhatsApp (`AC-065-2`, `AC-065-4`).
  Future<void> _trackPriceInquiry(WidgetRef ref, int productId) async {
    try {
      await ref
          .read(analyticsSinkProvider)
          .track(
            'price_on_request_tap',
            parameters: {
              'product_id': '$productId',
              'timestamp': DateTime.now().toUtc().toIso8601String(),
            },
          );
    } on Object {
      // Silencioso: no muestra error al usuario ni impide abrir WhatsApp.
    }
  }

  /// Mensaje con nombre y SKU; sin SKU, solo el nombre (AC-062-5: nunca
  /// "undefined", "null" ni un SKU vacío).
  String _whatsAppMessage(AppLocalizations l10n, ProductDetail product) {
    final name = sanitizeWhatsAppTerm(product.name);
    final sku = sanitizeWhatsAppTerm(product.sku);
    return sku.isEmpty
        ? l10n.productDetailWhatsappMessageNoSku(name)
        : l10n.sharedWhatsappMsgProduct(name, sku);
  }
}
