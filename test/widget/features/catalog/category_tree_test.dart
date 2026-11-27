import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/category_node.dart';
import 'package:ipr_mobile/features/catalog/presentation/widgets/category_tree.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/ipr_localizations.dart';
import 'package:ipr_mobile/shared/design_system/ipr_theme.dart';
import 'package:material_ui/material_ui.dart';

const _roots = [
  CategoryNode(
    id: 1,
    slug: 'aire',
    name: 'Aire',
    children: [
      CategoryNode(
        id: 11,
        slug: 'split',
        name: 'Split',
        children: [CategoryNode(id: 111, slug: 'inverter', name: 'Inverter')],
      ),
      CategoryNode(id: 12, slug: 'ducto', name: 'Ducto'),
    ],
  ),
  CategoryNode(
    id: 2,
    slug: 'refri',
    name: 'Refri',
    children: [CategoryNode(id: 21, slug: 'camaras', name: 'Cámaras')],
  ),
];

/// Dos ramas hermanas con hijos, para probar el acordeón en un nivel interno.
const _twinBranches = [
  CategoryNode(
    id: 1,
    slug: 'aire',
    name: 'Aire',
    children: [
      CategoryNode(
        id: 11,
        slug: 'split',
        name: 'Split',
        children: [CategoryNode(id: 111, slug: 'inverter', name: 'Inverter')],
      ),
      CategoryNode(
        id: 12,
        slug: 'ducto',
        name: 'Ducto',
        children: [CategoryNode(id: 121, slug: 'piso', name: 'Piso')],
      ),
    ],
  ),
];

Future<void> _pump(
  WidgetTester tester, {
  List<CategoryNode> roots = _roots,
  bool disableAnimations = false,
}) => tester.pumpWidget(
  MaterialApp(
    theme: IprTheme.light(),
    localizationsDelegates: iprLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(disableAnimations: disableAnimations),
      child: child!,
    ),
    home: Scaffold(
      body: SingleChildScrollView(child: CategoryTree(roots: roots)),
    ),
  ),
);

Finder _toggle(String slug) => find.byKey(ValueKey('category-toggle-$slug'));

void main() {
  group('CategoryTree · acordeón', () {
    testWidgets('abrir otra rama cierra la anterior (una sola abierta)', (
      tester,
    ) async {
      await _pump(tester);
      await tester.tap(_toggle('aire'));
      await tester.pumpAndSettle();
      expect(find.text('Split'), findsOneWidget);

      await tester.tap(_toggle('refri'));
      await tester.pumpAndSettle();
      expect(find.text('Cámaras'), findsOneWidget);
      expect(find.text('Split'), findsNothing);
      expect(find.text('Ducto'), findsNothing);
    });

    testWidgets('abrir un hermano en un nivel interno cierra al anterior', (
      tester,
    ) async {
      await _pump(tester, roots: _twinBranches);
      await tester.tap(_toggle('aire'));
      await tester.pumpAndSettle();
      await tester.tap(_toggle('split'));
      await tester.pumpAndSettle();
      expect(find.text('Inverter'), findsOneWidget);

      await tester.tap(_toggle('ducto'));
      await tester.pumpAndSettle();
      expect(find.text('Piso'), findsOneWidget);
      expect(find.text('Inverter'), findsNothing);
      // La raíz sigue abierta.
      expect(find.text('Split'), findsOneWidget);
    });

    testWidgets('una hoja no tiene botón de desplegar', (tester) async {
      await _pump(tester);
      await tester.tap(_toggle('aire'));
      await tester.pumpAndSettle();
      expect(_toggle('ducto'), findsNothing);
      expect(_toggle('split'), findsOneWidget);
    });

    testWidgets('con movimiento reducido el cambio es inmediato', (
      tester,
    ) async {
      await _pump(tester, disableAnimations: true);
      await tester.tap(_toggle('aire'));
      await tester.pump();
      expect(find.text('Split'), findsOneWidget);
    });

    testWidgets('texto al 200 % sin desbordar con ramas abiertas', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await _pump(tester);
      await tester.tap(_toggle('aire'));
      await tester.pumpAndSettle();
      await tester.tap(_toggle('split'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Inverter'), findsOneWidget);
    });
  });
}
