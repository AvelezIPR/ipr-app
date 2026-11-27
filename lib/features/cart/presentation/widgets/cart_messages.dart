import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/features/cart/domain/entities/cart.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/widgets/failure_messages.dart';

/// Texto es-CO de un rechazo al añadir al carrito (`Validation.code` con
/// prefijo `cart_`). Cualquier otro fallo usa el mensaje general.
String cartAddFailureText(AppLocalizations l10n, AppFailure failure) {
  if (failure is Validation) {
    switch (failure.code) {
      case 'cart_line_limit':
        return l10n.cartAddLineLimit;
      case 'cart_not_purchasable':
        return l10n.cartAddNotPurchasable;
      case 'cart_invalid_product' || 'cart_invalid_quantity':
        return l10n.cartAddInvalid;
    }
  }
  return failureText(l10n, failure);
}

/// Aviso cuando una cantidad se acotó al máximo por producto (AC-029-5). [max]
/// es el del producto (W1-06); sin él, el general.
String cartQuantityLimitedText(AppLocalizations l10n, {int? max}) =>
    l10n.cartAddQuantityLimited(max ?? CartLimits.maxQuantity);
