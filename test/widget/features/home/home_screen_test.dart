import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/home/data/mappers/home_mappers.dart';
import 'package:ipr_mobile/features/home/domain/entities/home_brand.dart';
import 'package:ipr_mobile/features/home/domain/entities/home_category.dart';
import 'package:ipr_mobile/features/home/domain/entities/section_data.dart';
import 'package:ipr_mobile/features/home/presentation/screens/home_screen.dart';
import 'package:ipr_mobile/features/home/presentation/widgets/home_blocks.dart';
import 'package:ipr_mobile/shared/domain/product_summary.dart';
import 'package:ipr_mobile/shared/widgets/product_card.dart';
import 'package:ipr_mobile/shared/widgets/state_widgets.dart';
import 'package:material_ui/material_ui.dart';

import '../../../mocks/test_providers.dart';
import '../../../unit/features/home/home_test_support.dart';
import 'home_harness.dart';

/// Las 8 categorías raíz del inventario (datos sintéticos de prueba).
const _names = [
  'Aire Acondicionado',
  'Refrigeración',
  'Eléctricos',
  'Materiales y Consumibles',
  'Herramientas',
  'Tableros y Controles',
  'Ventilación',
  'Refrigerantes',
];

final List<HomeCategory> _categories = [
  for (var i = 0; i < _names.length; i++)
    HomeCategory(id: i + 1, slug: 'cat-${i + 1}', name: _names[i]),
];

const _brands = [
  HomeBrand(slug: 'elitech', name: 'Elitech'),
  HomeBrand(slug: 'copeland', name: 'Copeland'),
];

List<ProductSummary> _products() => mapProducts([
  fixture('ProductSummary.priced.json'),
  fixture('ProductSummary.on-request.json'),
  fixture('ProductSummary.out-of-stock.json'),
]);

Result<SectionData<List<T>>> _ok<T>(List<T> items, {bool stale = false}) =>
    Ok(SectionData(items, stale: stale));

FakeHomeRepository _repo({
  Result<SectionData<List<HomeCategory>>>? categories,
  Result<SectionData<List<HomeBrand>>>? brands,
  Result<SectionData<List<ProductSummary>>>? featured,
}) => FakeHomeRepository(
  categoryResults: [categories ?? _ok(_categories)],
  brandResults: [brands ?? _ok(_brands)],
  featuredResults: [featured ?? _ok(_products())],
);

/// Alto de pantalla que construye todo el contenido (la lista es perezosa).
const _tall = Size(360, 4000);

Future<void> _scrollTo(WidgetTester tester, Finder finder) => tester
    .scrollUntilVisible(finder, 300, scrollable: find.byType(Scrollable).first);

void main() {
  group('TC-115 · AC-001-1 · AC-005-1 · buscador y WhatsApp sin desplazar', () {
    testWidgets('visibles y etiquetados con los datos cargados', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpHome(tester, repository: _repo());

      final search = find.bySemanticsLabel(
        'Buscar productos por nombre, marca o referencia',
      );
      expect(search, findsOneWidget);
      expect(
        find.text('Buscar por nombre, marca o referencia (SKU)'),
        findsOneWidget,
      );
      expect(find.text('Asesoría por WhatsApp'), findsOneWidget);

      final viewport = tester.view.physicalSize.height;
      expect(tester.getRect(search).bottom, lessThan(viewport));
      expect(
        tester.getRect(find.text('Asesoría por WhatsApp')).bottom,
        lessThan(viewport),
      );
      expect(
        tester.getSemantics(search),
        matchesSemantics(
          label: 'Buscar productos por nombre, marca o referencia',
          isButton: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets(
      'también visibles mientras las secciones cargan (no dependen de red)',
      (tester) async {
        final gate = Completer<Result<SectionData<List<HomeCategory>>>>();
        final repo = _GatedHomeRepo(gate);
        await pumpHome(tester, repository: repo);
        expect(find.text('Cargando Categorías'), findsNothing); // es semántica
        expect(find.text('Asesoría por WhatsApp'), findsOneWidget);
        expect(
          find.text('Buscar por nombre, marca o referencia (SKU)'),
          findsOneWidget,
        );
        gate.complete(_ok(_categories));
        await settle(tester);
      },
    );
  });

  group('M1 · RF-001 · AC-001-2/003 · el buscador abre la búsqueda', () {
    testWidgets('al tocarlo navega a /search sin pedir sesión', (tester) async {
      await pumpHome(tester, repository: _repo());
      await tester.tap(
        find.text('Buscar por nombre, marca o referencia (SKU)'),
      );
      await tester.pumpAndSettle();
      final uri = Uri.parse(destinationOf(tester));
      expect(uri.path, '/search');
      // Sin texto aún: la pantalla de búsqueda abre con el campo vacío.
      expect(uri.queryParameters['q'] ?? '', isEmpty);
    });
  });

  group('TC-115 · AC-002-1/2 · categorías raíz', () {
    testWidgets('un acceso por cada categoría devuelta', (tester) async {
      await pumpHome(tester, repository: _repo(), size: _tall);
      for (final name in _names) {
        expect(find.text(name), findsOneWidget);
      }
      expect(find.byType(CategoryTile), findsNWidgets(8));
    });

    testWidgets('si el servidor devuelve 3, se muestran 3', (tester) async {
      await pumpHome(
        tester,
        repository: _repo(categories: _ok(_categories.take(3).toList())),
        size: _tall,
      );
      expect(find.byType(CategoryTile), findsNWidgets(3));
    });

    testWidgets('tocar una categoría abre su listado', (tester) async {
      await pumpHome(tester, repository: _repo(), size: _tall);
      await tester.tap(find.text('Refrigeración'));
      await tester.pumpAndSettle();
      expect(destinationOf(tester), '/catalog/list?category=cat-2');
    });

    testWidgets(
      'CTAs "Ver todo el catálogo" en Categorías y Más vendidos navegan a /catalog',
      (tester) async {
        await pumpHome(tester, repository: _repo(), size: _tall);
        expect(find.text('Ver todo el catálogo'), findsNWidgets(2));

        await tester.tap(find.text('Ver todo el catálogo').first);
        await tester.pumpAndSettle();
        expect(destinationOf(tester), '/catalog');

        await pumpHome(tester, repository: _repo(), size: _tall);
        await tester.tap(find.text('Ver todo el catálogo').last);
        await tester.pumpAndSettle();
        expect(destinationOf(tester), '/catalog');
      },
    );

    testWidgets(
      'sin datos en Categorías ni Más vendidos no muestra CTAs de catálogo',
      (tester) async {
        await pumpHome(
          tester,
          repository: _repo(
            categories: _ok(<HomeCategory>[]),
            featured: _ok(<ProductSummary>[]),
          ),
          size: _tall,
        );
        expect(find.text('Ver todo el catálogo'), findsNothing);
      },
    );

    testWidgets('AC-002-3 · 200 vacío: mensaje, no cuadrícula vacía', (
      tester,
    ) async {
      await pumpHome(
        tester,
        repository: _repo(categories: _ok(<HomeCategory>[])),
        size: _tall,
      );
      expect(find.text('Aún no hay categorías para mostrar'), findsOneWidget);
      expect(find.byType(CategoryTile), findsNothing);
    });

    testWidgets('AC-002-3/AC-009-1 · falla: mensaje no técnico y Reintentar', (
      tester,
    ) async {
      final repo = FakeHomeRepository(
        categoryResults: [const Err(NoConnection()), _ok(_categories)],
        brandResults: [_ok(_brands)],
        featuredResults: [_ok(_products())],
      );
      await pumpHome(tester, repository: repo, size: _tall);
      expect(
        find.text('No tienes conexión. Revisa tu internet.'),
        findsOneWidget,
      );
      expect(find.byType(CategoryTile), findsNothing);
      expect(find.text('Reintentar'), findsOneWidget);
      // AC-009-7: un error no se presenta como "sin resultados".
      expect(find.text('Aún no hay categorías para mostrar'), findsNothing);

      // AC-009-3: al volver la red, "Reintentar" carga sin reiniciar.
      await tester.tap(find.text('Reintentar'));
      await settle(tester);
      expect(find.text('Reintentar'), findsNothing);
      expect(find.byType(CategoryTile), findsNWidgets(8));
      expect(repo.categoryCalls, [false, true]);
    });
  });

  group('TC-142 · AC-003-1..5 · más vendidos', () {
    testWidgets('tarjetas con nombre, SKU, stock y precio o Más información', (
      tester,
    ) async {
      await pumpHome(tester, repository: _repo(), size: _tall);
      expect(find.text('Más vendidos'), findsOneWidget);
      expect(find.byType(ProductCard), findsNWidgets(3));
      expect(find.text('Detector de fugas CO2 R744 Elitech'), findsOneWidget);
      expect(find.text('SKU 500-0144'), findsOneWidget);
      expect(find.text(r'$ 1.445.000'), findsOneWidget);
      expect(find.text('En stock'), findsWidgets);
    });

    testWidgets('AC-003-2 · sin precio: "Más información", nunca cero pesos', (
      tester,
    ) async {
      await pumpHome(tester, repository: _repo(), size: _tall);
      expect(find.text('Más información'), findsOneWidget);
      expect(find.textContaining(r'$ 0'), findsNothing);
      expect(find.textContaining(r'$0'), findsNothing);
    });

    testWidgets('AC-003-3 · agotado: "Agotado" y sin acción de compra', (
      tester,
    ) async {
      await pumpHome(tester, repository: _repo(), size: _tall);
      expect(find.text('Agotado'), findsOneWidget);
      expect(find.textContaining('carrito'), findsNothing);
      expect(find.textContaining('Añadir'), findsNothing);
    });

    testWidgets('AC-003-5 · tocar una tarjeta abre la ficha', (tester) async {
      await pumpHome(tester, repository: _repo(), size: _tall);
      await tester.tap(find.text('Detector de fugas CO2 R744 Elitech'));
      await tester.pumpAndSettle();
      expect(destinationOf(tester), '/product/detector-fugas-co2-r744');
    });

    testWidgets('solo pinta hasta 8 tarjetas aunque el servidor mande más', (
      tester,
    ) async {
      final many = mapProducts([
        for (var i = 1; i <= 12; i++)
          {...fixture('ProductSummary.priced.json'), 'id': i, 'slug': 'p-$i'},
      ]);
      await pumpHome(
        tester,
        repository: _repo(featured: _ok(many)),
        size: _tall,
      );
      expect(find.byType(ProductCard), findsNWidgets(homeFeaturedShown));
    });

    testWidgets('200 vacío: el bloque opcional se oculta', (tester) async {
      await pumpHome(
        tester,
        repository: _repo(featured: _ok(<ProductSummary>[])),
        size: _tall,
      );
      expect(find.text('Más vendidos'), findsNothing);
      expect(find.byType(ProductCard), findsNothing);
    });

    testWidgets(
      'AC-003-4 · si solo falla este bloque, el resto sigue operativo',
      (tester) async {
        final repo = FakeHomeRepository(
          categoryResults: [_ok(_categories)],
          brandResults: [_ok(_brands)],
          featuredResults: [const Err(ServiceUnavailable()), _ok(_products())],
        );
        final launcher = FakeExternalLauncher();
        await pumpHome(
          tester,
          repository: repo,
          launcher: launcher,
          size: _tall,
        );
        // Bloque con error + Reintentar; ocho categorías intactas.
        expect(
          find.text('La tienda no está disponible en este momento.'),
          findsOneWidget,
        );
        expect(find.text('Reintentar'), findsOneWidget);
        expect(find.byType(CategoryTile), findsNWidgets(8));
        expect(find.text('Copeland'), findsOneWidget);
        // WhatsApp sigue operativo.
        await tester.tap(find.text('Asesoría por WhatsApp'));
        await tester.pump();
        expect(launcher.opened.single.host, 'wa.me');
        // Reintentar solo ese bloque.
        await tester.tap(find.text('Reintentar'));
        await settle(tester);
        expect(find.byType(ProductCard), findsNWidgets(3));
        expect(repo.categoryCalls, [false]);
        expect(repo.featuredCalls, [false, true]);
      },
    );

    testWidgets('TC-104 · 404 y 503 se distinguen en pantalla', (tester) async {
      await pumpHome(
        tester,
        repository: _repo(
          categories: const Err(NotFound()),
          featured: const Err(ServiceUnavailable()),
        ),
        size: _tall,
      );
      expect(
        find.text('Este contenido ya no está disponible.'),
        findsOneWidget,
      );
      expect(
        find.text('La tienda no está disponible en este momento.'),
        findsOneWidget,
      );
      // 404 no es reintentable: solo el 503 ofrece Reintentar.
      expect(find.text('Reintentar'), findsOneWidget);
    });
  });

  group('TC-115 · AC-004 · marcas', () {
    testWidgets('AC-004-1/2 · el acceso al directorio funciona sin sesión', (
      tester,
    ) async {
      await pumpHome(tester, repository: _repo(), size: _tall);
      await tester.tap(find.text('Ver todas las marcas'));
      await tester.pumpAndSettle();
      expect(destinationOf(tester), '/catalog/brands');
    });

    testWidgets('el acceso al directorio sigue aunque las marcas fallen', (
      tester,
    ) async {
      await pumpHome(
        tester,
        repository: _repo(brands: const Err(RequestTimeout())),
        size: _tall,
      );
      expect(find.text('Ver todas las marcas'), findsOneWidget);
      await tester.tap(find.text('Ver todas las marcas'));
      await tester.pumpAndSettle();
      expect(destinationOf(tester), '/catalog/brands');
    });

    testWidgets('tocar una marca abre su página', (tester) async {
      await pumpHome(tester, repository: _repo(), size: _tall);
      await tester.tap(find.text('Copeland'));
      await tester.pumpAndSettle();
      expect(destinationOf(tester), '/catalog/brands/copeland');
    });

    testWidgets('sin marcas con página propia, el bloque se oculta', (
      tester,
    ) async {
      await pumpHome(
        tester,
        repository: _repo(brands: _ok(<HomeBrand>[])),
        size: _tall,
      );
      expect(find.text('Marcas'), findsNothing);
      expect(find.text('Copeland'), findsNothing);
    });
  });

  group('TC-142 · AC-007 · Liquidaciones y sedes', () {
    testWidgets('AC-007-1/2 · Liquidaciones abre el listado sin sesión', (
      tester,
    ) async {
      await pumpHome(tester, repository: _repo(), size: _tall);
      await tester.tap(find.text('Liquidaciones'));
      await tester.pumpAndSettle();
      expect(destinationOf(tester), '/catalog/sale');
    });

    testWidgets('Sedes abre /branches', (tester) async {
      await pumpHome(tester, repository: _repo(), size: _tall);
      await tester.tap(find.text('Sedes'));
      await tester.pumpAndSettle();
      expect(destinationOf(tester), '/branches');
    });
  });

  group('TC-115 · AC-005 · AC-064 · WhatsApp (asesoría y cotización)', () {
    testWidgets('AC-005-2/4 · asesoría abre wa.me con mensaje no vacío', (
      tester,
    ) async {
      final launcher = FakeExternalLauncher();
      await pumpHome(
        tester,
        repository: _repo(),
        launcher: launcher,
        extra: [phoneOverride()],
      );
      await tester.tap(find.text('Asesoría por WhatsApp'));
      await tester.pump();
      final uri = launcher.opened.single;
      expect(uri.host, 'wa.me');
      expect(uri.path, '/573014021882');
      expect(
        uri.queryParameters['text'],
        'Hola, necesito asesoría de IPR Partes y Repuestos.',
      );
    });

    testWidgets(
      'AC-064-1/2/4 · "Cotizar por WhatsApp" con mensaje de cotización',
      (tester) async {
        final launcher = FakeExternalLauncher();
        await pumpHome(
          tester,
          repository: _repo(),
          launcher: launcher,
          size: _tall,
        );
        expect(
          find.text('¿Necesitas cotizar un proyecto o un volumen?'),
          findsOneWidget,
        );
        await tester.tap(find.text('Cotizar por WhatsApp'));
        await tester.pump();
        final uri = launcher.opened.single;
        expect(uri.host, 'wa.me');
        expect(
          uri.queryParameters['text'],
          'Hola, quiero cotizar un proyecto o un volumen de compra.',
        );
      },
    );

    testWidgets(
      'AC-005-3 · sin WhatsApp ofrece llamar o abrir la versión web',
      (tester) async {
        final launcher = FakeExternalLauncher(results: [false, true]);
        await pumpHome(
          tester,
          repository: _repo(),
          launcher: launcher,
          extra: [phoneOverride()],
        );
        await tester.tap(find.text('Asesoría por WhatsApp'));
        await tester.pumpAndSettle();
        expect(find.text('No pudimos abrir WhatsApp'), findsOneWidget);
        expect(find.text('Llamar a la línea de atención'), findsWidgets);
      },
    );
  });

  group('M1 · llamada a la línea de atención', () {
    testWidgets('con teléfono en /config: abre tel: sin marcar solo', (
      tester,
    ) async {
      final launcher = FakeExternalLauncher();
      await pumpHome(
        tester,
        repository: _repo(),
        launcher: launcher,
        size: _tall,
        extra: [phoneOverride()],
      );
      expect(find.text('(604) 360 4440'), findsOneWidget);
      await tester.tap(find.text('Llamar a la línea de atención'));
      await tester.pump();
      expect(launcher.opened.single.scheme, 'tel');
      expect(launcher.opened.single.path, '+576043604440');
    });

    testWidgets('si el sistema no puede llamar, avisa con claridad', (
      tester,
    ) async {
      final launcher = FakeExternalLauncher(result: false);
      await pumpHome(
        tester,
        repository: _repo(),
        launcher: launcher,
        size: _tall,
        extra: [phoneOverride()],
      );
      await tester.tap(find.text('Llamar a la línea de atención'));
      await tester.pumpAndSettle();
      expect(
        find.text('No pudimos abrir el marcador del teléfono.'),
        findsOneWidget,
      );
    });

    testWidgets('sin teléfono en /config no se ofrece la llamada', (
      tester,
    ) async {
      await pumpHome(tester, repository: _repo(), size: _tall);
      expect(find.text('Llamar a la línea de atención'), findsNothing);
    });
  });

  group('M1 · RNF-022 · carga, obsoleto y sin red', () {
    testWidgets('esqueleto accesible por sección mientras carga', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final gate = Completer<Result<SectionData<List<HomeCategory>>>>();
      await pumpHome(tester, repository: _GatedHomeRepo(gate), size: _tall);
      expect(find.bySemanticsLabel('Cargando Categorías'), findsOneWidget);
      expect(find.byType(CategoryTile), findsNothing);
      gate.complete(_ok(_categories));
      await settle(tester);
      expect(find.bySemanticsLabel('Cargando Categorías'), findsNothing);
      expect(find.byType(CategoryTile), findsNWidgets(8));
      handle.dispose();
    });

    testWidgets('datos guardados: aviso de información obsoleta', (
      tester,
    ) async {
      await pumpHome(
        tester,
        repository: _repo(categories: _ok(_categories, stale: true)),
        size: _tall,
      );
      expect(find.byType(StaleBanner), findsOneWidget);
      expect(find.byType(CategoryTile), findsNWidgets(8));
    });

    testWidgets('datos al día: sin aviso', (tester) async {
      await pumpHome(tester, repository: _repo(), size: _tall);
      expect(find.byType(StaleBanner), findsNothing);
    });

    testWidgets('AC-009-1/2 · sin red y sin caché: tres bloques con '
        'Reintentar y el buscador sigue', (tester) async {
      await pumpHome(
        tester,
        repository: _repo(
          categories: const Err(NoConnection()),
          brands: const Err(NoConnection()),
          featured: const Err(NoConnection()),
        ),
        size: _tall,
      );
      expect(find.text('Reintentar'), findsNWidgets(3));
      expect(
        find.text('Buscar por nombre, marca o referencia (SKU)'),
        findsOneWidget,
      );
      expect(find.text('Asesoría por WhatsApp'), findsOneWidget);
    });

    testWidgets(
      'pull-to-refresh recarga las tres secciones saltando la caché',
      (tester) async {
        final repo = _repo();
        await pumpHome(tester, repository: repo);
        expect(repo.categoryCalls, [false]);
        await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
        await tester.pumpAndSettle();
        expect(repo.categoryCalls, [false, true]);
        expect(repo.brandCalls, [false, true]);
        expect(repo.featuredCalls, [false, true]);
      },
    );
  });

  group('M1 · RNF-068/070 · accesibilidad', () {
    testWidgets('texto al 200 % sin desbordar con todo el contenido', (
      tester,
    ) async {
      await pumpHome(
        tester,
        repository: _repo(),
        textScale: 2,
        size: const Size(360, 9000),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(ProductCard), findsNWidgets(3));
      expect(find.byType(CategoryTile), findsNWidgets(8));
    });

    testWidgets('texto al 200 % en pantalla normal: se puede llegar al final', (
      tester,
    ) async {
      await pumpHome(tester, repository: _repo(), textScale: 2);
      await _scrollTo(tester, find.text('Sedes'));
      expect(tester.takeException(), isNull);
      expect(find.text('Sedes'), findsOneWidget);
    });

    testWidgets('texto al 200 % con errores en las secciones', (tester) async {
      await pumpHome(
        tester,
        repository: _repo(
          categories: const Err(NoConnection()),
          brands: const Err(NoConnection()),
          featured: const Err(NoConnection()),
        ),
        textScale: 2,
        size: const Size(360, 9000),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('guías de objetivo táctil, etiquetas y contraste', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpHome(
        tester,
        repository: _repo(),
        size: _tall,
        extra: [phoneOverride()],
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });

    testWidgets('las secciones se anuncian como encabezados', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpHome(tester, repository: _repo(), size: _tall);
      for (final title in ['Categorías', 'Más vendidos', 'Marcas']) {
        final node = tester.getSemantics(find.text(title));
        expect(node.flagsCollection.isHeader, isTrue, reason: title);
      }
      handle.dispose();
    });
  });
}

/// Repositorio cuya carga de categorías espera a una compuerta.
final class _GatedHomeRepo extends FakeHomeRepository {
  new(this.gate)
    : super(brandResults: [_ok(_brands)], featuredResults: [_ok(_products())]);

  final Completer<Result<SectionData<List<HomeCategory>>>> gate;

  @override
  Future<Result<SectionData<List<HomeCategory>>>> categories({
    bool forceRefresh = false,
  }) => gate.future;
}
