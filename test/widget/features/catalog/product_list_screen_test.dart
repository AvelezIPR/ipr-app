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

const screen = ProductListScreen(categorySlug: 'minisplit');

Finder cards() => find.byType(ProductCard);

/// Texto dentro de la hoja inferior (evita chocar con las tarjetas).
Finder inSheet(String text) =>
    find.descendant(of: find.byType(BottomSheet), matching: find.text(text));

void main() {
  late FakeCatalogBff bff;

  setUp(() => bff = FakeCatalogBff());

  /// Páginas de [perPage] productos con ids consecutivos.
  void servePages({int pages = 3, int perPage = 12, int? total}) {
    bff.on('/products', (o) {
      final page = o.queryParameters['page'] as int;
      return FakeHttpAdapter.json(
        productPage(
          products(perPage, from: (page - 1) * perPage + 1),
          page: page,
          total: total ?? pages * perPage,
          hasMore: page < pages,
        ),
      );
    });
  }

  Future<void> scrollToEnd(WidgetTester tester) async {
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -20000));
    await settle(tester);
  }

  Future<void> openFilters(WidgetTester tester) async {
    await tester.tap(find.text('Filtros'));
    await settle(tester);
  }

  Future<void> applyFilters(WidgetTester tester) async {
    await tester.tap(find.text('Aplicar'));
    await settle(tester);
  }

  group('AC-011-1 · AC-002-2 · listado de una categoría', () {
    testWidgets('muestra tarjetas, contador y el nombre de la categoría', (
      tester,
    ) async {
      servePages();
      await pumpCatalog(tester, screen, bff);
      // El título sale del árbol de categorías (caché de taxonomía).
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Minisplit'),
        ),
        findsOneWidget,
      );
      expect(cards(), findsWidgets);
      expect(find.text('Producto de prueba 1'), findsOneWidget);
      expect(find.text('36 resultados'), findsOneWidget);
      expect(find.text(r'$ 1.445.000'), findsWidgets);
      expect(find.text('IVA incluido'), findsWidgets);
      expect(find.text('En stock'), findsWidgets);
      expect(
        bff.to('/products').first.queryParameters['category'],
        'minisplit',
      );
    });

    testWidgets('una categoría fuera del árbol usa el título "Productos"', (
      tester,
    ) async {
      servePages();
      await pumpCatalog(
        tester,
        const ProductListScreen(categorySlug: 'no-esta-en-el-arbol'),
        bff,
      );
      expect(find.text('Productos'), findsOneWidget);
    });

    testWidgets('sin categoría lista el catálogo general', (tester) async {
      servePages();
      await pumpCatalog(tester, const ProductListScreen(), bff);
      expect(cards(), findsWidgets);
      expect(
        bff.to('/products').first.queryParameters.containsKey('category'),
        isFalse,
      );
    });

    testWidgets('tocar una tarjeta abre la ficha del producto', (tester) async {
      servePages();
      final visited = <String>[];
      await pumpCatalog(tester, screen, bff, visited: visited);
      await tester.tap(cards().first);
      await settle(tester);
      expect(visited, ['/product/producto-1']);
    });

    testWidgets('el icono de búsqueda abre la búsqueda', (tester) async {
      servePages();
      final visited = <String>[];
      await pumpCatalog(tester, screen, bff, visited: visited);
      await tester.tap(find.byTooltip('Buscar productos'));
      await settle(tester);
      expect(visited, ['/search']);
    });

    testWidgets(
      'AC-012-5 · 3 de 10 sin precio: exactamente 3 "Más información"',
      (tester) async {
        bff.on(
          '/products',
          (_) => FakeHttpAdapter.json(
            productPage([
              for (var i = 1; i <= 10; i++)
                product(
                  i,
                  base: i <= 3
                      ? 'ProductSummary.on-request.json'
                      : 'ProductSummary.priced.json',
                ),
            ]),
          ),
        );
        await pumpCatalog(tester, screen, bff, size: const Size(360, 6000));
        expect(find.text('Más información'), findsNWidgets(3));
        expect(find.text(r'$ 1.445.000'), findsNWidgets(7));
        expect(find.textContaining(r'$ 0'), findsNothing);
        expect(find.textContaining('NaN'), findsNothing);
      },
    );

    testWidgets(
      'AC-011-4 · producto sin imagen: marcador sin romper el diseño',
      (tester) async {
        bff.on(
          '/products',
          (_) => FakeHttpAdapter.json(
            productPage([product(1, base: 'ProductSummary.no-image.json')]),
          ),
        );
        await pumpCatalog(tester, screen, bff);
        expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
        expect(find.text('Agotado'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'muestra insignia Oferta en categoría cuando product.onSale es true',
      (tester) async {
        bff.on(
          '/products',
          (_) => FakeHttpAdapter.json(
            productPage([
              product(1, base: 'ProductSummary.on-sale.json'),
              product(2),
            ]),
          ),
        );
        await pumpCatalog(tester, screen, bff);
        expect(find.text('Oferta'), findsOneWidget);
        expect(find.text(r'Antes $ 2.350.000'), findsOneWidget);
      },
    );
  });

  group('TC-118 · AC-011-2/3 · carga progresiva', () {
    testWidgets('al llegar al final pide la página siguiente sin repetir', (
      tester,
    ) async {
      servePages();
      await pumpCatalog(tester, screen, bff);
      expect(bff.to('/products'), hasLength(1));
      await scrollToEnd(tester);
      final pages = bff
          .to('/products')
          .map((r) => r.queryParameters['page'])
          .toList();
      expect(pages.first, 1);
      expect(pages, contains(2));
      expect(pages.toSet().length, pages.length, reason: 'páginas repetidas');
    });

    testWidgets(
      'tras la última página indica el fin y no hay más solicitudes',
      (tester) async {
        servePages(pages: 2);
        await pumpCatalog(tester, screen, bff);
        await scrollToEnd(tester);
        await scrollToEnd(tester);
        expect(find.text('Llegaste al final'), findsOneWidget);
        final count = bff.to('/products').length;
        expect(count, 2);
        await scrollToEnd(tester);
        expect(bff.to('/products'), hasLength(count));
      },
    );

    testWidgets('AC-011-8 · ids repetidos del servidor no duplican tarjetas', (
      tester,
    ) async {
      bff.on('/products', (o) {
        final page = o.queryParameters['page'] as int;
        return FakeHttpAdapter.json(
          productPage(
            products(12, from: page == 1 ? 1 : 7),
            page: page,
            hasMore: page < 2,
          ),
        );
      });
      // Pantalla alta: se construyen todas las tarjetas y, como la lista no
      // llena el desplazamiento, se pide sola la segunda página.
      await pumpCatalog(tester, screen, bff, size: const Size(360, 12000));
      await settle(tester);
      expect(find.text('Llegaste al final'), findsOneWidget);
      // Ids 1..18 (12 + 12 con 6 repetidos): 18 tarjetas, no 24.
      expect(cards(), findsNWidgets(18));
      expect(find.text('Producto de prueba 7'), findsOneWidget);
      expect(find.text('Producto de prueba 18'), findsOneWidget);
    });
  });

  group('TC-101 · AC-009-5 · fallo de una página intermedia', () {
    testWidgets('conserva lo cargado y reintenta solo esa página', (
      tester,
    ) async {
      var failPage2 = true;
      bff.on('/products', (o) {
        final page = o.queryParameters['page'] as int;
        if (page == 2 && failPage2) {
          return FakeHttpAdapter.problem(503, 'service_unavailable');
        }
        return FakeHttpAdapter.json(
          productPage(
            products(12, from: (page - 1) * 12 + 1),
            page: page,
            hasMore: page < 2,
          ),
        );
      });
      await pumpCatalog(tester, screen, bff);
      await scrollToEnd(tester);
      await scrollToEnd(tester);
      // Pie con el mensaje y "Reintentar"; los 12 de la página 1 siguen.
      expect(
        find.text('La tienda no está disponible en este momento.'),
        findsOneWidget,
      );
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.text('Producto de prueba 12'), findsOneWidget);
      expect(find.text('Sin resultados'), findsNothing);
      final requested = bff.to('/products').length;

      failPage2 = false;
      await tester.tap(find.text('Reintentar'));
      await settle(tester);
      await scrollToEnd(tester);
      expect(find.text('Reintentar'), findsNothing);
      expect(find.text('Producto de prueba 24'), findsOneWidget);
      expect(find.text('Llegaste al final'), findsOneWidget);
      expect(bff.to('/products').length, greaterThan(requested));
    });
  });

  group('TC-099/100 · AC-009 · errores de la primera carga', () {
    testWidgets(
      'AC-009-7 · sin red: error con Reintentar, nunca "sin resultados"',
      (tester) async {
        var online = false;
        bff.on('/products', (o) {
          if (!online) return FakeHttpAdapter.connectionError(o);
          return FakeHttpAdapter.json(productPage(products(3)));
        });
        await pumpCatalog(tester, screen, bff);
        await settle(tester);
        expect(
          find.text('No tienes conexión. Revisa tu internet.'),
          findsOneWidget,
        );
        expect(find.text('No hay productos en esta categoría'), findsNothing);
        expect(find.text('Sin resultados'), findsNothing);

        online = true;
        await tester.tap(find.text('Reintentar'));
        await settle(tester);
        expect(find.text('Producto de prueba 1'), findsOneWidget);
        expect(
          find.text('No tienes conexión. Revisa tu internet.'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'TC-104 · 404 ("ya no está disponible", sin Reintentar) ≠ 503',
      (tester) async {
        bff.on('/products', (_) => FakeHttpAdapter.problem(404, 'not_found'));
        await pumpCatalog(tester, screen, bff);
        await settle(tester);
        expect(
          find.text('Este contenido ya no está disponible.'),
          findsOneWidget,
        );
        expect(find.text('Reintentar'), findsNothing);
        expect(
          find.text('La tienda no está disponible en este momento.'),
          findsNothing,
        );
      },
    );

    testWidgets('TC-104 · 503: "La tienda no está disponible" con Reintentar', (
      tester,
    ) async {
      bff.on('/products', (_) => FakeHttpAdapter.problem(503, 'x'));
      await pumpCatalog(tester, screen, bff);
      await settle(tester);
      expect(
        find.text('La tienda no está disponible en este momento.'),
        findsOneWidget,
      );
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.text('Este contenido ya no está disponible.'), findsNothing);
    });

    testWidgets(
      'AC-010-3 · categoría vacía: tarjeta comercial WhatsApp y búsqueda',
      (tester) async {
        bff.on('/products', (_) => FakeHttpAdapter.json(productPage([])));
        final visited = <String>[];
        final launcher = FakeExternalLauncher();
        await pumpCatalog(
          tester,
          screen,
          bff,
          visited: visited,
          launcher: launcher,
        );
        expect(find.text('Disponible por WhatsApp'), findsOneWidget);
        expect(
          find.text('¡Encuentra aquí los productos de Minisplit!'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Aunque nuestro catálogo en línea'),
          findsOneWidget,
        );
        expect(find.byType(WhatsAppButton), findsOneWidget);
        expect(
          tester.widget<WhatsAppButton>(find.byType(WhatsAppButton)).message,
          '¡Hola IPR! Quiero comprar productos de la categoría «Minisplit».',
        );

        await tester.tap(find.text('Comprar por WhatsApp'));
        await tester.pump();
        expect(launcher.opened.single.host, 'wa.me');
        expect(
          launcher.opened.single.queryParameters['text'],
          '¡Hola IPR! Quiero comprar productos de la categoría «Minisplit».',
        );

        await tester.tap(find.text('Buscar productos'));
        await settle(tester);
        expect(visited, ['/search']);
      },
    );

    testWidgets(
      'categoría vacía con subcategorías hijas muestra botones navegables',
      (tester) async {
        bff.on('/products', (_) => FakeHttpAdapter.json(productPage([])));
        final visited = <String>[];
        await pumpCatalog(
          tester,
          const ProductListScreen(categorySlug: 'aire-acondicionado'),
          bff,
          visited: visited,
        );
        expect(
          find.text('¡Encuentra aquí los productos de Aire acondicionado!'),
          findsOneWidget,
        );
        expect(find.text('Subcategorías disponibles'), findsOneWidget);
        expect(find.text('Minisplit'), findsOneWidget);
        expect(find.text('Cassette'), findsOneWidget);

        await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
        await tester.pump();
        await tester.tap(find.text('Minisplit'));
        await settle(tester);
        expect(visited, ['/catalog/list?category=minisplit']);
      },
    );

    testWidgets(
      'categoría vacía sin nombre en el árbol usa texto genérico y WhatsApp',
      (tester) async {
        bff.on('/products', (_) => FakeHttpAdapter.json(productPage([])));
        await pumpCatalog(
          tester,
          const ProductListScreen(categorySlug: 'no-esta-en-el-arbol'),
          bff,
        );
        expect(
          find.text('¡Encuentra aquí los productos de esta categoría!'),
          findsOneWidget,
        );
        expect(
          tester.widget<WhatsAppButton>(find.byType(WhatsAppButton)).message,
          '¡Hola IPR! Quiero comprar productos de esta categoría.',
        );
      },
    );

    testWidgets(
      'catálogo general vacío (sin categoría) conserva EmptyState estándar',
      (tester) async {
        bff.on('/products', (_) => FakeHttpAdapter.json(productPage([])));
        await pumpCatalog(tester, const ProductListScreen(), bff);
        expect(find.text('No hay productos en esta categoría'), findsOneWidget);
        expect(find.text('Disponible por WhatsApp'), findsNothing);
        expect(find.text('Buscar productos'), findsOneWidget);
      },
    );

    testWidgets(
      'datos guardados con la red caída: listado + aviso de obsoletos',
      (tester) async {
        servePages(pages: 1);
        await pumpCatalog(tester, screen, bff);
        expect(find.byType(StaleBanner), findsNothing);
        // Se tira para refrescar con la red caída: se usa la página guardada.
        bff.on('/products', FakeHttpAdapter.connectionError);
        await tester.fling(
          find.byType(CustomScrollView),
          const Offset(0, 400),
          1000,
        );
        await settle(tester);
        expect(find.byType(StaleBanner), findsOneWidget);
        expect(find.text('Producto de prueba 1'), findsOneWidget);
        // Nunca se confunde con "sin resultados".
        expect(find.text('No hay productos en esta categoría'), findsNothing);
      },
    );
  });

  group('TC-120 · AC-013 · filtros activos, chips y "Limpiar filtros"', () {
    void serveFiltered() {
      bff.on('/products', (o) {
        final q = o.queryParameters;
        final filtered =
            q.containsKey('brand') || q.containsKey('attr[pa_capacidad-btu]');
        return FakeHttpAdapter.json(
          productPage(
            products(filtered ? 4 : 12, from: filtered ? 100 : 1),
            total: filtered ? 4 : 12,
          ),
        );
      });
    }

    testWidgets('la hoja muestra solo las dimensiones del servidor', (
      tester,
    ) async {
      serveFiltered();
      await pumpCatalog(tester, screen, bff);
      await openFilters(tester);
      expect(inSheet('Marca'), findsOneWidget);
      expect(inSheet('Capacidad BTU'), findsOneWidget);
      expect(inSheet('Solo ofertas'), findsWidgets);
      expect(inSheet('9.000'), findsOneWidget);
      expect(inSheet('12.000'), findsOneWidget);
      expect(inSheet('Elitech'), findsOneWidget);
      // Sin dimensiones inventadas.
      expect(inSheet('Precio'), findsNothing);
      expect(
        bff.to('/filters').single.queryParameters['category'],
        'minisplit',
      );
    });

    testWidgets(
      'AC-013-1/2/3/6 · marca + BTU: chips quitables, contador y consulta',
      (tester) async {
        serveFiltered();
        await pumpCatalog(tester, screen, bff);
        await openFilters(tester);
        await tester.tap(inSheet('Elitech'));
        await tester.tap(inSheet('12.000'));
        await settle(tester);
        await applyFilters(tester);

        expect(find.text('Marca: Elitech'), findsOneWidget);
        expect(find.text('Capacidad BTU: 12.000'), findsOneWidget);
        expect(find.text('Filtros (2)'), findsOneWidget);
        expect(find.text('4 resultados'), findsOneWidget);
        expect(find.text('Limpiar filtros'), findsOneWidget);
        final q = bff.to('/products').last.queryParameters;
        expect(q['brand'], 'elitech');
        expect(q['attr[pa_capacidad-btu]'], '12-000-btu');
        expect(q['category'], 'minisplit');
        expect(q['page'], 1);

        // Quitar un chip lo quita solo a él.
        await tester.tap(find.text('Marca: Elitech'));
        await settle(tester);
        expect(find.text('Marca: Elitech'), findsNothing);
        expect(find.text('Capacidad BTU: 12.000'), findsOneWidget);
        expect(
          bff.to('/products').last.queryParameters.containsKey('brand'),
          isFalse,
        );

        // "Limpiar filtros" restaura el listado.
        await tester.tap(find.text('Limpiar filtros'));
        await settle(tester);
        expect(find.text('Capacidad BTU: 12.000'), findsNothing);
        expect(find.text('12 resultados'), findsOneWidget);
        expect(find.text('Filtros'), findsOneWidget);
      },
    );

    testWidgets('AC-013-6 · la página siguiente respeta el filtro', (
      tester,
    ) async {
      servePages(pages: 2);
      await pumpCatalog(tester, screen, bff);
      await openFilters(tester);
      await tester.tap(inSheet('Elitech'));
      await applyFilters(tester);
      await scrollToEnd(tester);
      final withBrand = bff
          .to('/products')
          .where((r) => r.queryParameters['brand'] == 'elitech')
          .map((r) => r.queryParameters['page']);
      expect(withBrand, containsAll(<int>[1, 2]));
    });

    testWidgets(
      'AC-013-4 · combinación sin productos: mensaje y limpiar filtros',
      (tester) async {
        bff.on('/products', (o) {
          final empty = o.queryParameters.containsKey('brand');
          return FakeHttpAdapter.json(productPage(empty ? [] : products(5)));
        });
        await pumpCatalog(tester, screen, bff);
        await openFilters(tester);
        await tester.tap(inSheet('Refco'));
        await applyFilters(tester);
        expect(find.text('Sin resultados con estos filtros'), findsOneWidget);
        // El vacío no es un error.
        expect(find.text('Reintentar'), findsNothing);
        await tester.tap(find.widgetWithText(FilledButton, 'Limpiar filtros'));
        await settle(tester);
        expect(find.text('Sin resultados con estos filtros'), findsNothing);
        expect(find.text('Producto de prueba 1'), findsOneWidget);
      },
    );

    testWidgets(
      'AC-013-5 · si falla al filtrar se conserva el listado y se ofrece Reintentar',
      (tester) async {
        var fail = false;
        bff.on('/products', (o) {
          if (fail && o.queryParameters.containsKey('brand')) {
            return FakeHttpAdapter.problem(503, 'x');
          }
          return FakeHttpAdapter.json(productPage(products(5)));
        });
        await pumpCatalog(tester, screen, bff);
        await openFilters(tester);
        await tester.tap(inSheet('Elitech'));
        fail = true;
        await applyFilters(tester);

        // Listado y filtros previos intactos; error visible; no "sin resultados".
        expect(find.text('Producto de prueba 1'), findsOneWidget);
        expect(
          find.text('La tienda no está disponible en este momento.'),
          findsOneWidget,
        );
        expect(find.text('Marca: Elitech'), findsNothing);
        expect(find.text('Filtros'), findsOneWidget);
        expect(find.text('Sin resultados con estos filtros'), findsNothing);

        fail = false;
        await tester.tap(find.text('Reintentar'));
        await settle(tester);
        expect(find.text('Marca: Elitech'), findsOneWidget);
        expect(
          find.text('La tienda no está disponible en este momento.'),
          findsNothing,
        );
      },
    );

    testWidgets('cerrar la hoja sin aplicar descarta los cambios', (
      tester,
    ) async {
      serveFiltered();
      await pumpCatalog(tester, screen, bff);
      await openFilters(tester);
      await tester.tap(inSheet('Elitech'));
      await tester.tap(find.text('Cerrar'));
      await settle(tester);
      expect(find.text('Marca: Elitech'), findsNothing);
      expect(bff.to('/products'), hasLength(1));
      // Al reabrir, la casilla está sin marcar.
      await openFilters(tester);
      final checkbox = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'Elitech'),
      );
      expect(checkbox.value, isFalse);
    });

    testWidgets('"Limpiar" de la hoja desmarca todo antes de aplicar', (
      tester,
    ) async {
      serveFiltered();
      await pumpCatalog(tester, screen, bff);
      await openFilters(tester);
      await tester.tap(inSheet('Elitech'));
      await tester.tap(find.text('Limpiar'));
      await tester.pump();
      final checkbox = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, 'Elitech'),
      );
      expect(checkbox.value, isFalse);
    });

    testWidgets(
      'AC-013-2 · la categoría se filtra con las subcategorías del servidor',
      (tester) async {
        serveFiltered();
        await pumpCatalog(
          tester,
          const ProductListScreen(categorySlug: 'aire-acondicionado'),
          bff,
        );
        await openFilters(tester);
        expect(inSheet('Categoría'), findsOneWidget);
        expect(inSheet('Todas'), findsOneWidget);
        expect(inSheet('Minisplit'), findsOneWidget);
        expect(inSheet('Cassette'), findsOneWidget);
        await tester.tap(inSheet('Cassette'));
        await tester.tap(inSheet('Elitech'));
        await applyFilters(tester);
        final q = bff.to('/products').last.queryParameters;
        expect(q['category'], 'cassette');
        expect(q['brand'], 'elitech');
        expect(find.text('Categoría: Cassette'), findsOneWidget);
        await tester.tap(find.text('Categoría: Cassette'));
        await settle(tester);
        expect(
          bff.to('/products').last.queryParameters['category'],
          'aire-acondicionado',
        );
      },
    );

    testWidgets('AC-014-2 · sin atributos: no hay secciones vacías', (
      tester,
    ) async {
      bff.on('/filters', (_) => FakeHttpAdapter.json({'data': <Object?>[]}));
      servePages(pages: 1);
      await pumpCatalog(tester, screen, bff);
      await openFilters(tester);
      expect(
        find.text('No hay filtros disponibles para este listado.'),
        findsOneWidget,
      );
      expect(inSheet('Capacidad BTU'), findsNothing);
    });

    testWidgets('si los filtros no cargan, la hoja ofrece Reintentar', (
      tester,
    ) async {
      var ok = false;
      bff.on('/filters', (o) {
        if (!ok) return FakeHttpAdapter.problem(503, 'x');
        return FakeHttpAdapter.json(filtersBody());
      });
      servePages(pages: 1);
      await pumpCatalog(tester, screen, bff);
      await openFilters(tester);
      await settle(tester);
      expect(
        inSheet('La tienda no está disponible en este momento.'),
        findsOneWidget,
      );
      ok = true;
      await tester.tap(inSheet('Reintentar'));
      await settle(tester);
      expect(inSheet('Capacidad BTU'), findsOneWidget);
    });

    testWidgets(
      'con 5 marcas elegidas no deja añadir más (máximo del contrato)',
      (tester) async {
        bff.on(
          '/filters',
          (_) => FakeHttpAdapter.json({
            'data': [
              {
                'key': 'brand',
                'label': 'Marca',
                'type': 'multi',
                'options': [
                  for (var i = 1; i <= 6; i++)
                    {'value': 'm$i', 'label': 'Marca $i'},
                ],
              },
            ],
          }),
        );
        servePages(pages: 1);
        await pumpCatalog(tester, screen, bff, size: const Size(360, 1600));
        await openFilters(tester);
        for (var i = 1; i <= 5; i++) {
          await tester.tap(inSheet('Marca $i'));
          await tester.pump();
        }
        expect(inSheet('Puedes elegir hasta 5 opciones.'), findsOneWidget);
        final sixth = tester.widget<CheckboxListTile>(
          find.widgetWithText(CheckboxListTile, 'Marca 6'),
        );
        expect(sixth.value, isFalse);
        expect(sixth.onChanged, isNull);
      },
    );
  });

  group('TC-121 · AC-015 · orden', () {
    testWidgets(
      'el botón indica el orden vigente y ofrece los 5 del contrato',
      (tester) async {
        servePages(pages: 1);
        await pumpCatalog(tester, screen, bff);
        expect(find.text('Ordenar: Más recientes'), findsOneWidget);
        await tester.tap(find.text('Ordenar: Más recientes'));
        await settle(tester);
        for (final label in [
          'Más recientes',
          'Más populares',
          'Precio: menor a mayor',
          'Precio: mayor a menor',
          'Nombre (A a Z)',
        ]) {
          expect(inSheet(label), findsOneWidget);
        }
      },
    );

    testWidgets(
      'AC-015-2 · cambiar el orden recarga desde la página 1 y queda indicado',
      (tester) async {
        servePages();
        await pumpCatalog(tester, screen, bff);
        await scrollToEnd(tester);
        await tester.drag(
          find.byType(CustomScrollView),
          const Offset(0, 30000),
        );
        await settle(tester);
        await tester.tap(find.text('Ordenar: Más recientes'));
        await settle(tester);
        await tester.tap(inSheet('Precio: menor a mayor'));
        await settle(tester);
        expect(find.text('Ordenar: Precio: menor a mayor'), findsOneWidget);
        final last = bff.to('/products').last.queryParameters;
        expect(last['sort'], 'price-asc');
        expect(last['page'], 1);
      },
    );
  });

  group('RNF-068/070 · accesibilidad del listado', () {
    testWidgets('texto al 200 %: una columna, sin desbordar', (tester) async {
      servePages(pages: 1);
      await pumpCatalog(tester, screen, bff, textScale: 2);
      expect(cards(), findsWidgets);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Filtros'), findsOneWidget);
    });

    testWidgets('texto al 110 %: rejilla de dos columnas sin desbordar', (
      tester,
    ) async {
      servePages(pages: 1);
      await pumpCatalog(tester, screen, bff, textScale: 1.1);
      expect(cards(), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('texto al 140 %: una columna sin desbordar', (tester) async {
      servePages(pages: 1);
      await pumpCatalog(tester, screen, bff, textScale: 1.4);
      expect(cards(), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tableta: tres columnas sin desbordar', (tester) async {
      servePages(pages: 1);
      await pumpCatalog(tester, screen, bff, size: const Size(900, 1200));
      expect(cards(), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('texto al 200 % con el vacío del listado', (tester) async {
      bff.on('/products', (_) => FakeHttpAdapter.json(productPage([])));
      await pumpCatalog(
        tester,
        const ProductListScreen(categorySlug: 'aire-acondicionado'),
        bff,
        textScale: 2,
      );
      expect(
        find.text('¡Encuentra aquí los productos de Aire acondicionado!'),
        findsOneWidget,
      );
      expect(find.text('Minisplit'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'categoría vacía comercial cumple guías de objetivo táctil, etiquetas y contraste',
      (tester) async {
        bff.on('/products', (_) => FakeHttpAdapter.json(productPage([])));
        final handle = tester.ensureSemantics();
        await pumpCatalog(
          tester,
          const ProductListScreen(categorySlug: 'aire-acondicionado'),
          bff,
        );
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      },
    );

    testWidgets('guías de objetivo táctil, etiquetas y contraste', (
      tester,
    ) async {
      servePages(pages: 1);
      final handle = tester.ensureSemantics();
      await pumpCatalog(tester, screen, bff);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });

    testWidgets('el chip de filtro activo anuncia cómo quitarlo', (
      tester,
    ) async {
      servePages(pages: 1);
      final handle = tester.ensureSemantics();
      await pumpCatalog(tester, screen, bff);
      await openFilters(tester);
      await tester.tap(inSheet('Elitech'));
      await applyFilters(tester);
      expect(
        find.bySemanticsLabel('Quitar filtro Marca: Elitech'),
        findsOneWidget,
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });
}
