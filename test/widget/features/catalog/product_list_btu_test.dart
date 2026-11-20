import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/features/catalog/catalog.dart';

import '../../../fixtures/catalog/catalog_fixtures.dart';
import '../../../fixtures/catalog/fake_catalog_bff.dart';
import '../../../mocks/fake_http_adapter.dart';
import 'catalog_harness.dart';

void main() {
  group(
    'M5 · RF-089 · H1-04 · Listado con filtro inicial de capacidad BTU',
    () {
      testWidgets(
        'TC-128 · AC-089-1/2 · solicita /products?attr[pa_capacidad-btu]=12-000-btu y muestra chip removible',
        (tester) async {
          final bff = FakeCatalogBff()
            ..on('/products', (req) {
              final filtered = req.queryParameters['attr[pa_capacidad-btu]'];
              return FakeHttpAdapter.json(
                productPage(
                  filtered == '12-000-btu'
                      ? [product(1, name: 'Minisplit 12.000 BTU')]
                      : products(2),
                ),
              );
            });

          await pumpCatalog(
            tester,
            const ProductListScreen(btuSlug: '12-000-btu'),
            bff,
          );

          final firstReq = bff.to('/products').first;
          expect(
            firstReq.queryParameters['attr[pa_capacidad-btu]'],
            '12-000-btu',
          );
          expect(find.text('Minisplit 12.000 BTU'), findsOneWidget);
          expect(find.text('Capacidad BTU: 12.000 BTU'), findsOneWidget);

          // Quitar el filtro recarga sin attr[pa_capacidad-btu].
          await tester.tap(find.text('Capacidad BTU: 12.000 BTU'));
          await settle(tester);

          expect(bff.to('/products'), hasLength(2));
          expect(
            bff.to('/products').last.queryParameters['attr[pa_capacidad-btu]'],
            isNull,
          );
        },
      );

      testWidgets(
        'AC-089-3 · sin productos para la capacidad sugerida muestra estado vacío con WhatsApp',
        (tester) async {
          final bff = FakeCatalogBff()
            ..on('/products', (_) => FakeHttpAdapter.json(productPage([])));

          await pumpCatalog(
            tester,
            const ProductListScreen(btuSlug: '36-000-btu'),
            bff,
          );

          expect(find.text('Capacidad BTU: 36.000 BTU'), findsOneWidget);
          expect(find.text('Sin resultados con estos filtros'), findsOneWidget);
          expect(find.text('Limpiar filtros'), findsAtLeastNWidgets(1));
        },
      );
    },
  );
}
