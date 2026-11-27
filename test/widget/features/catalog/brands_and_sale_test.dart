import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/features/catalog/catalog.dart';
import 'package:ipr_mobile/shared/widgets/product_card.dart';
import 'package:ipr_mobile/shared/widgets/state_widgets.dart';
import 'package:ipr_mobile/shared/widgets/whatsapp_button.dart';
import 'package:material_ui/material_ui.dart';

import '../../../fixtures/catalog/catalog_fixtures.dart';
import '../../../fixtures/catalog/fake_catalog_bff.dart';
import '../../../mocks/fake_http_adapter.dart';
import '../../../mocks/test_providers.dart';
import 'catalog_harness.dart';

Finder cards() => find.byType(ProductCard);

void main() {
  late FakeCatalogBff bff;

  setUp(() => bff = FakeCatalogBff());

  group('TC-136 · AC-016-1/2/5 · directorio de marcas', () {
    testWidgets('lista todas las marcas del servidor con su número', (
      tester,
    ) async {
      await pumpCatalog(tester, const BrandsScreen(), bff);
      expect(find.text('2 marcas'), findsOneWidget);
      expect(find.text('Elitech'), findsOneWidget);
      expect(find.text('Marca sin logo'), findsOneWidget);
      // El logo de un host no permitido o ausente es el marcador.
      expect(find.byIcon(Icons.image_not_supported_outlined), findsWidgets);
    });

    testWidgets('AC-016-2 · tocar una marca abre su landing', (tester) async {
      final visited = <String>[];
      await pumpCatalog(tester, const BrandsScreen(), bff, visited: visited);
      await tester.tap(find.text('Elitech'));
      await settle(tester);
      expect(visited, ['/catalog/brands/elitech']);
    });

    testWidgets(
      'AC-016-5 · sin sesión: ninguna solicitud lleva Authorization',
      (tester) async {
        await pumpCatalog(tester, const BrandsScreen(), bff);
        expect(bff.to('/brands'), hasLength(1));
        expect(
          bff.requests.every((r) => !r.headers.containsKey('Authorization')),
          isTrue,
        );
      },
    );

    testWidgets('AC-009 · sin red: error con Reintentar y recupera', (
      tester,
    ) async {
      var online = false;
      bff.on('/brands', (o) {
        if (!online) return FakeHttpAdapter.connectionError(o);
        return FakeHttpAdapter.json(brandsBody());
      });
      await pumpCatalog(tester, const BrandsScreen(), bff);
      await settle(tester);
      expect(
        find.text('No tienes conexión. Revisa tu internet.'),
        findsOneWidget,
      );
      online = true;
      await tester.tap(find.text('Reintentar'));
      await settle(tester);
      expect(find.text('Elitech'), findsOneWidget);
    });

    testWidgets('200 vacío: mensaje de que no hay marcas', (tester) async {
      bff.on('/brands', (_) => FakeHttpAdapter.json({'data': <Object?>[]}));
      await pumpCatalog(tester, const BrandsScreen(), bff);
      expect(find.text('Aún no hay marcas para mostrar.'), findsOneWidget);
    });

    testWidgets('texto al 200 % y guías de accesibilidad', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpCatalog(tester, const BrandsScreen(), bff, textScale: 2);
      expect(find.text('Elitech'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  });

  group('TC-136 · AC-016-2/3/4 · landing de marca', () {
    const screen = BrandLandingScreen(slug: 'elitech');

    void serveBrand({int n = 6}) {
      bff.on(
        '/products',
        (_) => FakeHttpAdapter.json(productPage(products(n), total: n)),
      );
    }

    testWidgets('AC-016-2 · lista los productos de la marca con su nombre', (
      tester,
    ) async {
      serveBrand();
      await pumpCatalog(tester, screen, bff);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Elitech'),
        ),
        findsOneWidget,
      );
      expect(cards(), findsWidgets);
      final request = bff.to('/products').single.queryParameters;
      expect(request['brand'], 'elitech');
      expect(request.containsKey('category'), isFalse);
      expect(find.text('6 resultados'), findsOneWidget);
    });

    testWidgets('sin el directorio, el título sale del primer producto', (
      tester,
    ) async {
      bff
        ..on('/brands', (_) => FakeHttpAdapter.problem(503, 'x'))
        ..on(
          '/products',
          (_) => FakeHttpAdapter.json(productPage(products(2))),
        );
      await pumpCatalog(tester, screen, bff);
      await settle(tester);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Elitech'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('sin directorio ni productos, el título es "Marca"', (
      tester,
    ) async {
      bff
        ..on('/brands', (_) => FakeHttpAdapter.problem(503, 'x'))
        ..on('/products', (_) => FakeHttpAdapter.json(productPage([])));
      await pumpCatalog(tester, screen, bff);
      await settle(tester);
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('Marca')),
        findsOneWidget,
      );
    });

    testWidgets('AC-016-3 · la búsqueda interna se restringe a la marca', (
      tester,
    ) async {
      serveBrand();
      bff.on(
        '/search',
        (_) => FakeHttpAdapter.json(
          productPage([product(50, name: 'Manómetro Elitech')], total: 1),
        ),
      );
      await pumpCatalog(tester, screen, bff);
      await tester.enterText(find.byType(TextField), 'manómetro');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await settle(tester);

      final search = bff.to('/search').single.queryParameters;
      expect(search['q'], 'manómetro');
      expect(search['brand'], 'elitech');
      expect(find.text('Manómetro Elitech'), findsOneWidget);
      expect(find.text('Búsqueda: manómetro'), findsOneWidget);
      // Con búsqueda no hay filtros ni orden (el contrato no los ofrece).
      expect(find.text('Filtros'), findsNothing);
      expect(find.textContaining('Ordenar'), findsNothing);
      // El término no se guarda en la caché ni viaja a /products.
      expect(
        bff.to('/products').every((r) => r.queryParameters['q'] == null),
        isTrue,
      );
    });

    testWidgets(
      'quitar la búsqueda (chip) vuelve al listado y vacía el campo',
      (tester) async {
        serveBrand();
        bff.on(
          '/search',
          (_) => FakeHttpAdapter.json(productPage([product(50)], total: 1)),
        );
        await pumpCatalog(tester, screen, bff);
        await tester.enterText(find.byType(TextField), 'manómetro');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await settle(tester);
        await tester.tap(find.text('Búsqueda: manómetro'));
        await settle(tester);
        expect(find.text('Búsqueda: manómetro'), findsNothing);
        expect(find.text('Filtros'), findsOneWidget);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          isEmpty,
        );
      },
    );

    testWidgets('el botón borrar limpia el campo y la búsqueda', (
      tester,
    ) async {
      serveBrand();
      bff.on(
        '/search',
        (_) => FakeHttpAdapter.json(productPage([product(50)], total: 1)),
      );
      await pumpCatalog(tester, screen, bff);
      expect(find.byTooltip('Borrar búsqueda'), findsNothing);
      await tester.enterText(find.byType(TextField), 'manómetro');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await settle(tester);
      await tester.tap(find.byTooltip('Borrar búsqueda'));
      await settle(tester);
      expect(find.text('Búsqueda: manómetro'), findsNothing);
      expect(find.byTooltip('Borrar búsqueda'), findsNothing);
      expect(cards(), findsWidgets);
    });

    testWidgets('búsqueda sin resultados: vacío propio y limpiar', (
      tester,
    ) async {
      serveBrand();
      bff.on('/search', (_) => FakeHttpAdapter.json(productPage([])));
      await pumpCatalog(tester, screen, bff);
      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await settle(tester);
      expect(find.text('Sin resultados para tu búsqueda'), findsOneWidget);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Limpiar filtros'));
      await settle(tester);
      expect(find.text('Sin resultados para tu búsqueda'), findsNothing);
    });

    testWidgets('AC-016-4 · marca sin productos: mensaje', (tester) async {
      bff.on('/products', (_) => FakeHttpAdapter.json(productPage([])));
      await pumpCatalog(tester, screen, bff);
      expect(find.text('Esta marca aún no tiene productos'), findsOneWidget);
    });

    testWidgets('TC-104 · 404 de la marca ≠ 503', (tester) async {
      bff.on('/products', (_) => FakeHttpAdapter.problem(404, 'not_found'));
      await pumpCatalog(tester, screen, bff);
      await settle(tester);
      expect(
        find.text('Este contenido ya no está disponible.'),
        findsOneWidget,
      );
      expect(find.text('Reintentar'), findsNothing);
    });

    testWidgets('los filtros no ofrecen la marca (ya está fijada)', (
      tester,
    ) async {
      serveBrand();
      await pumpCatalog(tester, screen, bff);
      await tester.tap(find.text('Filtros'));
      await settle(tester);
      final sheet = find.byType(BottomSheet);
      expect(
        find.descendant(of: sheet, matching: find.text('Capacidad BTU')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.text('Marca')),
        findsNothing,
      );
      // /filters se pide sin categoría.
      expect(
        bff.to('/filters').single.queryParameters.containsKey('category'),
        isFalse,
      );
    });

    testWidgets('AC-011-2 · paginación de la landing', (tester) async {
      bff.on('/products', (o) {
        final page = o.queryParameters['page'] as int;
        return FakeHttpAdapter.json(
          productPage(
            products(12, from: (page - 1) * 12 + 1),
            page: page,
            hasMore: page < 2,
          ),
        );
      });
      await pumpCatalog(tester, screen, bff);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -20000));
      await settle(tester);
      expect(
        bff.to('/products').map((r) => r.queryParameters['page']),
        containsAll(<int>[1, 2]),
      );
      expect(
        bff
            .to('/products')
            .every((r) => r.queryParameters['brand'] == 'elitech'),
        isTrue,
      );
    });

    testWidgets('texto al 200 % y guías de accesibilidad', (tester) async {
      serveBrand();
      final handle = tester.ensureSemantics();
      await pumpCatalog(tester, screen, bff, textScale: 2);
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });

    testWidgets(
      'muestra insignia Oferta en landing de marca cuando product.onSale es true',
      (tester) async {
        bff.on(
          '/products',
          (_) => FakeHttpAdapter.json(
            productPage([
              product(1, base: 'ProductSummary.on-sale.json'),
              product(2),
            ], total: 2),
          ),
        );
        await pumpCatalog(tester, screen, bff);
        expect(find.text('Oferta'), findsOneWidget);
        expect(find.text(r'Antes $ 2.350.000'), findsOneWidget);
      },
    );
  });

  group('TC-135 · AC-018 · liquidaciones', () {
    const screen = SaleScreen();

    void serveSale() {
      bff.on(
        '/liquidaciones',
        (_) => FakeHttpAdapter.json(
          productPage([
            product(1, base: 'ProductSummary.on-sale.json'),
            product(2, base: 'ProductSummary.on-sale.json'),
          ]),
        ),
      );
    }

    testWidgets(
      'AC-018-1 · precio regular tachado, especial, insignia Oferta y banner WhatsApp',
      (tester) async {
        final launcher = FakeExternalLauncher();
        serveSale();
        await pumpCatalog(tester, screen, bff, launcher: launcher);
        expect(find.text('Liquidaciones'), findsOneWidget);
        expect(
          find.text('Ofertas especiales por tiempo limitado'),
          findsOneWidget,
        );
        expect(find.byType(WhatsAppButton), findsOneWidget);
        expect(
          tester.widget<WhatsAppButton>(find.byType(WhatsAppButton)).message,
          '¡Hola IPR! Quiero aprovechar las liquidaciones.',
        );
        expect(find.text(r'Antes $ 2.350.000'), findsNWidgets(2));
        expect(find.text(r'$ 1.890.000'), findsNWidgets(2));
        expect(find.text('Oferta'), findsNWidgets(2));
        // El precio regular lleva tachado (forma, no solo color).
        final regular = tester.widget<Text>(
          find.text(r'Antes $ 2.350.000').first,
        );
        expect(regular.style?.decoration, TextDecoration.lineThrough);

        await tester.tap(find.text('Escríbenos por WhatsApp'));
        await tester.pump();
        expect(
          launcher.opened.single.queryParameters['text'],
          '¡Hola IPR! Quiero aprovechar las liquidaciones.',
        );
      },
    );

    testWidgets(
      'AC-018-2 · pide /liquidaciones y solo muestra lo que devuelve',
      (tester) async {
        serveSale();
        await pumpCatalog(tester, screen, bff);
        expect(bff.to('/liquidaciones'), hasLength(1));
        expect(bff.to('/products'), isEmpty);
        expect(cards(), findsNWidgets(2));
        // Sin filtros: el contrato de liquidaciones solo admite orden.
        expect(find.text('Filtros'), findsNothing);
        expect(find.text('Ordenar: Más recientes'), findsOneWidget);
      },
    );

    testWidgets('un producto sin oferta no lleva insignia', (tester) async {
      bff.on(
        '/liquidaciones',
        (_) => FakeHttpAdapter.json(productPage([product(1)])),
      );
      await pumpCatalog(tester, screen, bff);
      expect(find.text('Oferta'), findsNothing);
    });

    testWidgets('AC-018-4 · cambiar el orden recarga desde la página 1', (
      tester,
    ) async {
      serveSale();
      await pumpCatalog(tester, screen, bff);
      await tester.tap(find.text('Ordenar: Más recientes'));
      await settle(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Precio: mayor a menor'),
        ),
      );
      await settle(tester);
      final last = bff.to('/liquidaciones').last.queryParameters;
      expect(last['sort'], 'price-desc');
      expect(last['page'], 1);
    });

    testWidgets('AC-018-3 · carga progresiva', (tester) async {
      bff.on('/liquidaciones', (o) {
        final page = o.queryParameters['page'] as int;
        return FakeHttpAdapter.json(
          productPage(
            [
              for (var i = 0; i < 12; i++)
                product(
                  (page - 1) * 12 + i + 1,
                  base: 'ProductSummary.on-sale.json',
                ),
            ],
            page: page,
            hasMore: page < 2,
          ),
        );
      });
      await pumpCatalog(tester, screen, bff);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -30000));
      await settle(tester);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -30000));
      await settle(tester);
      expect(find.text('Llegaste al final'), findsOneWidget);
      expect(bff.to('/liquidaciones'), hasLength(2));
    });

    testWidgets(
      'AC-018-6 · sin ofertas: muestra vacío con Explorar el catálogo y WhatsApp',
      (tester) async {
        bff.on('/liquidaciones', (_) => FakeHttpAdapter.json(productPage([])));
        final visited = <String>[];
        final launcher = FakeExternalLauncher();
        await pumpCatalog(
          tester,
          screen,
          bff,
          visited: visited,
          launcher: launcher,
        );
        expect(find.text('No hay liquidaciones vigentes'), findsOneWidget);
        expect(find.text('Explorar el catálogo'), findsOneWidget);
        expect(find.text('Escríbenos por WhatsApp'), findsOneWidget);
        expect(find.byType(WhatsAppButton), findsOneWidget);
        expect(
          tester.widget<WhatsAppButton>(find.byType(WhatsAppButton)).message,
          '¡Hola IPR! Quiero aprovechar las liquidaciones.',
        );

        await tester.tap(find.text('Escríbenos por WhatsApp'));
        await tester.pump();
        expect(
          launcher.opened.single.queryParameters['text'],
          '¡Hola IPR! Quiero aprovechar las liquidaciones.',
        );

        await tester.tap(find.text('Explorar el catálogo'));
        await settle(tester);
        expect(visited, ['/catalog']);
      },
    );

    testWidgets(
      'estado vacío de liquidaciones al 200 % y guías de accesibilidad',
      (tester) async {
        bff.on('/liquidaciones', (_) => FakeHttpAdapter.json(productPage([])));
        final handle = tester.ensureSemantics();
        await pumpCatalog(tester, screen, bff, textScale: 2);
        expect(find.text('Explorar el catálogo'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      },
    );

    testWidgets('AC-009 · 503 con Reintentar; no es "sin liquidaciones"', (
      tester,
    ) async {
      bff.on('/liquidaciones', (_) => FakeHttpAdapter.problem(503, 'x'));
      await pumpCatalog(tester, screen, bff);
      await settle(tester);
      expect(
        find.text('La tienda no está disponible en este momento.'),
        findsOneWidget,
      );
      expect(find.text('No hay liquidaciones vigentes'), findsNothing);
      expect(find.byType(ErrorState), findsOneWidget);
    });

    testWidgets('texto al 200 % y guías de accesibilidad', (tester) async {
      serveSale();
      final handle = tester.ensureSemantics();
      await pumpCatalog(tester, screen, bff, textScale: 2);
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });

    testWidgets('guías con la rejilla de dos columnas', (tester) async {
      serveSale();
      final handle = tester.ensureSemantics();
      await pumpCatalog(tester, screen, bff);
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  });
}
