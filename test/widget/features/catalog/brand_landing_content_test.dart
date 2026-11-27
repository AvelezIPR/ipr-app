import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/features/catalog/catalog.dart';
import 'package:ipr_mobile/shared/navigation/routes.dart';
import 'package:material_ui/material_ui.dart';

import '../../../fixtures/catalog/catalog_fixtures.dart';
import '../../../fixtures/catalog/fake_catalog_bff.dart';
import '../../../mocks/fake_http_adapter.dart';
import 'catalog_harness.dart';

const _slug = 'elitech';

Map<String, dynamic> _landing(List<Map<String, dynamic>> blocks) => {
  'data': {'slug': _slug, 'blocks': blocks},
};

final _blocks = <Map<String, dynamic>>[
  {
    'type': 'hero',
    'title': 'Elitech en IPR',
    'subtitle': 'Instrumentos de medición y diagnóstico.',
    'accentColor': '#0B2A3F',
    'ctaLabel': 'Hablar con ingeniería',
    'target': {'kind': 'engineering'},
  },
  {
    'type': 'text',
    'title': 'Sobre la marca',
    'body': 'Primer párrafo.\n\nSegundo párrafo.',
  },
  {
    'type': 'highlights',
    'title': 'Por qué Elitech',
    'items': [
      {'title': 'Precisión', 'body': 'Medición confiable en campo.'},
      {'title': 'Garantía', 'body': 'Respaldo directo de IPR.'},
    ],
  },
  {
    'type': 'faq',
    'title': 'Preguntas frecuentes',
    'items': [
      {'title': '¿Tiene garantía?', 'body': 'Sí, de fábrica.'},
      {'title': '¿Hacen envíos?', 'body': 'A todo el país.'},
    ],
  },
  {
    'type': 'cta',
    'title': 'Campaña',
    'body': 'Conoce la campaña de la marca.',
    'ctaLabel': 'Ver campaña',
    'target': {'kind': 'web', 'ref': 'https://iprpartesyrepuestos.com/elitech'},
  },
];

void main() {
  late FakeCatalogBff bff;

  setUp(() {
    bff = FakeCatalogBff()
      ..on(
        '/products',
        (_) => FakeHttpAdapter.json(productPage(products(3), total: 3)),
      );
  });

  void serveLanding([List<Map<String, dynamic>>? blocks]) => bff.on(
    '/brands/$_slug',
    (_) => FakeHttpAdapter.json(_landing(blocks ?? _blocks)),
  );

  Future<void> pump(
    WidgetTester tester, {
    List<String>? visited,
    double textScale = 1,
  }) async {
    await pumpCatalog(
      tester,
      const BrandLandingScreen(slug: _slug),
      bff,
      visited: visited,
      textScale: textScale,
      size: const Size(360, 3000),
    );
    await settle(tester);
  }

  group('W3-01 · landing de marca con contenido editorial', () {
    testWidgets('muestra los bloques arriba de los productos', (tester) async {
      serveLanding();
      await pump(tester);
      expect(find.text('Elitech en IPR'), findsOneWidget);
      expect(
        find.text('Instrumentos de medición y diagnóstico.'),
        findsOneWidget,
      );
      expect(find.text('Sobre la marca'), findsOneWidget);
      expect(find.text('Primer párrafo.'), findsOneWidget);
      expect(find.text('Segundo párrafo.'), findsOneWidget);
      expect(find.text('Por qué Elitech'), findsOneWidget);
      expect(find.text('Precisión'), findsOneWidget);
      expect(find.text('Preguntas frecuentes'), findsOneWidget);
      expect(find.text('¿Tiene garantía?'), findsOneWidget);
      // Los productos siguen debajo.
      expect(find.text('3 resultados'), findsOneWidget);
      final hero = tester.getTopLeft(find.text('Elitech en IPR')).dy;
      final results = tester.getTopLeft(find.text('3 resultados')).dy;
      expect(hero, lessThan(results));
    });

    testWidgets(
      'las preguntas son un acordeón: la respuesta aparece al abrir',
      (tester) async {
        serveLanding();
        await pump(tester);
        expect(find.text('Sí, de fábrica.'), findsNothing);
        await tester.tap(find.text('¿Tiene garantía?'));
        await tester.pumpAndSettle();
        expect(find.text('Sí, de fábrica.'), findsOneWidget);
        await tester.tap(find.text('¿Tiene garantía?'));
        await tester.pumpAndSettle();
        expect(find.text('Sí, de fábrica.'), findsNothing);
      },
    );

    testWidgets('el botón de la portada abre la pantalla de ingeniería', (
      tester,
    ) async {
      final visited = <String>[];
      serveLanding();
      await pump(tester, visited: visited);
      await tester.tap(find.text('Hablar con ingeniería'));
      await tester.pumpAndSettle();
      expect(visited, [Routes.engineering]);
    });

    testWidgets('sin contenido (404) se ven solo los productos', (
      tester,
    ) async {
      // /brands/elitech no está servido: el BFF falso responde 404.
      await pump(tester);
      expect(find.text('Elitech en IPR'), findsNothing);
      expect(find.text('Preguntas frecuentes'), findsNothing);
      expect(find.text('3 resultados'), findsOneWidget);
    });

    testWidgets('si falla la carga del contenido, los productos siguen', (
      tester,
    ) async {
      bff.on('/brands/$_slug', (_) => FakeHttpAdapter.problem(503, 'x'));
      await pump(tester);
      expect(find.text('Preguntas frecuentes'), findsNothing);
      expect(find.text('3 resultados'), findsOneWidget);
    });

    testWidgets('una respuesta ilegible no rompe la pantalla', (tester) async {
      bff.on('/brands/$_slug', (_) => FakeHttpAdapter.json({'data': 'roto'}));
      await pump(tester);
      expect(find.text('3 resultados'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('una landing sin bloques válidos no deja un hueco', (
      tester,
    ) async {
      serveLanding([
        {'type': 'nuevo-bloque'},
        {'type': 'text'},
      ]);
      await pump(tester);
      expect(find.text('3 resultados'), findsOneWidget);
    });

    testWidgets('un destino a la calculadora apagada oculta su bloque', (
      tester,
    ) async {
      serveLanding([
        {
          'type': 'cta',
          'title': 'Calcula tus BTU',
          'ctaLabel': 'Abrir calculadora',
          'target': {'kind': 'calculator'},
        },
        {'type': 'text', 'body': 'Texto visible.'},
      ]);
      await pump(tester);
      expect(find.text('Calcula tus BTU'), findsNothing);
      expect(find.text('Texto visible.'), findsOneWidget);
    });

    testWidgets('los títulos de los bloques se anuncian como encabezados', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      serveLanding();
      await pump(tester);
      for (final title in [
        'Elitech en IPR',
        'Sobre la marca',
        'Por qué Elitech',
        'Preguntas frecuentes',
        'Campaña',
      ]) {
        expect(
          tester.getSemantics(find.text(title)).flagsCollection.isHeader,
          isTrue,
          reason: title,
        );
      }
      handle.dispose();
    });

    testWidgets('guías de objetivo táctil, etiquetas y contraste', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      serveLanding();
      await pump(tester);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });

    testWidgets('texto al 200 % sin desbordar', (tester) async {
      serveLanding();
      await pump(tester, textScale: 2);
      expect(tester.takeException(), isNull);
    });
  });
}
