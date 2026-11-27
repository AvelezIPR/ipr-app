import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/storage/cache_store.dart';
import 'package:ipr_mobile/features/catalog/catalog.dart';
import 'package:ipr_mobile/shared/widgets/state_widgets.dart';
import 'package:material_ui/material_ui.dart';

import '../../../fixtures/catalog/catalog_fixtures.dart';
import '../../../fixtures/catalog/fake_catalog_bff.dart';
import '../../../mocks/fake_http_adapter.dart';
import 'catalog_harness.dart';

/// Botón de chevron que despliega o contrae la rama de [slug].
Finder _toggle(String slug) => find.byKey(ValueKey('category-toggle-$slug'));

void main() {
  late FakeCatalogBff bff;

  setUp(() => bff = FakeCatalogBff());

  group('TC-117 · AC-010-1 · navegación jerárquica de categorías', () {
    testWidgets('lista las raíces en el orden del servidor y los accesos', (
      tester,
    ) async {
      await pumpCatalog(tester, const CatalogScreen(), bff);
      expect(find.text('Catálogo'), findsOneWidget);
      expect(find.text('Aire acondicionado'), findsOneWidget);
      expect(find.text('Herramientas'), findsOneWidget);
      expect(find.text('Marcas'), findsOneWidget);
      expect(find.text('Liquidaciones'), findsOneWidget);
      final aire = tester.getTopLeft(find.text('Aire acondicionado')).dy;
      final herr = tester.getTopLeft(find.text('Herramientas')).dy;
      expect(aire, lessThan(herr));
    });

    testWidgets(
      'el chevron despliega las subcategorías en el mismo lugar, sin cambiar de pantalla',
      (tester) async {
        await pumpCatalog(tester, const CatalogScreen(), bff);
        expect(find.text('Minisplit'), findsNothing);

        await tester.tap(_toggle('aire-acondicionado'));
        await settle(tester);
        // Mismo título y las demás raíces siguen a la vista.
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text('Catálogo'),
          ),
          findsOneWidget,
        );
        expect(find.text('Minisplit'), findsOneWidget);
        expect(find.text('Cassette'), findsOneWidget);
        expect(find.text('Herramientas'), findsOneWidget);
        // Los nietos esperan a que se despliegue su rama.
        expect(find.text('Cassette inverter'), findsNothing);

        await tester.tap(_toggle('cassette'));
        await settle(tester);
        expect(find.text('Cassette inverter'), findsOneWidget);
        expect(find.text('Minisplit'), findsOneWidget);

        // Contraer la raíz esconde toda su rama.
        await tester.tap(_toggle('aire-acondicionado'));
        await settle(tester);
        expect(find.text('Minisplit'), findsNothing);
        expect(find.text('Cassette inverter'), findsNothing);
        expect(find.text('Herramientas'), findsOneWidget);
      },
    );

    testWidgets('una hoja abre su listado de productos', (tester) async {
      final visited = <String>[];
      await pumpCatalog(tester, const CatalogScreen(), bff, visited: visited);
      await tester.tap(find.text('Herramientas'));
      await settle(tester);
      expect(visited, ['/catalog/list?category=herramientas']);
      expect(
        find.text('DESTINO /catalog/list?category=herramientas'),
        findsOneWidget,
      );
    });

    testWidgets(
      'el nombre de una categoría con hijos abre su listado; no la despliega',
      (tester) async {
        final visited = <String>[];
        await pumpCatalog(tester, const CatalogScreen(), bff, visited: visited);
        await tester.tap(find.text('Aire acondicionado'));
        await settle(tester);
        expect(visited, ['/catalog/list?category=aire-acondicionado']);
        await goBack(tester);
        expect(find.text('Minisplit'), findsNothing);
      },
    );

    testWidgets('lo desplegado se conserva al volver de un listado', (
      tester,
    ) async {
      final visited = <String>[];
      await pumpCatalog(tester, const CatalogScreen(), bff, visited: visited);
      await tester.tap(_toggle('aire-acondicionado'));
      await settle(tester);
      await tester.tap(find.text('Minisplit'));
      await settle(tester);
      expect(visited.last, '/catalog/list?category=minisplit');
      await goBack(tester);
      expect(find.text('Minisplit'), findsOneWidget);
      expect(find.text('Cassette'), findsOneWidget);
    });

    testWidgets('los accesos a Marcas, Liquidaciones y búsqueda navegan', (
      tester,
    ) async {
      final visited = <String>[];
      await pumpCatalog(tester, const CatalogScreen(), bff, visited: visited);
      await tester.tap(find.text('Marcas'));
      await settle(tester);
      await goBack(tester);
      await tester.tap(find.text('Liquidaciones'));
      await settle(tester);
      await goBack(tester);
      await tester.tap(find.byTooltip('Buscar productos'));
      await settle(tester);
      expect(visited, ['/catalog/brands', '/catalog/sale', '/search']);
    });

    testWidgets(
      'AC-010-4 · sin sesión: ninguna solicitud lleva Authorization',
      (tester) async {
        await pumpCatalog(tester, const CatalogScreen(), bff);
        expect(bff.requests, isNotEmpty);
        expect(
          bff.requests.every((r) => !r.headers.containsKey('Authorization')),
          isTrue,
        );
      },
    );
  });

  group('AC-009 · estados de la pestaña', () {
    testWidgets('cargando muestra el indicador accesible', (tester) async {
      final gate = Future<void>.delayed(const Duration(seconds: 5));
      bff.on('/categories', (_) async {
        await gate;
        return FakeHttpAdapter.json(categoriesBody());
      });
      await pumpCatalog(tester, const CatalogScreen(), bff);
      expect(find.byType(LoadingState), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets(
      'AC-009-1/3 · sin red: mensaje no técnico + Reintentar; reintenta sin reiniciar',
      (tester) async {
        var online = false;
        bff.on('/categories', (o) {
          if (!online) return FakeHttpAdapter.connectionError(o);
          return FakeHttpAdapter.json(categoriesBody());
        });
        await pumpCatalog(tester, const CatalogScreen(), bff);
        await settle(tester);
        expect(
          find.text('No tienes conexión. Revisa tu internet.'),
          findsOneWidget,
        );
        expect(find.text('Aire acondicionado'), findsNothing);
        // Nada de códigos HTTP ni nombres de servidor.
        expect(find.textContaining('503'), findsNothing);
        expect(find.textContaining('HTTP'), findsNothing);

        online = true;
        await tester.tap(find.text('Reintentar'));
        await settle(tester);
        expect(find.text('Aire acondicionado'), findsOneWidget);
        expect(find.text('Reintentar'), findsNothing);
      },
    );

    testWidgets('AC-009-2 · 503: la tienda no está disponible', (tester) async {
      bff.on(
        '/categories',
        (_) => FakeHttpAdapter.problem(503, 'service_unavailable'),
      );
      await pumpCatalog(tester, const CatalogScreen(), bff);
      await settle(tester);
      expect(
        find.text('La tienda no está disponible en este momento.'),
        findsOneWidget,
      );
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets('200 con lista vacía muestra el vacío real', (tester) async {
      bff.on('/categories', (_) => FakeHttpAdapter.json({'data': <Object?>[]}));
      await pumpCatalog(tester, const CatalogScreen(), bff);
      expect(find.text('Aún no hay categorías para mostrar.'), findsOneWidget);
      expect(find.text('Reintentar'), findsNothing);
    });

    testWidgets('datos guardados caducados con la red caída: árbol + aviso', (
      tester,
    ) async {
      var now = DateTime(2026, 11, 19, 10);
      final cache = MemoryCacheStore(now: () => now);
      await pumpCatalog(tester, const CatalogScreen(), bff, cache: cache);
      expect(find.text('Aire acondicionado'), findsOneWidget);
      expect(find.byType(StaleBanner), findsNothing);

      // Nueva apertura de la pestaña, 2 h después y sin red.
      now = now.add(const Duration(hours: 2));
      bff.on('/categories', FakeHttpAdapter.connectionError);
      await tester.pumpWidget(const SizedBox());
      await pumpCatalog(tester, const CatalogScreen(), bff, cache: cache);
      expect(find.text('Aire acondicionado'), findsOneWidget);
      expect(find.byType(StaleBanner), findsOneWidget);
      expect(find.textContaining('puede no estar actualizada'), findsOneWidget);
    });
  });

  group('RNF-068/070 · accesibilidad de la pestaña', () {
    testWidgets('texto al 200 % sin desbordar', (tester) async {
      await pumpCatalog(tester, const CatalogScreen(), bff, textScale: 2);
      expect(find.text('Aire acondicionado'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('guías de objetivo táctil, etiquetas y contraste', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpCatalog(tester, const CatalogScreen(), bff);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });

    testWidgets('una raíz con hijos anuncia que tiene subcategorías', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpCatalog(tester, const CatalogScreen(), bff);
      expect(
        find.bySemanticsLabel('Aire acondicionado. Subcategorías disponibles'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('el botón de desplegar anuncia su estado (abierto/cerrado)', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpCatalog(tester, const CatalogScreen(), bff);
      expect(
        tester.getSemantics(
          find.bySemanticsLabel('Desplegar Aire acondicionado'),
        ),
        matchesSemantics(
          label: 'Desplegar Aire acondicionado',
          isButton: true,
          hasTapAction: true,
          hasExpandedState: true,
        ),
      );
      await tester.tap(_toggle('aire-acondicionado'));
      await settle(tester);
      expect(
        tester.getSemantics(
          find.bySemanticsLabel('Contraer Aire acondicionado'),
        ),
        matchesSemantics(
          label: 'Contraer Aire acondicionado',
          isButton: true,
          hasTapAction: true,
          hasExpandedState: true,
          isExpanded: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('con las ramas desplegadas cumple las guías de accesibilidad', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpCatalog(tester, const CatalogScreen(), bff);
      await tester.tap(_toggle('aire-acondicionado'));
      await settle(tester);
      await tester.tap(_toggle('cassette'));
      await settle(tester);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  });
}
