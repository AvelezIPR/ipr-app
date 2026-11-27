import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/product_detail/domain/entities/product_variant.dart';
import 'package:ipr_mobile/features/product_detail/presentation/controllers/add_to_cart_provider.dart';
import 'package:ipr_mobile/features/product_detail/product_detail.dart';
import 'package:ipr_mobile/shared/domain/money.dart';
import 'package:ipr_mobile/shared/domain/price_status.dart';
import 'package:ipr_mobile/shared/domain/quantity_range.dart';
import 'package:ipr_mobile/shared/domain/stock_status.dart';
import 'package:material_ui/material_ui.dart';

import 'product_detail_harness.dart';

final class _MutableCartQty extends Notifier<int> {
  @override
  int build() => 0;

  int get qty => state;
  set qty(int value) => state = value;
}

final _mutableCartQtyProvider = NotifierProvider<_MutableCartQty, int>(
  _MutableCartQty.new,
);

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

    testWidgets(
      'una opción de otra combinación queda habilitada, avisa y cambia limpio',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _pumpVariable(tester);

        await _choose(tester, '440 V');
        // 440 V + 3/4" no existe, pero 3/4" existe con 220 V: sigue habilitada
        // y anuncia que requiere cambiar otra opción.
        final node = tester.getSemantics(find.bySemanticsLabel('3/4"'));
        expect(node.hint, 'Requiere cambiar otra opción');
        await _choose(tester, '3/4"');
        // Al tocar 3/4" limpia 440 V y deja 3/4" seleccionada.
        expect(find.text('Selecciona una opción'), findsOneWidget);
        expect(find.text('Agregar al carrito'), findsNothing);
        expect(
          tester.getSemantics(find.bySemanticsLabel('3/4"')),
          matchesSemantics(
            label: '3/4"',
            hint: 'Toca de nuevo para quitar la opción',
            isButton: true,
            isSelected: true,
            hasSelectedState: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
          ),
        );
        // Al elegir ahora 220 V se resuelve la variación 220 V / 3/4".
        await _choose(tester, '220 V');
        expect(find.text('Agregar al carrito'), findsOneWidget);
        handle.dispose();
      },
    );

    testWidgets(
      'una opción inexistente en todo el producto queda deshabilitada',
      (tester) async {
        final handle = tester.ensureSemantics();
        final product = customProduct(
          variantAxes: const [
            ProductVariantAxis(
              slug: 'pa_voltaje',
              name: 'Voltaje',
              options: [
                ProductVariantOption(value: '220-v', label: '220 V'),
                ProductVariantOption(value: '440-v', label: '440 V'),
              ],
            ),
          ],
          variants: const [
            ProductVariant(
              id: 901,
              sku: 'SKU-901',
              price: Priced(Money(50000)),
              availability: StockStatus.inStock,
              selection: {'pa_voltaje': '220-v'},
            ),
          ],
        );
        await pumpProduct(
          tester,
          repository: FakeProductDetailRepository([
            Ok(ProductDetailLoad(product: product)),
          ]),
          addToCart: FakeAddToCart(),
          size: _tall,
        );

        final node = tester.getSemantics(find.bySemanticsLabel('440 V'));
        expect(node.hint, 'No disponible con lo que elegiste');
        await _choose(tester, '440 V');
        // 220 V sigue preseleccionada.
        expect(find.text('SKU SKU-901'), findsOneWidget);
        handle.dispose();
      },
    );

    testWidgets('preselecciona automáticamente cuando hay 1 sola variación', (
      tester,
    ) async {
      final addToCart = FakeAddToCart();
      final product = customProduct(
        name: 'Válvula única',
        variantAxes: const [
          ProductVariantAxis(
            slug: 'pa_voltaje',
            name: 'Voltaje',
            options: [ProductVariantOption(value: '220-v', label: '220 V')],
          ),
        ],
        variants: const [
          ProductVariant(
            id: 910,
            sku: 'SKU-910',
            price: Priced(Money(120000)),
            availability: StockStatus.inStock,
            selection: {'pa_voltaje': '220-v'},
          ),
        ],
      );
      await pumpProduct(
        tester,
        repository: FakeProductDetailRepository([
          Ok(ProductDetailLoad(product: product)),
        ]),
        addToCart: addToCart,
        size: _tall,
      );

      expect(find.text('Selecciona una opción'), findsNothing);
      expect(find.text('SKU SKU-910'), findsOneWidget);
      expect(find.text('Agregar al carrito'), findsOneWidget);
      await tester.tap(find.text('Agregar al carrito'));
      await tester.pump();
      expect(addToCart.calls.single.productId, 910);
    });

    testWidgets(
      'preselecciona automáticamente cuando solo 1 variación tiene precio',
      (tester) async {
        final product = customProduct(
          name: 'Válvula mixta',
          variantAxes: const [
            ProductVariantAxis(
              slug: 'pa_voltaje',
              name: 'Voltaje',
              options: [
                ProductVariantOption(value: '220-v', label: '220 V'),
                ProductVariantOption(value: '440-v', label: '440 V'),
              ],
            ),
          ],
          variants: const [
            ProductVariant(
              id: 920,
              sku: 'SKU-920',
              price: Priced(Money(150000)),
              availability: StockStatus.inStock,
              selection: {'pa_voltaje': '220-v'},
            ),
            ProductVariant(
              id: 921,
              sku: 'SKU-921',
              price: OnRequest(),
              availability: StockStatus.inStock,
              selection: {'pa_voltaje': '440-v'},
            ),
          ],
        );
        await pumpProduct(
          tester,
          repository: FakeProductDetailRepository([
            Ok(ProductDetailLoad(product: product)),
          ]),
          addToCart: FakeAddToCart(),
          size: _tall,
        );

        expect(find.text('SKU SKU-920'), findsOneWidget);
        expect(find.text('Agregar al carrito'), findsOneWidget);
      },
    );

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

    testWidgets('descuenta lo que ya está en el carrito del máximo permitido', (
      tester,
    ) async {
      final addToCart = FakeAddToCart();
      await pumpProduct(
        tester,
        repository: repoWith('ProductDetail.variable.json'),
        addToCart: addToCart,
        cartQuantities: const {4702: 2},
        size: _tall,
      );
      await _choose(tester, '220 V');
      await _choose(tester, '3/4"');

      // Máximo 3, ya hay 2 en el carrito → solo queda 1 por agregar.
      expect(find.widgetWithText(TextField, '1'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(iconButtonWith('Aumentar cantidad'))
            .onPressed,
        isNull,
      );
      expect(
        find.text(
          'Máximo 3 unidades por producto. Para más, habla con un asesor.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Agregar al carrito'));
      await tester.pump();
      expect(addToCart.calls.single, (productId: 4702, quantity: 1));
    });

    testWidgets(
      'con el máximo ya en el carrito deshabilita compra y muestra aviso',
      (tester) async {
        final addToCart = FakeAddToCart();
        await pumpProduct(
          tester,
          repository: repoWith('ProductDetail.variable.json'),
          addToCart: addToCart,
          cartQuantities: const {4702: 3},
          size: _tall,
        );
        await _choose(tester, '220 V');
        await _choose(tester, '3/4"');

        expect(find.text('Cantidad'), findsNothing);
        expect(find.text('Agregar al carrito'), findsNothing);
        final button = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Máximo en el carrito'),
        );
        expect(button.onPressed, isNull);
        expect(
          find.text(
            'Máximo 3 unidades por producto. Para más, habla con un asesor.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('con unidades en el carrito el mínimo efectivo baja a 1', (
      tester,
    ) async {
      final addToCart = FakeAddToCart();
      await pumpProduct(
        tester,
        repository: repoWith('ProductDetail.variable.json'),
        addToCart: addToCart,
        cartQuantities: const {4701: 2}, // min=2, max=12 → remaining=10
        size: _tall,
      );
      await _choose(tester, '220 V');
      await _choose(tester, '1/2"');

      expect(find.widgetWithText(TextField, '1'), findsOneWidget);
      await tester.tap(find.text('Agregar al carrito'));
      await tester.pump();
      expect(addToCart.calls.single, (productId: 4701, quantity: 1));
    });

    testWidgets(
      'al actualizarse el carrito en vivo recorta cantidad y pasa a Máximo en el carrito',
      (tester) async {
        final product = customProduct(
          id: 88,
          quantityRange: const QuantityRange(max: 3),
        );
        await pumpApp(
          tester,
          const ProductDetailScreen(slug: kSlug),
          size: _tall,
          overrides: [
            ...productOverrides(
              repository: FakeProductDetailRepository([
                Ok(ProductDetailLoad(product: product)),
              ]),
              addToCart: FakeAddToCart(),
            ),
            cartQuantityForProductProvider.overrideWith(
              (ref, productId) =>
                  productId == 88 ? ref.watch(_mutableCartQtyProvider) : 0,
            ),
          ],
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Sube a 2 en el selector.
        await tester.tap(find.byTooltip('Aumentar cantidad'));
        await tester.pump();
        expect(find.widgetWithText(TextField, '2'), findsOneWidget);

        // Ahora el carrito pasa a tener 2 → remaining=1, recorta a 1.
        final container = ProviderScope.containerOf(
          tester.element(find.byType(ProductDetailScreen)),
        );
        container.read(_mutableCartQtyProvider.notifier).qty = 2;
        await tester.pump();
        expect(find.widgetWithText(TextField, '1'), findsOneWidget);
        expect(
          find.text(
            'Máximo 3 unidades por producto. Para más, habla con un asesor.',
          ),
          findsOneWidget,
        );

        // El carrito pasa a tener 3 → "Máximo en el carrito".
        container.read(_mutableCartQtyProvider.notifier).qty = 3;
        await tester.pump();
        expect(find.text('Máximo en el carrito'), findsOneWidget);
        expect(find.text('Cantidad'), findsNothing);
      },
    );

    testWidgets(
      'Máximo en el carrito y chips con cambio de eje al 200 % sin desbordar',
      (tester) async {
        await pumpProduct(
          tester,
          repository: repoWith('ProductDetail.variable.json'),
          addToCart: FakeAddToCart(),
          cartQuantities: const {4702: 3},
          textScale: 2,
          size: _tall,
        );
        await _choose(tester, '440 V');
        expect(tester.takeException(), isNull);
        await _choose(tester, '3/4"');
        await _choose(tester, '220 V');
        expect(find.text('Máximo en el carrito'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
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
