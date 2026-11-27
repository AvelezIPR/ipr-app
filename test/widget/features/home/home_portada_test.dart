import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/config/remote_config.dart';
import 'package:ipr_mobile/core/config/remote_config_controller.dart';
import 'package:ipr_mobile/core/config/remote_config_repository.dart'
    show RemoteConfigSource;
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/home/domain/entities/home_brand.dart';
import 'package:ipr_mobile/features/home/domain/entities/home_category.dart';
import 'package:ipr_mobile/features/home/domain/entities/home_city.dart';
import 'package:ipr_mobile/features/home/domain/entities/section_data.dart';
import 'package:ipr_mobile/features/home/presentation/widgets/home_brand_blocks.dart';
import 'package:material_ui/material_ui.dart';

import '../../../unit/features/home/home_test_support.dart';
import 'home_harness.dart';

const _tall = Size(360, 4000);

const _categories = [
  HomeCategory(id: 1, slug: 'aire', name: 'Aire Acondicionado'),
  HomeCategory(id: 2, slug: 'refrigeracion', name: 'Refrigeración'),
  HomeCategory(id: 3, slug: 'electricos', name: 'Eléctricos'),
];

const _cities = [
  HomeCity(name: 'Medellín', branchCount: 9, upcoming: false),
  HomeCity(name: 'Cali', branchCount: 5, upcoming: false),
  HomeCity(name: 'Cartagena', branchCount: 0, upcoming: true),
];

FakeHomeRepository _repo({Result<SectionData<List<HomeCity>>>? cities}) =>
    FakeHomeRepository(
      categoryResults: const [Ok(SectionData(_categories))],
      brandResults: const [
        Ok(SectionData([HomeBrand(slug: 'elitech', name: 'Elitech')])),
      ],
      featuredResults: const [Ok(SectionData([]))],
      cityResults: [cities ?? const Ok(SectionData(_cities))],
    );

void main() {
  group('Portada · identidad de marca', () {
    testWidgets('la cabecera muestra el logo de IPR con etiqueta accesible', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpHome(tester, repository: _repo(), size: _tall);

      expect(find.byType(IprLogoMark), findsOneWidget);
      expect(find.bySemanticsLabel('Logo de IPR'), findsOneWidget);
      expect(find.text('IPR Partes y Repuestos'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('el bloque de bienvenida lleva al catálogo', (tester) async {
      await pumpHome(tester, repository: _repo(), size: _tall);

      expect(
        find.text('Todo para aire acondicionado, refrigeración y ventilación'),
        findsOneWidget,
      );
      await tester.tap(find.text('Ver el catálogo'));
      await tester.pumpAndSettle();
      expect(destinationOf(tester), '/catalog');
    });

    testWidgets('cada categoría lleva su ícono, no un número', (tester) async {
      await pumpHome(tester, repository: _repo(), size: _tall);

      expect(find.byIcon(Icons.air), findsOneWidget);
      expect(find.byIcon(Icons.ac_unit), findsWidgets);
      expect(find.byIcon(Icons.bolt), findsOneWidget);
      expect(find.text('01'), findsNothing);
    });
  });

  group('RF-072 · Nuestras sedes (resumen por ciudad)', () {
    testWidgets('muestra totales y una entrada por ciudad desde /stores', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpHome(tester, repository: _repo(), size: _tall);

      expect(find.text('Nuestras sedes'), findsOneWidget);
      // Cartagena (por abrir) no suma a los totales.
      // Banda de cifras: sedes, ciudades (sin la que está por abrir) y las
      // marcas que entrega el servidor; cada cifra se lee junta.
      expect(find.bySemanticsLabel('14 sedes'), findsOneWidget);
      expect(find.bySemanticsLabel('2 ciudades'), findsOneWidget);
      expect(find.bySemanticsLabel('1 marca'), findsOneWidget);
      expect(find.text('14'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Medellín · 9 sedes'), findsOneWidget);
      expect(find.text('Cali · 5 sedes'), findsOneWidget);
      expect(find.text('Cartagena · próximamente'), findsOneWidget);
      handle.dispose();
    });

    testWidgets(
      'chip upcoming muestra ícono + texto diferenciado y cumple accesibilidad',
      (tester) async {
        final handle = tester.ensureSemantics();
        await pumpHome(tester, repository: _repo(), size: _tall);

        expect(find.byIcon(Icons.schedule_outlined), findsOneWidget);
        expect(find.text('Cartagena · próximamente'), findsOneWidget);
        expect(
          find.descendant(
            of: find.widgetWithText(OutlinedButton, 'Cartagena · próximamente'),
            matching: find.byIcon(Icons.schedule_outlined),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.widgetWithText(OutlinedButton, 'Medellín · 9 sedes'),
            matching: find.byIcon(Icons.schedule_outlined),
          ),
          findsNothing,
        );

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();

        await pumpHome(
          tester,
          repository: _repo(),
          textScale: 2,
          size: const Size(360, 9000),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('el singular se escribe bien (1 sede en 1 ciudad)', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpHome(
        tester,
        repository: _repo(
          cities: const Ok(
            SectionData([
              HomeCity(name: 'Rionegro', branchCount: 1, upcoming: false),
            ]),
          ),
        ),
        size: _tall,
      );
      expect(find.bySemanticsLabel('1 sede'), findsOneWidget);
      expect(find.bySemanticsLabel('1 ciudad'), findsOneWidget);
      expect(find.text('Rionegro · 1 sede'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('tocar una ciudad o "Ver todas las sedes" abre /branches', (
      tester,
    ) async {
      await pumpHome(tester, repository: _repo(), size: _tall);

      await tester.tap(find.text('Medellín · 9 sedes'));
      await tester.pumpAndSettle();
      expect(destinationOf(tester), '/branches');
    });

    testWidgets('"Ver todas las sedes" abre /branches', (tester) async {
      await pumpHome(tester, repository: _repo(), size: _tall);

      await tester.tap(find.text('Ver todas las sedes'));
      await tester.pumpAndSettle();
      expect(destinationOf(tester), '/branches');
    });

    testWidgets('sin sedes del servidor el bloque se oculta', (tester) async {
      await pumpHome(
        tester,
        repository: _repo(cities: const Ok(SectionData([]))),
        size: _tall,
      );
      expect(find.text('Nuestras sedes'), findsNothing);
    });

    testWidgets('si /stores falla el bloque se oculta sin "Reintentar"', (
      tester,
    ) async {
      await pumpHome(
        tester,
        repository: _repo(cities: const Err(NoConnection())),
        size: _tall,
      );
      expect(find.text('Nuestras sedes'), findsNothing);
      expect(find.text('Reintentar'), findsNothing);
      // El acceso a Sedes de "Más accesos" sigue disponible.
      expect(find.text('Sedes'), findsOneWidget);
    });
  });

  group('Portada · tarjeta de la calculadora de BTU', () {
    testWidgets('con la función activa se ve la tarjeta y navega', (
      tester,
    ) async {
      await pumpHome(
        tester,
        repository: _repo(),
        size: _tall,
        extra: [
          remoteConfigProvider.overrideWithBuild(
            (_, _) => const RemoteConfigState(
              config: RemoteConfig(btuCalculatorEnabled: true),
              source: RemoteConfigSource.network,
            ),
          ),
        ],
      );
      expect(
        find.text('Calcula los BTU que necesita tu espacio antes de comprar.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Calculadora de BTU'));
      await tester.pumpAndSettle();
      expect(destinationOf(tester), '/tools/btu');
    });

    testWidgets('con la función apagada no hay tarjeta', (tester) async {
      await pumpHome(tester, repository: _repo(), size: _tall);
      expect(find.text('Calculadora de BTU'), findsNothing);
      expect(find.text('Abrir la calculadora'), findsNothing);
    });
  });
}
