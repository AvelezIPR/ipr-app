import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/ipr_colors.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:ipr_mobile/shared/design_system/tokens/typography_tokens.dart';
import 'package:ipr_mobile/shared/domain/money.dart';
import 'package:ipr_mobile/shared/domain/price_status.dart';
import 'package:ipr_mobile/shared/domain/stock_status.dart';
import 'package:ipr_mobile/shared/formatting/cop_format.dart';
import 'package:material_ui/material_ui.dart';

/// Precio de un producto. Sin precio muestra "Más información" y **jamás**
/// "$0" (RF-012). El lector de pantalla recibe "N pesos, IVA incluido".
class PriceText extends StatelessWidget {
  const new({required this.price, super.key, this.style});

  final PriceStatus price;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final base = style ?? theme.extension<IprTextStyles>()!.priceCard;
    return switch (price) {
      Priced(:final amount) => Semantics(
        label: l10n.priceSemantics(copSemanticsAmount(amount)),
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(formatCop(amount), style: base),
            Text(
              l10n.priceTaxIncluded,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      OnRequest() => Semantics(
        label: l10n.priceOnRequestSemantics,
        excludeSemantics: true,
        child: Text(l10n.priceConsult, style: theme.textTheme.titleSmall),
      ),
    };
  }
}

/// Precio "Desde $X" de un producto variable (W1-01): el mínimo entre sus
/// variaciones con precio. Sin ese mínimo (o en cero) muestra "Más
/// información" y **jamás** "$0" (RF-012). El lector de pantalla recibe
/// "Desde N pesos, IVA incluido".
class FromPriceText extends StatelessWidget {
  const new({required this.from, super.key, this.style});

  final Money? from;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final amount = from;
    if (amount == null || amount.isZero) {
      return PriceText(price: const OnRequest(), style: style);
    }
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final base = style ?? theme.extension<IprTextStyles>()!.priceCard;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Semantics(
      label: l10n.priceFromSemantics(copSemanticsAmount(amount)),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.priceFrom, style: muted),
          Text(formatCop(amount), style: base),
          Text(l10n.priceTaxIncluded, style: muted),
        ],
      ),
    );
  }
}

/// Insignia de disponibilidad: texto + ícono, nunca solo color (RNF-076).
class StockBadge extends StatelessWidget {
  const new({required this.stock, super.key});

  final StockStatus stock;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final ipr = theme.extension<IprColors>()!;
    final (label, icon, background, foreground) = switch (stock) {
      StockStatus.inStock => (
        l10n.stockInStock,
        Icons.check_circle_outline,
        ipr.successContainer,
        ipr.onSuccessContainer,
      ),
      StockStatus.outOfStock => (
        l10n.stockOutOfStock,
        Icons.cancel_outlined,
        theme.colorScheme.errorContainer,
        theme.colorScheme.onErrorContainer,
      ),
      StockStatus.onBackorder => (
        l10n.stockOnBackorder,
        Icons.schedule,
        theme.colorScheme.primaryContainer,
        theme.colorScheme.onPrimaryContainer,
      ),
      StockStatus.unknown => (
        l10n.stockUnknown,
        Icons.help_outline,
        theme.colorScheme.surfaceContainer,
        theme.colorScheme.onSurface,
      ),
    };
    final iconColor = stock == StockStatus.inStock
        ? ipr.success
        : stock == StockStatus.outOfStock
        ? theme.colorScheme.error
        : foreground;
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
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
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: IprSpace.s1),
              // Flexible: a texto de sistema al 200 % la etiqueta se ajusta en
              // varias líneas en vez de desbordar (RNF-068).
              Flexible(
                child: Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
