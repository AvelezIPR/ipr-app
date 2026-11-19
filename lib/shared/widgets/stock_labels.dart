import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/domain/stock_status.dart';

/// Texto es-CO de la disponibilidad (misma fuente para la insignia y para la
/// etiqueta de accesibilidad de la tarjeta).
String stockLabelOf(AppLocalizations l10n, StockStatus stock) =>
    switch (stock) {
      StockStatus.inStock => l10n.stockInStock,
      StockStatus.outOfStock => l10n.stockOutOfStock,
      StockStatus.onBackorder => l10n.stockOnBackorder,
      StockStatus.unknown => l10n.stockUnknown,
    };
