import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/features/cart/presentation/widgets/cart_banners.dart';
import 'package:ipr_mobile/features/cart/presentation/widgets/cart_messages.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('es'));

  group('AC-029-5 · AC-029-6 · mensajes al añadir desde la ficha', () {
    test('cada código del carrito tiene su texto', () {
      expect(
        cartAddFailureText(l10n, const Validation(code: 'cart_line_limit')),
        'Tu carrito ya tiene 100 productos distintos. Quita alguno para añadir otro.',
      );
      expect(
        cartAddFailureText(
          l10n,
          const Validation(code: 'cart_not_purchasable'),
        ),
        'Este producto no se puede comprar en la app.',
      );
      for (final code in ['cart_invalid_product', 'cart_invalid_quantity']) {
        expect(
          cartAddFailureText(l10n, Validation(code: code)),
          'No pudimos añadir el producto. Revisa la cantidad.',
        );
      }
    });

    test('cualquier otro fallo usa el mensaje general', () {
      expect(
        cartAddFailureText(l10n, const NoConnection()),
        l10n.failureNoConnection,
      );
      expect(
        cartAddFailureText(l10n, const Validation()),
        l10n.failureValidation,
      );
    });

    test('aviso de cantidad acotada al máximo', () {
      expect(
        cartQuantityLimitedText(l10n),
        'Máximo 99 unidades por producto: ajustamos la cantidad.',
      );
    });
  });

  group('RNF-020 · por qué no se pudo verificar', () {
    test('sin red se dice que el pago exige conexión', () {
      expect(
        cartVerifyFailureText(l10n, const NoConnection()),
        l10n.cartVerifyFailedOffline,
      );
    });

    test('otro fallo: mensaje general', () {
      for (final failure in [
        const ServiceUnavailable(),
        const RequestTimeout(),
        const ServerFailure(),
      ]) {
        expect(cartVerifyFailureText(l10n, failure), l10n.cartVerifyFailed);
      }
    });
  });
}
