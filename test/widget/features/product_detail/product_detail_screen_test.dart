import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/config/remote_config.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/shared/domain/money.dart';
import 'package:ipr_mobile/shared/domain/price_status.dart';
import 'package:ipr_mobile/shared/domain/stock_status.dart';
import 'package:ipr_mobile/shared/widgets/state_widgets.dart';
import 'package:material_ui/material_ui.dart';

import 'product_detail_harness.dart';

void main() {
  group('TC-122 · AC-026-1 · ficha con precio y en stock', () {
    testWidgets('muestra marca, nombre, SKU, precio, oferta y stock', (
      tester,
    ) async {
      await pumpProduct(
        tester,
        repository: repoWith('ProductDetail.priced.json'),
      );

      expect(find.text('Copeland'), findsOneWidget);
      expect(find.text('Compresor scroll 24.000 BTU R410A'), findsOneWidget);
      expect(find.text('SKU 500-0144'), findsOneWidget);
      expect(find.text(r'$ 1.234.567'), findsOneWidget);
      expect(find.text('IVA incluido'), findsOneWidget);
      expect(find.text('Oferta'), findsOneWidget);
      expect(find.text(r'Antes $ 1.500.000'), findsOneWidget);
      expect(find.text('En stock'), findsOneWidget);
      expect(find.byType(StaleBanner), findsNothing);
    });

    testWidgets('AC-026-5 · el precio coincide con el del servidor', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpProduct(
        tester,
        repository: repoWith('ProductDetail.priced.json'),
      );
      expect(
        find.bySemanticsLabel('1.234.567 pesos, IVA incluido'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('sin oferta real no hay precio tachado ni insignia', (
      tester,
    ) async {
      await pumpProduct(
        tester,
        repository: FakeProductDetailRepository([
          Ok(
            ProductDetailLoad(
              product: fixtureProduct('ProductDetail.out-of-stock.json'),
            ),
          ),
        ]),
      );
      expect(find.text('Oferta'), findsNothing);
      expect(find.textContaining('Antes'), findsNothing);
    });

    testWidgets('AC-026-4 · solo disponibilidad genérica, sin cantidades', (
      tester,
    ) async {
      await pumpProduct(
        tester,
        repository: repoWith('ProductDetail.priced.json'),
      );
      expect(find.text('En stock'), findsOneWidget);
      expect(find.textContaining('unidades'), findsNothing);
      expect(find.textContaining('disponibles'), findsNothing);
    });

    testWidgets(
      'M1: sin carrito registrado NO hay "Agregar al carrito" ni cantidad',
      (tester) async {
        await pumpProduct(
          tester,
          repository: repoWith('ProductDetail.priced.json'),
        );
        expect(find.text('Agregar al carrito'), findsNothing);
        expect(find.text('Cantidad'), findsNothing);
        // Sí ofrece la asesoría por WhatsApp.
        expect(find.text('Asesoría por WhatsApp'), findsOneWidget);
      },
    );
  });

  group('AC-032-1..3 · RF-032 · avisos desde /config (D-12)', () {
    testWidgets('con precio: envío y garantía tal como llegan, sin inventar', (
      tester,
    ) async {
      await pumpProduct(
        tester,
        repository: repoWith('ProductDetail.priced.json'),
        config: const RemoteConfig(
          shippingNotice: 'AVISO-ENVIO-DEL-SERVIDOR',
          warrantyNotice: 'AVISO-GARANTIA-DEL-SERVIDOR',
          priceOnRequestNotice: 'AVISO-BAJO-CONSULTA',
        ),
      );
      expect(find.text('AVISO-ENVIO-DEL-SERVIDOR'), findsOneWidget);
      expect(find.text('AVISO-GARANTIA-DEL-SERVIDOR'), findsOneWidget);
      expect(find.text('AVISO-BAJO-CONSULTA'), findsNothing);
    });

    testWidgets('sin precio: solo el aviso de precio bajo consulta', (
      tester,
    ) async {
      await pumpProduct(
        tester,
        repository: repoWith('ProductDetail.on-request.json'),
        config: const RemoteConfig(
          shippingNotice: 'AVISO-ENVIO-DEL-SERVIDOR',
          warrantyNotice: 'AVISO-GARANTIA-DEL-SERVIDOR',
          priceOnRequestNotice: 'AVISO-BAJO-CONSULTA',
        ),
      );
      expect(find.text('AVISO-BAJO-CONSULTA'), findsOneWidget);
      expect(find.text('AVISO-ENVIO-DEL-SERVIDOR'), findsNothing);
      expect(find.text('AVISO-GARANTIA-DEL-SERVIDOR'), findsNothing);
    });

    testWidgets(
      'avisos nulos o vacíos: no se muestra nada (sin texto propio)',
      (tester) async {
        await pumpProduct(
          tester,
          repository: repoWith('ProductDetail.priced.json'),
          config: const RemoteConfig(shippingNotice: '  ', warrantyNotice: ''),
        );
        expect(find.byIcon(Icons.info_outline), findsNothing);
        expect(find.textContaining('transportadora'), findsNothing);
        expect(find.textContaining('arantía'), findsNothing);
      },
    );
  });

  group('AC-029 · selector de cantidad detrás de la costura del carrito', () {
    testWidgets('con la acción registrada: cantidad 1 y "Agregar al carrito"', (
      tester,
    ) async {
      final cart = FakeAddToCart();
      await pumpProduct(
        tester,
        repository: repoWith('ProductDetail.priced.json'),
        addToCart: cart,
      );
      expect(find.text('Cantidad'), findsOneWidget);
      expect(find.widgetWithText(TextField, '1'), findsOneWidget);
      expect(find.text('Agregar al carrito'), findsOneWidget);
    });

    testWidgets('+ y − respetan 1 y 99; agrega id y cantidad elegidos', (
      tester,
    ) async {
      final cart = FakeAddToCart();
      await pumpProduct(
        tester,
        repository: repoWith('ProductDetail.priced.json'),
        addToCart: cart,
      );
      final minus = iconButtonWith('Reducir cantidad');
      final plus = iconButtonWith('Aumentar cantidad');
      expect(tester.widget<IconButton>(minus).onPressed, isNull);

      await tester.ensureVisible(plus);
      await tester.tap(plus);
      await tester.pump();
      await tester.tap(plus);
      await tester.pump();
      expect(find.widgetWithText(TextField, '3'), findsOneWidget);

      await tester.tap(minus);
      await tester.pump();
      expect(find.widgetWithText(TextField, '2'), findsOneWidget);

      await tester.tap(find.text('Agregar al carrito'));
      await tester.pump();
      expect(cart.calls.single, (productId: 4521, quantity: 2));
      expect(find.text('Producto agregado al carrito'), findsOneWidget);
      expect(find.text('Ver carrito'), findsOneWidget);
    });

    testWidgets('AC-029-3 · lo escrito fuera de rango se corrige con mensaje', (
      tester,
    ) async {
      final cart = FakeAddToCart();
      await pumpProduct(
        tester,
        repository: repoWith('ProductDetail.priced.json'),
        addToCart: cart,
      );
      final field = find.byType(TextField);
      await tester.ensureVisible(field);

      await tester.enterText(field, '150');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(find.widgetWithText(TextField, '99'), findsOneWidget);
      expect(find.text('La cantidad debe estar entre 1 y 99.'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(iconButtonWith('Aumentar cantidad'))
            .onPressed,
        isNull,
      );

      await tester.enterText(field, '0');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(find.widgetWithText(TextField, '1'), findsOneWidget);
      expect(find.text('La cantidad debe estar entre 1 y 99.'), findsOneWidget);

      await tester.enterText(field, '5');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(find.text('La cantidad debe estar entre 1 y 99.'), findsNothing);
      await tester.tap(find.text('Agregar al carrito'));
      await tester.pump();
      expect(cart.calls.single.quantity, 5);
    });

    testWidgets(
      'si el carrito rechaza, muestra el motivo y no afirma que agregó',
      (tester) async {
        final cart = FakeAddToCart(result: const Err(ServerFailure()));
        await pumpProduct(
          tester,
          repository: repoWith('ProductDetail.priced.json'),
          addToCart: cart,
        );
        await tester.ensureVisible(find.text('Agregar al carrito'));
        await tester.tap(find.text('Agregar al carrito'));
        await tester.pump();
        expect(find.text('Algo salió mal. Intenta de nuevo.'), findsOneWidget);
        expect(find.text('Producto agregado al carrito'), findsNothing);
      },
    );
  });

  group('TC-053 · RF-030 · RF-062 · sin precio: "Más información"', () {
    testWidgets(r'sin cifra, sin "$0", sin selector ni compra', (tester) async {
      await pumpProduct(
        tester,
        repository: repoWith('ProductDetail.on-request.json'),
        addToCart: FakeAddToCart(),
      );
      expect(find.text('Precio bajo consulta'), findsOneWidget);
      expect(find.text('Más información'), findsOneWidget);
      expect(find.textContaining(r'$'), findsNothing);
      expect(find.text('IVA incluido'), findsNothing);
      expect(find.text('Agregar al carrito'), findsNothing);
      expect(find.text('Cantidad'), findsNothing);
    });

    testWidgets(
      'abre WhatsApp con nombre y SKU (sin sesión ni datos personales)',
      (tester) async {
        final launcher = FakeExternalLauncher();
        await pumpProduct(
          tester,
          repository: repoWith('ProductDetail.on-request.json'),
          launcher: launcher,
        );
        await tester.tap(find.text('Más información'));
        await tester.pump();
        final uri = launcher.opened.single;
        expect(uri.host, 'wa.me');
        expect(
          uri.queryParameters['text'],
          'Hola, quiero más información sobre Unidad condensadora especial (SKU 500-0145).',
        );
      },
    );

    testWidgets(
      'AC-062-2 · nombre con comillas, & y # se codifica y vuelve idéntico',
      (tester) async {
        final launcher = FakeExternalLauncher();
        const name = 'Válvula 1/4" & tubo #3';
        await pumpProduct(
          tester,
          repository: FakeProductDetailRepository([
            Ok(
              ProductDetailLoad(
                product: customProduct(
                  name: name,
                  sku: 'ABC-123',
                  price: const OnRequest(),
                ),
              ),
            ),
          ]),
          launcher: launcher,
        );
        await tester.tap(find.text('Más información'));
        await tester.pump();
        final uri = launcher.opened.single;
        expect(uri.toString(), isNot(contains('"')));
        expect(uri.toString(), isNot(contains('#')));
        final text = Uri.splitQueryString(uri.query)['text']!;
        expect(text, contains(name));
        expect(text, contains('ABC-123'));
      },
    );

    testWidgets('AC-062-5 · sin SKU el mensaje lleva el nombre y no "null"', (
      tester,
    ) async {
      final launcher = FakeExternalLauncher();
      await pumpProduct(
        tester,
        repository: FakeProductDetailRepository([
          Ok(
            ProductDetailLoad(
              product: customProduct(
                name: 'Filtro raro',
                sku: '',
                price: const OnRequest(),
              ),
            ),
          ),
        ]),
        launcher: launcher,
      );
      await tester.tap(find.text('Más información'));
      await tester.pump();
      final text = launcher.opened.single.queryParameters['text']!;
      expect(text, 'Hola, quiero más información sobre Filtro raro.');
      for (final bad in ['null', 'undefined', 'SKU']) {
        expect(text, isNot(contains(bad)));
      }
    });

    testWidgets('TC-057 · RF-063 · si WhatsApp falla, ofrece web y llamada', (
      tester,
    ) async {
      final launcher = FakeExternalLauncher(results: [false, true]);
      await pumpProduct(
        tester,
        repository: repoWith('ProductDetail.on-request.json'),
        launcher: launcher,
        config: const RemoteConfig(
          whatsappNumber: '573014021882',
          phoneDial: '+576043604440',
        ),
      );
      await tester.tap(find.text('Más información'));
      await tester.pumpAndSettle();
      expect(find.text('No pudimos abrir WhatsApp'), findsOneWidget);
      expect(find.text('Llamar a la línea de atención'), findsOneWidget);
      await tester.tap(find.text('Abrir WhatsApp en el navegador'));
      await tester.pumpAndSettle();
      final web = launcher.opened.last;
      expect(web.host, 'api.whatsapp.com');
      expect(
        web.queryParameters['text'],
        contains('Unidad condensadora especial'),
        reason: 'AC-063-3: el mensaje se conserva en la alternativa web',
      );
    });
  });

  group('TC-058 · TC-059 · RF-031 · CR-017 · agotado y bajo pedido', () {
    testWidgets('agotado: "Agotado", sin compra aunque haya carrito', (
      tester,
    ) async {
      final cart = FakeAddToCart();
      await pumpProduct(
        tester,
        repository: repoWith('ProductDetail.out-of-stock.json'),
        addToCart: cart,
      );
      expect(find.text('Agotado'), findsOneWidget);
      expect(find.text('Este producto está agotado.'), findsOneWidget);
      expect(find.text('Agregar al carrito'), findsNothing);
      expect(find.text('Cantidad'), findsNothing);
      expect(find.text('Más información'), findsOneWidget);
      expect(cart.calls, isEmpty);
    });

    testWidgets('bajo pedido: con precio pero NO comprable; ofrece consulta', (
      tester,
    ) async {
      final cart = FakeAddToCart();
      await pumpProduct(
        tester,
        repository: repoWith('ProductDetail.backorder.json'),
        addToCart: cart,
      );
      expect(find.text('Bajo pedido'), findsOneWidget);
      expect(find.text(r'$ 320.000'), findsOneWidget);
      expect(find.textContaining('disponible bajo pedido'), findsOneWidget);
      expect(find.text('Agregar al carrito'), findsNothing);
      expect(find.text('Cantidad'), findsNothing);
      expect(find.text('Más información'), findsOneWidget);
    });

    testWidgets('disponibilidad desconocida y precio 0: sin cifra ni compra', (
      tester,
    ) async {
      await pumpProduct(
        tester,
        repository: repoWith('ProductDetail.unknown-availability.json'),
        addToCart: FakeAddToCart(),
      );
      expect(find.text('Disponibilidad por confirmar'), findsOneWidget);
      expect(find.text('Precio bajo consulta'), findsOneWidget);
      expect(find.textContaining(r'$'), findsNothing);
      expect(find.text('Agregar al carrito'), findsNothing);
    });

    testWidgets(
      'producto en stock con precio pero purchasable=false: no se compra',
      (tester) async {
        await pumpProduct(
          tester,
          repository: FakeProductDetailRepository([
            Ok(
              ProductDetailLoad(
                product: customProduct(serverPurchasable: false),
              ),
            ),
          ]),
          addToCart: FakeAddToCart(),
        );
        expect(find.text('Agregar al carrito'), findsNothing);
        expect(find.text('Más información'), findsOneWidget);
      },
    );
  });

  group('TC-103 · TC-104 · AC-026-6/-7 · RF-009 · estados de error', () {
    testWidgets('carga: indicador accesible y nada más', (tester) async {
      final repo = PendingProductDetailRepository();
      await pumpProduct(tester, repository: repo);
      expect(find.byType(LoadingState), findsOneWidget);
      expect(find.text('Compresor scroll 24.000 BTU R410A'), findsNothing);
    });

    testWidgets(
      '404: "Producto no disponible" con "Volver", sin texto técnico',
      (tester) async {
        await pumpProduct(
          tester,
          repository: FakeProductDetailRepository([const Err(NotFound())]),
        );
        expect(find.text('Producto no disponible'), findsOneWidget);
        expect(
          find.text('Este producto ya no está disponible.'),
          findsOneWidget,
        );
        expect(find.text('Volver'), findsOneWidget);
        expect(find.text('Reintentar'), findsNothing);
        expect(find.textContaining('404'), findsNothing);
        // "Volver" sin pila ni router no falla.
        await tester.tap(find.text('Volver'));
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('503: error con "Reintentar"; NO afirma que no existe', (
      tester,
    ) async {
      await pumpProduct(
        tester,
        repository: FakeProductDetailRepository([
          const Err(ServiceUnavailable()),
        ]),
      );
      expect(
        find.text('La tienda no está disponible en este momento.'),
        findsOneWidget,
      );
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.text('Producto no disponible'), findsNothing);
      expect(find.textContaining('503'), findsNothing);
    });

    testWidgets('AC-009-3 · sin red: "Reintentar" y al volver la red carga', (
      tester,
    ) async {
      final repo = FakeProductDetailRepository([
        const Err(NoConnection()),
        Ok(loadOf('ProductDetail.priced.json')),
      ]);
      await pumpProduct(tester, repository: repo);
      expect(
        find.text('No tienes conexión. Revisa tu internet.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Reintentar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Compresor scroll 24.000 BTU R410A'), findsOneWidget);
      expect(find.text('Reintentar'), findsNothing);
      expect(repo.calls.last.forceRefresh, isTrue);
    });

    testWidgets('RNF-022 · datos obsoletos: ficha completa con aviso', (
      tester,
    ) async {
      await pumpProduct(
        tester,
        repository: repoWith('ProductDetail.priced.json', stale: true),
      );
      expect(find.byType(StaleBanner), findsOneWidget);
      expect(
        find.text(
          'Mostrando información guardada; puede no estar actualizada.',
        ),
        findsOneWidget,
      );
      expect(find.text('Compresor scroll 24.000 BTU R410A'), findsOneWidget);
    });
  });

  group('RNF-068 · texto al 200 % sin desbordar', () {
    for (final fixture in [
      'ProductDetail.priced.json',
      'ProductDetail.on-request.json',
      'ProductDetail.out-of-stock.json',
      'ProductDetail.backorder.json',
    ]) {
      testWidgets('$fixture a 200 % con carrito: sin excepciones', (
        tester,
      ) async {
        await pumpProduct(
          tester,
          repository: repoWith(fixture),
          addToCart: FakeAddToCart(),
          textScale: 2,
          config: const RemoteConfig(
            shippingNotice: 'Envío a todo Colombia: valor según transportadora',
            warrantyNotice: 'Garantía según condiciones del fabricante',
            priceOnRequestNotice: 'Solicita tu cotización por WhatsApp',
          ),
        );
        expect(tester.takeException(), isNull);
        // El contenido completo es alcanzable al desplazar.
        final scroll = find.byType(SingleChildScrollView).first;
        await tester.drag(scroll, const Offset(0, -2000));
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('errores a 200 % también son desplazables', (tester) async {
      await pumpProduct(
        tester,
        repository: FakeProductDetailRepository([
          const Err(ServiceUnavailable()),
        ]),
        textScale: 2,
        size: const Size(320, 480),
      );
      expect(tester.takeException(), isNull);
      await pumpProduct(
        tester,
        repository: FakeProductDetailRepository([const Err(NotFound())]),
        textScale: 2,
        size: const Size(320, 480),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('RNF-070/071/072 · accesibilidad', () {
    testWidgets(
      'guías de objetivo táctil, etiquetas y contraste (con carrito)',
      (tester) async {
        final handle = tester.ensureSemantics();
        await pumpProduct(
          tester,
          repository: repoWith('ProductDetail.priced.json'),
          addToCart: FakeAddToCart(),
          config: const RemoteConfig(
            shippingNotice: 'Envío según transportadora',
          ),
        );
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      },
    );

    testWidgets('guías en la ficha sin precio', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpProduct(
        tester,
        repository: repoWith('ProductDetail.on-request.json'),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });

    testWidgets('el nombre es un encabezado y la galería se anuncia', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpProduct(
        tester,
        repository: repoWith('ProductDetail.priced.json'),
      );
      expect(
        tester.getSemantics(find.text('Compresor scroll 24.000 BTU R410A')),
        matchesSemantics(
          label: 'Compresor scroll 24.000 BTU R410A',
          isHeader: true,
          textDirection: TextDirection.ltr,
        ),
      );
      expect(
        find.bySemanticsLabel('Galería de imágenes, imagen 1 de 3'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  test('PriceStatus de los fixtures de prueba son los esperados', () {
    expect(
      fixtureProduct('ProductDetail.priced.json').price,
      const Priced(Money(1234567)),
    );
    expect(
      fixtureProduct('ProductDetail.on-request.json').price,
      const OnRequest(),
    );
    expect(
      fixtureProduct('ProductDetail.backorder.json').summary.availability,
      StockStatus.onBackorder,
    );
  });
}
