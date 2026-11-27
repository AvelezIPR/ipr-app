import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/config/home_content.dart';
import 'package:ipr_mobile/core/config/remote_config.dart';
import 'package:ipr_mobile/core/config/remote_config_controller.dart';
import 'package:ipr_mobile/core/config/remote_config_repository.dart'
    show RemoteConfigSource;
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/home/domain/entities/home_city.dart';
import 'package:ipr_mobile/features/home/domain/entities/section_data.dart';
import 'package:material_ui/material_ui.dart';

import '../../../mocks/test_providers.dart';
import '../../../unit/features/home/home_test_support.dart';
import 'home_harness.dart';

const _tall = Size(360, 4000);

const _web = 'https://iprpartesyrepuestos.com/jugada-samsung';

const _banners = [
  HomeBanner(
    id: 'jugada-samsung',
    alt: 'Jugada Navideña Samsung X IPR: gana premios este diciembre',
    imageUrl: 'https://iprpartesyrepuestos.com/slider-main/a.webp',
    target: HomeTarget(HomeTargetKind.web, _web),
  ),
  HomeBanner(
    id: 'fiberglass',
    alt: 'Fiberglass Isover: gana una bicicleta eléctrica',
    imageUrl: 'https://iprpartesyrepuestos.com/slider-main/b.webp',
    target: HomeTarget(HomeTargetKind.brand, 'fiberglass'),
  ),
  HomeBanner(
    id: 'addi',
    alt: 'Compra ahora y paga después con Addi',
    imageUrl: 'https://iprpartesyrepuestos.com/slider-main/c.webp',
    target: HomeTarget(
      HomeTargetKind.whatsapp,
      'Hola IPR, quiero pagar con Addi',
    ),
  ),
];

const _stats = [
  HomeStat(
    id: 'years',
    value: '+30',
    unit: 'años',
    label: 'Importando y distribuyendo',
  ),
  HomeStat(id: 'branches', value: '31', label: 'Sedes atendiendo el mercado'),
  HomeStat(id: 'references', value: '+10.000', label: 'Referencias HVAC-R'),
  HomeStat(
    id: 'leader',
    value: 'Líder del sector HVAC-R*',
    label: 'Comparado con el sector',
  ),
];

const _highlights = [
  HomeHighlight(
    id: 'engineering',
    eyebrow: 'Ingeniería IPR',
    title: 'Ingeniería para tu proyecto',
    body: 'Dimensionamos cargas térmicas y seleccionamos equipos.',
    cta: 'Conocer ingeniería',
    target: HomeTarget(HomeTargetKind.engineering),
  ),
  HomeHighlight(
    id: 'training',
    eyebrow: 'Formación técnica',
    title: 'Capacitaciones con las marcas líderes',
    body: 'Jornadas técnicas con Samsung, Danfoss y Gree.',
    cta: 'Ver capacitaciones',
    target: HomeTarget(
      HomeTargetKind.web,
      'https://iprpartesyrepuestos.com/capacitaciones',
    ),
  ),
];

Override _config(HomeContent home, {bool btu = false}) =>
    remoteConfigProvider.overrideWithBuild(
      (ref, notifier) => RemoteConfigState(
        config: RemoteConfig(
          whatsappNumber: '573014021882',
          btuCalculatorEnabled: btu,
          home: home,
        ),
        source: RemoteConfigSource.network,
      ),
    );

FakeHomeRepository _repo() => FakeHomeRepository(
  categoryResults: const [Ok(SectionData([]))],
  brandResults: const [Ok(SectionData([]))],
  featuredResults: const [Ok(SectionData([]))],
  cityResults: const [
    Ok(
      SectionData([
        HomeCity(name: 'Medellín', branchCount: 9, upcoming: false),
        HomeCity(name: 'Cali', branchCount: 5, upcoming: false),
      ]),
    ),
  ],
);

Future<void> _pump(
  WidgetTester tester,
  HomeContent home, {
  bool btu = false,
  FakeExternalLauncher? launcher,
  double textScale = 1,
  Size size = _tall,
}) => pumpHome(
  tester,
  repository: _repo(),
  launcher: launcher,
  textScale: textScale,
  size: size,
  extra: [_config(home, btu: btu)],
);

void main() {
  group('W2-01 · carrusel de campañas', () {
    testWidgets('muestra la primera campaña con su texto alternativo', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, const HomeContent(banners: _banners));
      expect(find.bySemanticsLabel('Campañas de IPR'), findsOneWidget);
      expect(find.bySemanticsLabel(_banners.first.alt), findsOneWidget);
      expect(find.bySemanticsLabel('Campaña 1 de 3'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('sin campañas no hay carrusel', (tester) async {
      await _pump(tester, HomeContent.empty);
      expect(find.byTooltip('Campaña siguiente'), findsNothing);
      expect(find.byTooltip('Campaña anterior'), findsNothing);
    });

    testWidgets('con una sola campaña no hay botones ni indicador', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, HomeContent(banners: [_banners.first]));
      expect(find.byTooltip('Campaña siguiente'), findsNothing);
      expect(find.bySemanticsLabel('Campaña 1 de 1'), findsNothing);
      expect(find.bySemanticsLabel(_banners.first.alt), findsOneWidget);
      handle.dispose();
    });

    testWidgets('los botones cambian de campaña y la posición se anuncia', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, const HomeContent(banners: _banners));

      await tester.tap(find.byTooltip('Campaña siguiente'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Campaña 2 de 3'), findsOneWidget);
      expect(find.bySemanticsLabel(_banners[1].alt), findsOneWidget);

      await tester.tap(find.byTooltip('Campaña anterior'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Campaña 1 de 3'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('da la vuelta: anterior desde la primera va a la última', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, const HomeContent(banners: _banners));
      await tester.tap(find.byTooltip('Campaña anterior'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Campaña 3 de 3'), findsOneWidget);
      await tester.tap(find.byTooltip('Campaña siguiente'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Campaña 1 de 3'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('no avanza sola (WCAG 2.2.2)', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, const HomeContent(banners: _banners));
      await tester.pump(const Duration(seconds: 30));
      expect(find.bySemanticsLabel('Campaña 1 de 3'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('también se cambia deslizando', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, const HomeContent(banners: _banners));
      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Campaña 2 de 3'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('una campaña de marca abre la página de la marca', (
      tester,
    ) async {
      await _pump(tester, const HomeContent(banners: _banners));
      await tester.tap(find.byTooltip('Campaña siguiente'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PageView));
      await tester.pumpAndSettle();
      expect(destinationOf(tester), '/catalog/brands/fiberglass');
    });

    testWidgets('una campaña web se abre en el navegador del sistema', (
      tester,
    ) async {
      final launcher = FakeExternalLauncher();
      await _pump(
        tester,
        const HomeContent(banners: _banners),
        launcher: launcher,
      );
      await tester.tap(find.byType(PageView));
      await tester.pump();
      expect(launcher.opened.single.toString(), _web);
    });

    testWidgets('si el enlace web no se puede abrir, lo dice', (tester) async {
      final launcher = FakeExternalLauncher(result: false);
      await _pump(
        tester,
        const HomeContent(banners: _banners),
        launcher: launcher,
      );
      await tester.tap(find.byType(PageView));
      await tester.pump();
      await tester.pump();
      expect(find.text('No pudimos abrir el enlace.'), findsOneWidget);
    });

    testWidgets('una campaña de WhatsApp abre al asesor con su mensaje', (
      tester,
    ) async {
      final launcher = FakeExternalLauncher();
      await _pump(
        tester,
        const HomeContent(banners: _banners),
        launcher: launcher,
      );
      await tester.tap(find.byTooltip('Campaña anterior'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PageView));
      await tester.pump();
      final uri = launcher.opened.single;
      expect(uri.host, 'wa.me');
      expect(uri.queryParameters['text'], 'Hola IPR, quiero pagar con Addi');
    });

    const btuContent = HomeContent(
      banners: [
        HomeBanner(
          id: 'btu',
          alt: 'Calcula tus BTU',
          imageUrl: 'https://iprpartesyrepuestos.com/x.webp',
          target: HomeTarget(HomeTargetKind.calculator),
        ),
      ],
    );

    testWidgets('una campaña a la calculadora se oculta si está apagada', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, btuContent);
      expect(find.bySemanticsLabel('Calcula tus BTU'), findsNothing);
      handle.dispose();
    });

    testWidgets('y se muestra y abre la calculadora si está encendida', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, btuContent, btu: true);
      expect(find.bySemanticsLabel('Calcula tus BTU'), findsOneWidget);
      await tester.tap(find.byType(PageView));
      await tester.pumpAndSettle();
      expect(destinationOf(tester), '/tools/btu');
      handle.dispose();
    });
  });

  group('W2-02 · cifras institucionales del servidor', () {
    testWidgets('muestra las cifras tal como las redacta Marketing', (
      tester,
    ) async {
      await _pump(tester, const HomeContent(stats: _stats));
      expect(find.text('+30 años'), findsOneWidget);
      expect(find.text('31'), findsOneWidget);
      expect(find.text('+10.000'), findsOneWidget);
      expect(find.text('Líder del sector HVAC-R*'), findsOneWidget);
      expect(find.text('Sedes atendiendo el mercado'), findsOneWidget);
    });

    testWidgets('cada cifra se lee junta con su etiqueta', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, const HomeContent(stats: _stats));
      expect(
        find.bySemanticsLabel('+30 años Importando y distribuyendo'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('con cifras del servidor no se repiten las calculadas', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, const HomeContent(stats: _stats));
      expect(find.bySemanticsLabel('14 sedes'), findsNothing);
      // La lista de ciudades de "Nuestras sedes" sigue.
      expect(find.text('Medellín · 9 sedes'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('sin cifras del servidor se mantienen las calculadas', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, HomeContent.empty);
      expect(find.bySemanticsLabel('14 sedes'), findsOneWidget);
      handle.dispose();
    });
  });

  group('W2-04 · bloques destacados', () {
    testWidgets('muestran título, texto y llamado a la acción', (tester) async {
      await _pump(tester, const HomeContent(highlights: _highlights));
      expect(find.text('Ingeniería para tu proyecto'), findsOneWidget);
      expect(find.text('Conocer ingeniería'), findsOneWidget);
      expect(find.text('INGENIERÍA IPR'), findsOneWidget);
      expect(
        find.text('Capacitaciones con las marcas líderes'),
        findsOneWidget,
      );
    });

    testWidgets('ingeniería abre su pantalla', (tester) async {
      await _pump(tester, const HomeContent(highlights: _highlights));
      await tester.tap(find.text('Ingeniería para tu proyecto'));
      await tester.pumpAndSettle();
      expect(destinationOf(tester), '/support/engineering');
    });

    testWidgets('formación abre la web de IPR en el navegador', (tester) async {
      final launcher = FakeExternalLauncher();
      await _pump(
        tester,
        const HomeContent(highlights: _highlights),
        launcher: launcher,
      );
      await tester.tap(find.text('Capacitaciones con las marcas líderes'));
      await tester.pump();
      expect(
        launcher.opened.single.toString(),
        'https://iprpartesyrepuestos.com/capacitaciones',
      );
    });

    testWidgets('sin destacados no hay bloques', (tester) async {
      await _pump(tester, HomeContent.empty);
      expect(find.text('Ingeniería para tu proyecto'), findsNothing);
    });
  });

  group('W2 · accesibilidad de la portada con contenido del servidor', () {
    testWidgets('guías de objetivo táctil, etiquetas y contraste', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        const HomeContent(
          banners: _banners,
          stats: _stats,
          highlights: _highlights,
        ),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });

    testWidgets('texto al 200 % sin desbordar con todo el contenido', (
      tester,
    ) async {
      await _pump(
        tester,
        const HomeContent(
          banners: _banners,
          stats: _stats,
          highlights: _highlights,
        ),
        textScale: 2,
        size: const Size(360, 9000),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('con movimiento reducido el cambio de campaña es inmediato', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final handle = tester.ensureSemantics();
      await _pump(tester, const HomeContent(banners: _banners));
      await tester.tap(find.byTooltip('Campaña siguiente'));
      await tester.pump();
      expect(find.bySemanticsLabel('Campaña 2 de 3'), findsOneWidget);
      handle.dispose();
    });
  });
}
