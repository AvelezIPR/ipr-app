import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/features/home/domain/entities/home_category.dart';
import 'package:ipr_mobile/features/home/presentation/widgets/home_blocks.dart';
import 'package:ipr_mobile/shared/design_system/ipr_theme.dart';
import 'package:ipr_mobile/shared/design_system/tokens/effect_tokens.dart';
import 'package:ipr_mobile/shared/widgets/gradient_panel.dart';
import 'package:ipr_mobile/shared/widgets/ipr_card.dart';
import 'package:material_ui/material_ui.dart';

Widget _host(Widget child) => MaterialApp(
  theme: IprTheme.light(),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('IprGradientPanel', () {
    testWidgets('pinta el contenido sobre el degradado y la textura', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const IprGradientPanel(child: Text('Hola'))),
      );

      expect(find.text('Hola'), findsOneWidget);
      final decoration =
          tester
                  .widget<DecoratedBox>(
                    find
                        .descendant(
                          of: find.byType(IprGradientPanel),
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as BoxDecoration;
      expect(decoration.gradient, IprGradients.hero);
      expect(decoration.boxShadow, IprShadows.raised);
    });

    testWidgets('IprGlassIcon queda fuera de la accesibilidad', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(const IprGradientPanel(child: IprGlassIcon(icon: Icons.ac_unit))),
      );

      expect(find.byIcon(Icons.ac_unit), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('.')), findsNothing);
      handle.dispose();
    });
  });

  group('IprCard', () {
    testWidgets('sin onTap no es tocable; con onTap responde una vez', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(const IprCard(child: SizedBox(width: 80, height: 80))),
      );
      expect(find.byType(InkWell), findsNothing);

      await tester.pumpWidget(
        _host(
          IprCard(
            onTap: () => taps++,
            child: const SizedBox(width: 80, height: 80),
          ),
        ),
      );
      await tester.tap(find.byType(IprCard));
      expect(taps, 1);
    });
  });

  group('categoryIconFor', () {
    IconData iconOf(String slug, String name) =>
        categoryIconFor(HomeCategory(id: 1, slug: slug, name: name));

    test('reconoce las familias por nombre aunque lleven tildes', () {
      expect(iconOf('aire', 'Aire Acondicionado'), Icons.air);
      expect(iconOf('r', 'Refrigeración'), Icons.ac_unit);
      expect(iconOf('v', 'Ventilación'), Icons.wind_power);
      expect(iconOf('e', 'Eléctricos'), Icons.bolt);
      expect(
        iconOf('m', 'Materiales y Consumibles'),
        Icons.inventory_2_outlined,
      );
      expect(iconOf('h', 'Herramientas'), Icons.build_outlined);
      expect(
        iconOf('t', 'Tableros y Controles'),
        Icons.developer_board_outlined,
      );
    });

    test('una categoría desconocida usa el ícono genérico', () {
      expect(iconOf('x', 'Novedades'), Icons.category_outlined);
    });
  });
}
