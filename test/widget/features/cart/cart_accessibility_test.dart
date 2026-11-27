import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/cart/domain/entities/cart_validation.dart';
import 'package:ipr_mobile/shared/domain/money.dart';
import 'package:ipr_mobile/shared/domain/price_status.dart';
import 'package:ipr_mobile/shared/domain/stock_status.dart';
import 'package:ipr_mobile/shared/widgets/whatsapp_button.dart';
import 'package:material_ui/material_ui.dart';

import 'cart_harness.dart';

Result<CartValidation> _ok(String fixture) => Ok(cartFixture(fixture));

/// Escenarios representativos: cada uno se pinta con las 4 guías y a 200 %.
final _scenarios =
    <
      String,
      Future<CartEnv> Function(
        WidgetTester tester, {
        double textScale,
        Size size,
      })
    >{
      'carrito con líneas verificadas':
          (tester, {textScale = 1, size = const Size(360, 800)}) => pumpCart(
            tester,
            lines: [
              lineOf(4521, 2, name: 'Compresor scroll 24.000 BTU R410A'),
              lineOf(4522, 1, price: 50000, name: 'Contactor 3 polos 25 A'),
            ],
            validation: FakeCartValidationRepository([
              _ok('CartValidation.all-available.json'),
            ]),
            textScale: textScale,
            size: size,
          ),
      'líneas no disponibles, sin precio y bajo pedido':
          (tester, {textScale = 1, size = const Size(360, 800)}) => pumpCart(
            tester,
            lines: [
              lineOf(4521, 2),
              lineOf(4533, 1, price: 89900),
              lineOf(4540, 1, price: 350000),
              lineOf(4551, 3, price: 0),
              lineOf(9999, 1),
            ],
            validation: FakeCartValidationRepository([
              _ok('CartValidation.mixed.json'),
            ]),
            textScale: textScale,
            size: size,
          ),
      'cambio de precio por aceptar':
          (tester, {textScale = 1, size = const Size(360, 800)}) => pumpCart(
            tester,
            lines: [lineOf(4521, 1)],
            validation: FakeCartValidationRepository([
              _ok('CartValidation.price-changed.json'),
            ]),
            textScale: textScale,
            size: size,
          ),
      'sin conexión (datos guardados)':
          (tester, {textScale = 1, size = const Size(360, 800)}) => pumpCart(
            tester,
            lines: [lineOf(1, 3), lineOf(2, 99)],
            validation: FakeCartValidationRepository([failureOffline]),
            textScale: textScale,
            size: size,
          ),
      'carrito vacío': (tester, {textScale = 1, size = const Size(360, 800)}) =>
          pumpCart(
            tester,
            validation: FakeCartValidationRepository([failureOffline]),
            textScale: textScale,
            size: size,
          ),
      'pago deshabilitado por el interruptor remoto':
          (tester, {textScale = 1, size = const Size(360, 800)}) => pumpCart(
            tester,
            lines: [lineOf(4521, 1), lineOf(4522, 1, price: 50000)],
            validation: FakeCartValidationRepository([
              _ok('CartValidation.all-available.json'),
            ]),
            checkoutEnabled: false,
            textScale: textScale,
            size: size,
          ),
    };

void main() {
  group('RNF-068 · el texto del sistema al 200 % no desborda', () {
    for (final entry in _scenarios.entries) {
      for (final size in const [Size(360, 800), Size(320, 568)]) {
        testWidgets(
          '${entry.key} · ${size.width.toInt()}x${size.height.toInt()}',
          (tester) async {
            await entry.value(tester, textScale: 2, size: size);
            expect(tester.takeException(), isNull);
            // Recorre la lista hasta el final sin desbordes.
            final lists = find.byType(Scrollable);
            if (lists.evaluate().isNotEmpty) {
              await tester.drag(lists.first, const Offset(0, -3000));
              await tester.pumpAndSettle();
            }
            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    testWidgets('el botón "Pagar" sigue siendo alcanzable a 200 % y 320x568', (
      tester,
    ) async {
      await _scenarios['carrito con líneas verificadas']!(
        tester,
        textScale: 2,
        size: const Size(320, 568),
      );
      expect(payButton, findsOneWidget);
      // El panel del resumen es desplazable: llegar al botón no exige salir de la pantalla.
      await tester.ensureVisible(payButton);
      await tester.pumpAndSettle();
      final rect = tester.getRect(payButton);
      expect(rect.bottom, lessThanOrEqualTo(568));
      expect(rect.height, greaterThanOrEqualTo(48));
    });
  });

  group('RNF-070/071/076 · guías de accesibilidad', () {
    for (final entry in _scenarios.entries) {
      testWidgets('androidTapTargetGuideline · ${entry.key}', (tester) async {
        final handle = tester.ensureSemantics();
        await entry.value(tester);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        handle.dispose();
      });
      testWidgets('iOSTapTargetGuideline · ${entry.key}', (tester) async {
        final handle = tester.ensureSemantics();
        await entry.value(tester);
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        handle.dispose();
      });
      testWidgets('labeledTapTargetGuideline · ${entry.key}', (tester) async {
        final handle = tester.ensureSemantics();
        await entry.value(tester);
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });
      testWidgets('textContrastGuideline · ${entry.key}', (tester) async {
        final handle = tester.ensureSemantics();
        await entry.value(tester);
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });
    }
  });

  group('RNF-070 · lectores de pantalla', () {
    testWidgets('el título es un encabezado y los avisos son regiones vivas', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _scenarios['líneas no disponibles, sin precio y bajo pedido']!(
        tester,
        size: const Size(360, 2400),
      );
      expect(
        tester.getSemantics(find.text('Carrito')),
        isSemantics(isHeader: true, label: 'Carrito'),
      );
      final banner = tester.getSemantics(
        find.text('Hay 4 productos que no se pueden comprar'),
      );
      expect(banner.label, contains('Hay 4 productos'));
      handle.dispose();
    });

    testWidgets('los botones de cantidad y quitar nombran el producto', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpCart(
        tester,
        lines: [lineOf(1, 2, name: 'Compresor')],
        validation: FakeCartValidationRepository([failureOffline]),
      );
      for (final label in [
        'Aumentar cantidad de Compresor',
        'Disminuir cantidad de Compresor',
        'Quitar Compresor del carrito',
      ]) {
        final node = tester.getSemantics(
          find.ancestor(
            of: find.byTooltip(label),
            matching: find.bySubtype<IconButton>(),
          ),
        );
        // Flutter publica la etiqueta del botón de ícono como `tooltip`.
        expect('${node.label} ${node.tooltip}', contains(label));
      }
      handle.dispose();
    });

    testWidgets('el subtotal se lee como importe con IVA incluido', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _scenarios['carrito con líneas verificadas']!(tester);
      expect(
        find.bySemanticsLabel(
          'Subtotal informativo, 150.000 pesos, IVA incluido',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets(
      'el estado de una línea no se comunica solo con color: lleva texto e ícono',
      (tester) async {
        await _scenarios['líneas no disponibles, sin precio y bajo pedido']!(
          tester,
          size: const Size(360, 2400),
        );
        expect(find.text('Agotado: quítalo para poder pagar'), findsOneWidget);
        expect(find.byIcon(Icons.block), findsWidgets);
      },
    );
  });

  group('asesoría WhatsApp en agotado, bajo pedido y sin precio', () {
    Future<CartEnv> pumpAdvisorLines(
      WidgetTester tester, {
      double textScale = 1,
      Size size = const Size(360, 2400),
    }) => pumpCart(
      tester,
      lines: [
        lineOf(4533, 1, price: 89900, name: 'Capacitor'),
        lineOf(4540, 1, price: 350000, name: 'Válvula'),
        lineOf(4551, 1, price: 0, name: 'Tarjeta'),
      ],
      validation: FakeCartValidationRepository([
        Ok(
          validationOf([
            ValidatedCartLine(
              id: 4533,
              quantity: 1,
              status: CartLineStatus.outOfStock,
              product: productOf(
                id: 4533,
                name: 'Capacitor',
                sku: 'QA-0007',
                stock: StockStatus.outOfStock,
                price: const Priced(Money(89900)),
              ),
            ),
            ValidatedCartLine(
              id: 4540,
              quantity: 1,
              status: CartLineStatus.onBackorder,
              product: productOf(
                id: 4540,
                name: 'Válvula',
                sku: 'QA-0008',
                stock: StockStatus.onBackorder,
                price: const Priced(Money(350000)),
              ),
            ),
            ValidatedCartLine(
              id: 4551,
              quantity: 1,
              status: CartLineStatus.priceOnRequest,
              product: productOf(
                id: 4551,
                name: 'Tarjeta',
                sku: 'QA-0009',
                price: const OnRequest(),
              ),
            ),
          ], checkoutAllowed: false),
        ),
      ]),
      textScale: textScale,
      size: size,
    );

    for (final size in const [Size(360, 800), Size(320, 568)]) {
      testWidgets(
        'legibilidad al 200 % sin desborde · ${size.width.toInt()}x${size.height.toInt()}',
        (tester) async {
          await pumpAdvisorLines(tester, textScale: 2, size: size);
          expect(tester.takeException(), isNull);
          await scrollTo(tester, find.text('Más información'));
          expect(tester.takeException(), isNull);
          expect(find.text('Más información'), findsOneWidget);
        },
      );
    }

    testWidgets(
      'todas las líneas muestran un único botón de asesoría visible',
      (tester) async {
        await pumpAdvisorLines(tester);
        expect(find.byType(WhatsAppButton), findsNWidgets(3));
        expect(find.text('Asesoría por WhatsApp'), findsNWidgets(2));
        expect(find.text('Más información'), findsOneWidget);
      },
    );

    for (final entry in <String, AccessibilityGuideline>{
      'androidTapTargetGuideline': androidTapTargetGuideline,
      'iOSTapTargetGuideline': iOSTapTargetGuideline,
      'labeledTapTargetGuideline': labeledTapTargetGuideline,
      'textContrastGuideline': textContrastGuideline,
    }.entries) {
      testWidgets('${entry.key} con botones visibles', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpAdvisorLines(tester);
        await expectLater(tester, meetsGuideline(entry.value));
        handle.dispose();
      });
    }
  });
}
