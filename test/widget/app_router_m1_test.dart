import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/app/router/app_router.dart';
import 'package:ipr_mobile/features/catalog/catalog.dart';
import 'package:ipr_mobile/features/home/home.dart';
import 'package:ipr_mobile/features/product_detail/product_detail.dart';
import 'package:ipr_mobile/features/search/search.dart';
import 'package:ipr_mobile/shared/navigation/routes.dart';

import 'app_router_test.dart' show pumpIprApp;

void main() {
  group('M1 · cableado de rutas de las features', () {
    final cases = <String, Type>{
      Routes.home: HomeScreen,
      Routes.catalog: CatalogScreen,
      Routes.categoryList('compresores'): ProductListScreen,
      Routes.brands: BrandsScreen,
      Routes.brand('elitech'): BrandLandingScreen,
      Routes.sale: SaleScreen,
      Routes.searchFor('compresor'): SearchScreen,
      Routes.product('detector-co2'): ProductDetailScreen,
    };
    for (final entry in cases.entries) {
      testWidgets('${entry.key} abre ${entry.value}', (tester) async {
        final c = await pumpIprApp(tester);
        c.read(appRouterProvider).go(entry.key);
        await tester.pumpAndSettle();
        expect(find.byType(entry.value), findsOneWidget);
      });
    }

    testWidgets('la categoría y la consulta llegan a su pantalla', (
      tester,
    ) async {
      final c = await pumpIprApp(tester);
      c.read(appRouterProvider).go(Routes.categoryList('compresores'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ProductListScreen>(find.byType(ProductListScreen))
            .categorySlug,
        'compresores',
      );
      c.read(appRouterProvider).go(Routes.product('detector-co2'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ProductDetailScreen>(find.byType(ProductDetailScreen))
            .slug,
        'detector-co2',
      );
    });
  });
}
