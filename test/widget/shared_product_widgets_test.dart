import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/config/remote_config.dart';
import 'package:ipr_mobile/core/config/remote_config_controller.dart';
import 'package:ipr_mobile/core/config/remote_config_repository.dart'
    show RemoteConfigSource;
import 'package:ipr_mobile/shared/domain/image_ref.dart';
import 'package:ipr_mobile/shared/domain/money.dart';
import 'package:ipr_mobile/shared/domain/price_status.dart';
import 'package:ipr_mobile/shared/domain/product_summary.dart';
import 'package:ipr_mobile/shared/domain/stock_status.dart';
import 'package:ipr_mobile/shared/widgets/product_card.dart';
import 'package:ipr_mobile/shared/widgets/product_image.dart';
import 'package:ipr_mobile/shared/widgets/whatsapp_button.dart';
import 'package:material_ui/material_ui.dart';

import '../mocks/pump_app.dart';
import '../mocks/test_providers.dart';

ProductSummary product({
  PriceStatus price = const Priced(Money(1445000)),
  StockStatus stock = StockStatus.inStock,
  bool onSale = false,
  Money? regular,
  ImageRef? image,
  String name = 'Detector de fugas CO2 R744 Elitech',
}) => ProductSummary(
  id: 55,
  slug: 'detector-co2',
  name: name,
  sku: '500-0144',
  brandName: 'Elitech',
  price: price,
  availability: stock,
  onSale: onSale,
  regularPrice: regular,
  image: image,
);

void main() {
  group('TC-119 · RNF-068/070 · ProductCard', () {
    testWidgets('muestra marca, nombre, SKU, precio IVA incluido y stock', (
      tester,
    ) async {
      var taps = 0;
      await pumpApp(
        tester,
        ProductCard(product: product(), onTap: () => taps++),
        overrides: testOverrides(),
      );
      expect(find.text('Elitech'), findsOneWidget);
      expect(find.text('Detector de fugas CO2 R744 Elitech'), findsOneWidget);
      expect(find.text('SKU 500-0144'), findsOneWidget);
      expect(find.text(r'$ 1.445.000'), findsOneWidget);
      expect(find.text('IVA incluido'), findsOneWidget);
      expect(find.text('En stock'), findsOneWidget);
      await tester.tap(find.byType(ProductCard));
      expect(taps, 1);
    });

    testWidgets(
      r'TC-052 · AC-012-1 · sin precio: "Más información" y jamás "$0"',
      (tester) async {
        await pumpApp(
          tester,
          ProductCard(
            product: product(price: const OnRequest()),
            onTap: () {},
          ),
          overrides: testOverrides(),
        );
        expect(find.text('Más información'), findsOneWidget);
        expect(find.textContaining(r'$'), findsNothing);
      },
    );

    testWidgets('oferta real: precio regular tachado; oferta falsa no', (
      tester,
    ) async {
      await pumpApp(
        tester,
        ProductCard(
          product: product(onSale: true, regular: const Money(1800000)),
          onTap: () {},
        ),
        overrides: testOverrides(),
      );
      expect(find.text(r'Antes $ 1.800.000'), findsOneWidget);

      await pumpApp(
        tester,
        ProductCard(
          product: product(onSale: true, regular: const Money(1000000)),
          onTap: () {},
        ),
        overrides: testOverrides(),
      );
      expect(
        find.textContaining('Antes'),
        findsNothing,
        reason: 'el precio "regular" menor que el vigente no es una oferta',
      );
    });

    testWidgets('la etiqueta de accesibilidad resume la tarjeta', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpApp(
        tester,
        ProductCard(product: product(), onTap: () {}),
        overrides: testOverrides(),
      );
      expect(
        find.bySemanticsLabel(
          'Detector de fugas CO2 R744 Elitech. Elitech. SKU 500-0144. '
          '1.445.000 pesos, IVA incluido. En stock.',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets(
      'AC-011-7 · a texto 1,0 es tarjeta de columna; desde 1,5 pasa a lista',
      (tester) async {
        await pumpApp(
          tester,
          ProductCard(product: product(), onTap: () {}),
          overrides: testOverrides(),
        );
        final columnWidth = tester.getSize(find.byType(AspectRatio)).width;
        final columnHeight = tester.getSize(find.byType(ProductCard)).height;
        expect(
          columnWidth,
          greaterThan(96),
          reason: 'a 1,0 la imagen ocupa el ancho de la tarjeta',
        );

        await pumpApp(
          tester,
          ProductCard(product: product(), onTap: () {}),
          textScale: 1.5,
          size: const Size(360, 1200),
          overrides: testOverrides(),
        );
        // En lista la imagen ocupa 96 dp de ancho, no el ancho completo.
        final imageWidth = tester.getSize(find.byType(AspectRatio)).width;
        expect(imageWidth, 96);
        expect(columnHeight, greaterThan(imageWidth));
      },
    );

    testWidgets('a texto 2,0 el nombre admite 4 líneas y no desborda', (
      tester,
    ) async {
      await pumpApp(
        tester,
        SingleChildScrollView(
          child: ProductCard(
            product: product(
              name: 'Mini Split Inverter Samsung Deluxe 12000 BTU 220V R410a con instalación',
            ),
            onTap: () {},
          ),
        ),
        textScale: 2,
        overrides: testOverrides(),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('TC-157 · guías de accesibilidad', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(
        tester,
        ProductCard(product: product(), onTap: () {}),
        overrides: testOverrides(),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  });

  group('SC-043 · ProductImage solo carga hosts permitidos', () {
    testWidgets(
      'sin imagen o con host no permitido muestra el marcador (sin red)',
      (tester) async {
        await pumpApp(
          tester,
          const ProductImage(image: null),
          overrides: testOverrides(),
        );
        expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);

        await pumpApp(
          tester,
          const ProductImage(
            image: ImageRef(url: 'https://evil.example.com/a.png', alt: ''),
          ),
          overrides: testOverrides(),
        );
        expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);

        await pumpApp(
          tester,
          const ProductImage(
            image: ImageRef(url: 'http://staging.invalid/a.png', alt: ''),
          ),
          overrides: testOverrides(),
        );
        expect(
          find.byIcon(Icons.image_not_supported_outlined),
          findsOneWidget,
          reason: 'http no se permite aunque el host coincida',
        );
      },
    );

    testWidgets(
      'con host permitido intenta cargar (y cae al marcador si falla)',
      (tester) async {
        await pumpApp(
          tester,
          const SizedBox(
            width: 100,
            height: 100,
            child: ProductImage(
              image: ImageRef(
                url: 'https://staging.invalid/a.png',
                alt: 'foto',
              ),
              semanticLabel: 'foto',
            ),
          ),
          overrides: testOverrides(),
        );
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byType(ProductImage), findsOneWidget);
      },
    );
  });

  group('TC-055 · TC-056 · RF-062/063 · WhatsAppButton', () {
    testWidgets('abre wa.me con el mensaje prellenado y el número de /config', (
      tester,
    ) async {
      final launcher = FakeExternalLauncher();
      await pumpApp(
        tester,
        const WhatsAppButton(
          label: 'Asesoría',
          message: 'Hola, quiero más información sobre X (SKU 1).',
        ),
        overrides: testOverrides(
          launcher: launcher,
          extra: [
            remoteConfigProvider.overrideWithBuild(
              (ref, notifier) => const RemoteConfigState(
                config: RemoteConfig(whatsappNumber: '+57 301 402 1882'),
                source: RemoteConfigSource.network,
              ),
            ),
          ],
        ),
      );
      await tester.tap(find.text('Asesoría'));
      await tester.pump();
      final uri = launcher.opened.single;
      expect(uri.host, 'wa.me');
      expect(uri.path, '/573014021882');
      expect(
        uri.queryParameters['text'],
        'Hola, quiero más información sobre X (SKU 1).',
      );
    });

    testWidgets('sin /config usa el WhatsApp público de respaldo del flavor', (
      tester,
    ) async {
      final launcher = FakeExternalLauncher();
      await pumpApp(
        tester,
        const WhatsAppButton(label: 'Asesoría', message: 'Hola'),
        overrides: testOverrides(launcher: launcher),
      );
      await tester.tap(find.text('Asesoría'));
      await tester.pump();
      expect(launcher.opened.single.path, '/573000000000');
    });

    testWidgets('si falla ofrece llamar o abrir WhatsApp web', (tester) async {
      final launcher = FakeExternalLauncher(results: [false, true]);
      await pumpApp(
        tester,
        const WhatsAppButton(label: 'Asesoría', message: 'Hola mundo'),
        overrides: testOverrides(
          launcher: launcher,
          extra: [
            remoteConfigProvider.overrideWithBuild(
              (ref, notifier) => const RemoteConfigState(
                config: RemoteConfig(
                  whatsappNumber: '573014021882',
                  phoneDial: '+576043604440',
                ),
                source: RemoteConfigSource.network,
              ),
            ),
          ],
        ),
      );
      await tester.tap(find.text('Asesoría'));
      await tester.pumpAndSettle();
      expect(find.text('No pudimos abrir WhatsApp'), findsOneWidget);
      expect(find.text('Llamar a la línea de atención'), findsOneWidget);
      await tester.tap(find.text('Abrir WhatsApp en el navegador'));
      await tester.pumpAndSettle();
      final web = launcher.opened.last;
      expect(web.host, 'api.whatsapp.com');
      expect(web.queryParameters['phone'], '573014021882');
      expect(web.queryParameters['text'], 'Hola mundo');
    });

    testWidgets(
      'la alternativa de llamada abre tel: con el número de /config',
      (tester) async {
        final launcher = FakeExternalLauncher(results: [false, true]);
        await pumpApp(
          tester,
          const WhatsAppButton(
            label: 'Asesoría',
            message: 'Hola',
            filled: false,
            expand: false,
          ),
          overrides: testOverrides(
            launcher: launcher,
            extra: [
              remoteConfigProvider.overrideWithBuild(
                (ref, notifier) => const RemoteConfigState(
                  config: RemoteConfig(phoneDial: '+576043604440'),
                  source: RemoteConfigSource.network,
                ),
              ),
            ],
          ),
        );
        await tester.tap(find.text('Asesoría'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Llamar a la línea de atención'));
        await tester.pumpAndSettle();
        expect(launcher.opened.last.scheme, 'tel');
        expect(launcher.opened.last.path, '+576043604440');
      },
    );

    testWidgets('sin teléfono en /config no se ofrece llamar', (tester) async {
      final launcher = FakeExternalLauncher(result: false);
      await pumpApp(
        tester,
        const WhatsAppButton(label: 'Asesoría', message: 'Hola'),
        overrides: testOverrides(launcher: launcher),
      );
      await tester.tap(find.text('Asesoría'));
      await tester.pumpAndSettle();
      expect(find.text('Llamar a la línea de atención'), findsNothing);
      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();
      expect(find.text('No pudimos abrir WhatsApp'), findsNothing);
    });

    test(
      'sanitizeWhatsAppTerm colapsa espacios y recorta a 100 caracteres',
      () {
        expect(
          sanitizeWhatsAppTerm('  compresor \n  tecumseh  '),
          'compresor tecumseh',
        );
        expect(sanitizeWhatsAppTerm('a' * 150), hasLength(100));
      },
    );
  });
}
