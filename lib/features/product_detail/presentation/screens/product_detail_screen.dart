import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/features/product_detail/domain/entities/product_detail.dart';
import 'package:ipr_mobile/features/product_detail/presentation/controllers/product_detail_controller.dart';
import 'package:ipr_mobile/features/product_detail/presentation/widgets/product_attributes.dart';
import 'package:ipr_mobile/features/product_detail/presentation/widgets/product_description.dart';
import 'package:ipr_mobile/features/product_detail/presentation/widgets/product_gallery.dart';
import 'package:ipr_mobile/features/product_detail/presentation/widgets/product_notices.dart';
import 'package:ipr_mobile/features/product_detail/presentation/widgets/purchase_box.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/ipr_colors.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:ipr_mobile/shared/design_system/tokens/typography_tokens.dart';
import 'package:ipr_mobile/shared/domain/image_ref.dart';
import 'package:ipr_mobile/shared/domain/price_status.dart';
import 'package:ipr_mobile/shared/formatting/cop_format.dart';
import 'package:ipr_mobile/shared/navigation/routes.dart';
import 'package:ipr_mobile/shared/widgets/price_widgets.dart';
import 'package:ipr_mobile/shared/widgets/state_widgets.dart';
import 'package:ipr_mobile/shared/widgets/ui_state.dart';
import 'package:material_ui/material_ui.dart';

/// Ficha de producto (`/product/:slug`, PT-08): RF-026..032, RF-062/063.
///
/// * 404 definitivo → "Producto no disponible" con "Volver" (AC-026-6).
/// * Red o 5xx → `ErrorState` con "Reintentar"; nunca afirma que el producto
///   no existe (RF-009, TC-103).
/// * Datos guardados → `StaleBanner`.
class ProductDetailScreen extends ConsumerWidget {
  const new({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final provider = productDetailControllerProvider(slug);
    final state = ref.watch(provider);

    final Widget body = switch (state) {
      UiFailure<ProductDetail>(:final failure) when failure is NotFound =>
        const _ProductUnavailable(),
      _ => AsyncView<ProductDetail>(
        state: state,
        onRetry: () => ref.read(provider.notifier).retry(),
        builder: (context, product) => _ProductBody(product: product),
      ),
    };

    return Scaffold(
      appBar: AppBar(title: Text(l10n.productDetailTitle)),
      body: SafeArea(top: false, child: body),
    );
  }
}

/// 404: el producto ya no existe (eliminado o despublicado).
class _ProductUnavailable extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return EmptyState(
      title: l10n.productDetailUnavailableTitle,
      body: l10n.productDetailUnavailableBody,
      action: FilledButton(
        onPressed: () async {
          final popped = await Navigator.of(context).maybePop();
          if (!popped && context.mounted) {
            GoRouter.maybeOf(context)?.go(Routes.home);
          }
        },
        child: Text(l10n.productDetailBack),
      ),
    );
  }
}

class _ProductBody extends StatelessWidget {
  const new({required this.product});

  final ProductDetail product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final styles = theme.extension<IprTextStyles>()!;
    final ipr = theme.extension<IprColors>()!;
    final summary = product.summary;
    final brand = summary.brandName;
    final images = <ImageRef>[
      ...product.gallery,
      if (product.gallery.isEmpty && summary.image != null) summary.image!,
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(IprSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProductGallery(images: images, productName: product.name),
          const SizedBox(height: IprSpace.s4),
          if (brand != null && brand.isNotEmpty)
            Text(
              brand,
              style: theme.textTheme.labelMedium?.copyWith(
                color: ipr.textSecondary,
              ),
            ),
          Semantics(
            header: true,
            child: Text(product.name, style: theme.textTheme.titleLarge),
          ),
          const SizedBox(height: IprSpace.s1),
          if (product.sku.isNotEmpty)
            Text(
              AppLocalizations.of(context).sharedProductSku(product.sku),
              style: styles.monoSku.copyWith(color: ipr.textSecondary),
            ),
          const SizedBox(height: IprSpace.s3),
          _PriceBlock(product: product),
          const SizedBox(height: IprSpace.s3),
          _StockRow(product: product),
          const SizedBox(height: IprSpace.s4),
          PurchaseBox(product: product),
          const SizedBox(height: IprSpace.s4),
          ProductNotices(price: product.price),
          ProductDescription(
            shortDescription: product.shortDescription,
            descriptionHtml: product.descriptionHtml,
          ),
          const SizedBox(height: IprSpace.s4),
          ProductAttributes(attributes: product.attributes),
          const SizedBox(height: IprSpace.s5),
        ],
      ),
    );
  }
}

/// Precio IVA incluido tal como llega (sin cálculo en el cliente). El precio
/// regular tachado solo si es una oferta real. Sin precio: "Precio bajo
/// consulta" y nunca "$0" (RF-030).
class _PriceBlock extends StatelessWidget {
  const new({required this.product});

  final ProductDetail product;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final ipr = theme.extension<IprColors>()!;
    final strike = product.summary.strikeThroughPrice;

    if (product.price is OnRequest) {
      return Text(
        l10n.productDetailPriceOnRequest,
        style: theme.textTheme.titleMedium,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (strike != null)
          Padding(
            padding: const EdgeInsets.only(bottom: IprSpace.s1),
            child: Wrap(
              spacing: IprSpace.s2,
              runSpacing: IprSpace.s1,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: ipr.successContainer,
                    borderRadius: BorderRadius.circular(IprRadius.sm),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: IprSpace.s2,
                      vertical: IprSpace.s1,
                    ),
                    child: Text(
                      l10n.productDetailOnSaleBadge,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: ipr.onSuccessContainer,
                      ),
                    ),
                  ),
                ),
                Text(
                  l10n.sharedProductRegularPrice(formatCop(strike)),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: ipr.textSecondary,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ],
            ),
          ),
        PriceText(price: product.price, style: theme.textTheme.headlineLarge),
      ],
    );
  }
}

class _StockRow extends StatelessWidget {
  const new({required this.product});

  final ProductDetail product;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: StockBadge(stock: product.summary.availability),
  );
}
