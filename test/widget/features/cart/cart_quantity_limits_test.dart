import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/cart/domain/entities/cart_validation.dart';
import 'package:ipr_mobile/shared/domain/money.dart';
import 'package:ipr_mobile/shared/domain/quantity_range.dart';
import 'package:material_ui/material_ui.dart';

import 'cart_harness.dart';

const failureOffline = Err<CartValidation>(NoConnection());

const _notice =
    'Máximo 3 unidades por producto. Para más, habla con un asesor.';

IconButton _button(WidgetTester tester, String tooltip) =>
    tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip(tooltip),
        matching: find.bySubtype<IconButton>(),
      ),
    );

void main() {
  group('W1-06 · carrito con límites por producto', () {
    testWidgets('en el máximo del producto no se puede subir y avisa', (
      tester,
    ) async {
      await pumpCart(
        tester,
        lines: [lineOf(1, 3, range: const QuantityRange(max: 3))],
        validation: FakeCartValidationRepository([failureOffline]),
      );
      expect(
        _button(tester, 'Aumentar cantidad de Producto 1').onPressed,
        isNull,
      );
      expect(find.text(_notice), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
    });

    testWidgets('por debajo del máximo no hay aviso y se puede subir', (
      tester,
    ) async {
      await pumpCart(
        tester,
        lines: [lineOf(1, 2, range: const QuantityRange(max: 3))],
        validation: FakeCartValidationRepository([failureOffline]),
      );
      expect(find.text(_notice), findsNothing);
      expect(
        _button(tester, 'Aumentar cantidad de Producto 1').onPressed,
        isNotNull,
      );
    });

    testWidgets('en el mínimo del producto no se puede bajar', (tester) async {
      await pumpCart(
        tester,
        lines: [lineOf(1, 2, range: const QuantityRange(min: 2, max: 5))],
        validation: FakeCartValidationRepository([failureOffline]),
      );
      expect(
        _button(tester, 'Disminuir cantidad de Producto 1').onPressed,
        isNull,
      );
      expect(
        _button(tester, 'Aumentar cantidad de Producto 1').onPressed,
        isNotNull,
      );
    });

    testWidgets('subir hasta el máximo muestra el aviso y deja de subir', (
      tester,
    ) async {
      final env = await pumpCart(
        tester,
        lines: [lineOf(1, 2, range: const QuantityRange(max: 3))],
        validation: FakeCartValidationRepository([failureOffline]),
      );
      await tester.tap(find.byTooltip('Aumentar cantidad de Producto 1'));
      await tester.pump();
      expect(env.state.cart.lineOf(1)!.quantity, 3);
      expect(find.text(_notice), findsOneWidget);
    });

    testWidgets('el aviso abre WhatsApp con el producto y su SKU', (
      tester,
    ) async {
      final launcher = FakeExternalLauncher();
      await pumpCart(
        tester,
        lines: [lineOf(1, 3, range: const QuantityRange(max: 3))],
        validation: FakeCartValidationRepository([failureOffline]),
        launcher: launcher,
      );
      await tester.tap(find.text('WhatsApp'));
      await tester.pump();
      final text = launcher.opened.single.queryParameters['text']!;
      expect(text, contains('Producto 1'));
      expect(text, contains('SKU-1'));
    });

    testWidgets('una revalidación con un máximo menor recorta la línea', (
      tester,
    ) async {
      final env = await pumpCart(
        tester,
        lines: [lineOf(1, 8)],
        validation: FakeCartValidationRepository([
          Ok(
            validationOf([
              ValidatedCartLine(
                id: 1,
                quantity: 8,
                status: CartLineStatus.available,
                product: productOf(
                  id: 1,
                  name: 'Producto 1',
                  sku: 'SKU-1',
                  range: const QuantityRange(max: 3),
                ),
                lineSubtotal: const Money(300000),
              ),
            ]),
          ),
        ]),
      );
      expect(env.state.cart.lineOf(1)!.quantity, 3);
      expect(find.text(_notice), findsOneWidget);
    });

    testWidgets('guías de accesibilidad con el aviso visible', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpCart(
        tester,
        lines: [lineOf(1, 3, range: const QuantityRange(max: 3))],
        validation: FakeCartValidationRepository([failureOffline]),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });

    testWidgets('texto al 200 % sin desbordar con el aviso', (tester) async {
      await pumpCart(
        tester,
        lines: [lineOf(1, 3, range: const QuantityRange(max: 3))],
        validation: FakeCartValidationRepository([failureOffline]),
        textScale: 2,
        size: const Size(360, 5000),
      );
      expect(tester.takeException(), isNull);
      expect(find.text(_notice), findsOneWidget);
    });
  });
}
