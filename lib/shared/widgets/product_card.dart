import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/ipr_colors.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:ipr_mobile/shared/design_system/tokens/typography_tokens.dart';
import 'package:ipr_mobile/shared/domain/price_status.dart';
import 'package:ipr_mobile/shared/domain/product_summary.dart';
import 'package:ipr_mobile/shared/formatting/cop_format.dart';
import 'package:ipr_mobile/shared/widgets/price_widgets.dart';
import 'package:ipr_mobile/shared/widgets/product_image.dart';
import 'package:ipr_mobile/shared/widgets/stock_labels.dart';
import 'package:material_ui/material_ui.dart';

/// Tarjeta de producto compartida (catálogo, búsqueda, inicio, marcas,
/// liquidaciones).
///
/// * Imagen, nombre (2 líneas; 4 en variante de lista), marca, SKU, precio IVA
///   incluido o "Más información" (**nunca "$0"**) y estado de stock con
///   texto + ícono.
/// * A texto de sistema ≥ 1,5× pasa a **variante de lista de una columna**
///   (`design_system.md` §5.3, RNF-068).
/// * Un solo objetivo táctil, con etiqueta de accesibilidad completa (RNF-070).
class ProductCard extends StatelessWidget {
  const new({required this.product, required this.onTap, super.key});

  final ProductSummary product;
  final VoidCallback onTap;

  /// Escala de texto a partir de la cual se usa la variante de lista.
  static const double listVariantScale = 1.5;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final asList = scale >= listVariantScale;

    final image = AspectRatio(
      aspectRatio: 1,
      child: ProductImage(image: product.image),
    );
    final details = _Details(product: product, maxNameLines: asList ? 4 : 2);

    return Semantics(
      button: true,
      excludeSemantics: true,
      label: _semanticLabel(l10n),
      onTap: onTap,
      child: Material(
        color: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(IprRadius.xxl),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(IprSpace.s3),
            child: asList
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 96, child: image),
                      const SizedBox(width: IprSpace.s3),
                      Expanded(child: details),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      image,
                      const SizedBox(height: IprSpace.s2),
                      details,
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  String _semanticLabel(AppLocalizations l10n) {
    final price = switch (product.price) {
      Priced(:final amount) => l10n.priceSemantics(copSemanticsAmount(amount)),
      OnRequest() => l10n.priceOnRequestSemantics,
    };
    return l10n.sharedProductCardSemantics(
      product.name,
      product.brandName ?? '',
      product.sku,
      price,
      stockLabelOf(l10n, product.availability),
    );
  }
}

class _Details extends StatelessWidget {
  const new({required this.product, required this.maxNameLines});

  final ProductSummary product;
  final int maxNameLines;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final styles = theme.extension<IprTextStyles>()!;
    final ipr = theme.extension<IprColors>()!;
    final strike = product.strikeThroughPrice;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (product.brandName != null && product.brandName!.isNotEmpty)
          Text(
            product.brandName!,
            style: theme.textTheme.labelMedium?.copyWith(
              color: ipr.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        Text(
          product.name,
          style: theme.textTheme.titleSmall,
          maxLines: maxNameLines,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: IprSpace.s1),
        Text(
          l10n.sharedProductSku(product.sku),
          style: styles.monoSku.copyWith(color: ipr.textSecondary),
        ),
        const SizedBox(height: IprSpace.s2),
        if (strike != null)
          Text(
            l10n.sharedProductRegularPrice(formatCop(strike)),
            style: theme.textTheme.bodySmall?.copyWith(
              color: ipr.textSecondary,
              decoration: TextDecoration.lineThrough,
            ),
          ),
        PriceText(price: product.price),
        const SizedBox(height: IprSpace.s2),
        StockBadge(stock: product.availability),
      ],
    );
  }
}
