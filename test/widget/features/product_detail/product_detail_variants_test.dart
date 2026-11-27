import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'product_detail_harness.dart';

const _tall = Size(360, 1800);

Future<FakeAddToCart> _pumpVariable(
  WidgetTester tester, {
  FakeExternalLauncher? launcher,
  double textScale = 1,
}) async {
  final addToCart = FakeAddToCart();
  await pumpProduct(
    tester,
    repository: repoWith('ProductDetail.variable.json'),
    addToCart: addToCart,
    launcher: launcher,
    textScale: textScale,
    size: _tall,
  );
  return addToCart;
}

Future<void> _choose(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pump();
}

void main() {
  group('W1-01 · ficha de un producto variable', () {
    testWidgets('sin elegir: "Desde", botón desactivado y sin stock', (
      tester,
    ) async {
      await _pumpVariable(tester);

      expect(find.text('Desde'), findsOneWidget);
      expect(find.text(r'$ 180.000'), findsOneWidget);
      expect(find.text('Voltaje'), findsOneWidget);
      expect(find.text('Diámetro'), findsOneWidget);
      expect(find.text('Agregar al carrito'), findsNothing);
      expect(find.text('En stock'), findsNothing);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Selecciona una opción'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets(
      'al elegir todo cambia precio, SKU, nombre y se puede comprar',
      (tester) async {
        final addToCart = await _pumpVariable(tester);

        await _choose(tester, '220 V');
        expect(find.text('Selecciona una opción'), findsOneWidget);
        await _choose(tester, '3/4"');

        expect(find.text('Selecciona una opción'), findsNothing);
        expect(find.text('Desde'), findsNothing);
        expect(find.text(r'$ 240.000'), findsOneWidget);
        expect(find.text(r'Antes $ 260.000'), findsOneWidget);
        expect(find.text('SKU 470-0002'), findsOneWidget);
        expect(find.text('En stock'), findsOneWidget);
        expect(
          find.text('Válvula solenoide de prueba · 220 V / 3/4"'),
          findsOneWidget,
        );

        await tester.tap(find.text('Agregar al carrito'));
        await tester.pump();
        // Al carrito va el id de la VARIACIÓN, con su opción en el nombre.
        expect(addToCart.calls.single.productId, 4702);
        expect(addToCart.calls.single.quantity, 1);
        final snapshot = addToCart.snapshots.single!;
        expect(snapshot.id, 4702);
        expect(snapshot.sku, '470-0002');
        expect(snapshot.name, 'Válvula solenoide de prueba · 220 V / 3/4"');
      },
    );

    testWidgets('una opción inexistente con lo elegido no se puede tocar', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpVariable(tester);

      await _choose(tester, '440 V');
      // 440 V + 3/4" no existe: queda deshabilitada y lo dice.
      final node = tester.getSemantics(find.bySemanticsLabel('3/4"'));
      expect(node.hint, 'No disponible con lo que elegiste');
      await _choose(tester, '3/4"');
      expect(find.text('Selecciona una opción'), findsOneWidget);
      expect(find.text('Agregar al carrito'), findsNothing);
      handle.dispose();
    });

    testWidgets('tocar la opción elegida la quita', (tester) async {
      await _pumpVariable(tester);
      await _choose(tester, '220 V');
      await _choose(tester, '1/2"');
      expect(find.text('Agregar al carrito'), findsOneWidget);

      await _choose(tester, '1/2"');
      expect(find.text('Agregar al carrito'), findsNothing);
      expect(find.text('Selecciona una opción'), findsOneWidget);
      expect(find.text('Desde'), findsOneWidget);
    });

    testWidgets('una variación sin precio ofrece "Más información" con SKU', (
      tester,
    ) async {
      final launcher = FakeExternalLauncher();
      final addToCart = await _pumpVariable(tester, launcher: launcher);

      await _choose(tester, '440 V');
      await _choose(tester, '1/2"');

      expect(find.text('Agregar al carrito'), findsNothing);
      expect(find.text('SKU 470-0003'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Más información'));
      await tester.pump();
      final text = launcher.opened.single.queryParameters['text']!;
      expect(text, contains('440 V'));
      expect(text, contains('470-0003'));
      expect(addToCart.calls, isEmpty);
    });

    testWidgets('un producto simple no muestra selector', (tester) async {
      await pumpProduct(
        tester,
        repository: repoWith('ProductDetail.priced.json'),
        addToCart: FakeAddToCart(),
        size: _tall,
      );
      expect(find.text('Selecciona una opción'), findsNothing);
      expect(find.text('Desde'), findsNothing);
      expect(find.text('Agregar al carrito'), findsOneWidget);
    });
  });

  group('W1-06 · límites de cantidad por variación', () {
    testWidgets('el máximo de la variación frena el selector y avisa', (
      tester,
    ) async {
      final addToCart = await _pumpVariable(tester);
      await _choose(tester, '220 V');
      await _choose(tester, '3/4"');

      // Máximo 3: se sube dos veces y el "+" queda desactivado.
      await tester.tap(find.byTooltip('Aumentar cantidad'));
      await tester.pump();
      expect(
        find.text(
          'Máximo 3 unidades por producto. Para más, habla con un asesor.',
        ),
        findsNothing,
      );
      await tester.tap(find.byTooltip('Aumentar cantidad'));
      await tester.pump();
      expect(
        find.text(
          'Máximo 3 unidades por producto. Para más, habla con un asesor.',
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<IconButton>(iconButtonWith('Aumentar cantidad'))
            .onPressed,
        isNull,
      );

      await tester.tap(find.text('Agregar al carrito'));
      await tester.pump();
      expect(addToCart.calls.single.productId, 4702);
      expect(addToCart.calls.single.quantity, 3);
    });

    testWidgets('el aviso abre WhatsApp con el producto, la opción y el SKU', (
      tester,
    ) async {
      final launcher = FakeExternalLauncher();
      await _pumpVariable(tester, launcher: launcher);
      await _choose(tester, '220 V');
      await _choose(tester, '3/4"');
      await tester.tap(find.byTooltip('Aumentar cantidad'));
      await tester.pump();
      await tester.tap(find.byTooltip('Aumentar cantidad'));
      await tester.pump();

      await tester.tap(find.text('WhatsApp'));
      await tester.pump();
      final text = launcher.opened.single.queryParameters['text']!;
      expect(text, contains('Válvula solenoide de prueba · 220 V / 3/4"'));
      expect(text, contains('470-0002'));
    });

    testWidgets('el mínimo de la variación sube la cantidad inicial', (
      tester,
    ) async {
      final addToCart = await _pumpVariable(tester);
      await _choose(tester, '220 V');
      await _choose(tester, '1/2"');

      // Mínimo 2: arranca en 2 y no se puede bajar de ahí.
      expect(
        tester.widget<IconButton>(iconButtonWith('Reducir cantidad')).onPressed,
        isNull,
      );
      await tester.tap(find.text('Agregar al carrito'));
      await tester.pump();
      expect(addToCart.calls.single.productId, 4701);
      expect(addToCart.calls.single.quantity, 2);
    });

    testWidgets('al cambiar de variación la cantidad se lleva al nuevo rango', (
      tester,
    ) async {
      final addToCart = await _pumpVariable(tester);
      await _choose(tester, '220 V');
      await _choose(tester, '1/2"'); // 2–12
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byTooltip('Aumentar cantidad'));
        await tester.pump();
      }
      // 6 unidades; la variación de 3/4" admite como máximo 3.
      await _choose(tester, '1/2"');
      await _choose(tester, '3/4"');
      await tester.tap(find.text('Agregar al carrito'));
      await tester.pump();
      expect(addToCart.calls.single.productId, 4702);
      expect(addToCart.calls.single.quantity, 3);
    });
  });

  group('W1-01 · accesibilidad del selector', () {
    testWidgets('guías de objetivo táctil, etiquetas y contraste', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpVariable(tester);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));

      await _choose(tester, '440 V');
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });

    testWidgets('la opción elegida se anuncia como seleccionada', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpVariable(tester);
      await _choose(tester, '220 V');
      expect(
        tester.getSemantics(find.bySemanticsLabel('220 V')),
        matchesSemantics(
          label: '220 V',
          hint: 'Toca de nuevo para quitar la opción',
          isButton: true,
          isSelected: true,
          hasSelectedState: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('texto al 200 % sin desbordar', (tester) async {
      await _pumpVariable(tester, textScale: 2);
      await _choose(tester, '220 V');
      await _choose(tester, '3/4"');
      expect(tester.takeException(), isNull);
    });
  });
}
