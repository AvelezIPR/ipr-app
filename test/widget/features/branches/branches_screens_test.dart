import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/branches/branches.dart';
import 'package:ipr_mobile/features/branches/branches_providers.dart';
import 'package:ipr_mobile/features/branches/data/mappers/branches_mappers.dart';
import 'package:ipr_mobile/features/branches/domain/entities/colombia_map.dart';
import 'package:ipr_mobile/features/branches/presentation/widgets/branches_map.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/ipr_localizations.dart';
import 'package:ipr_mobile/shared/design_system/ipr_theme.dart';
import 'package:ipr_mobile/shared/navigation/routes.dart';
import 'package:material_ui/material_ui.dart';

import '../../../mocks/test_providers.dart';

final class _FakeBranchesRepository implements BranchesRepository {
  Result<BranchesSnapshot> Function()? onStores;
  int calls = 0;

  @override
  Future<Result<BranchesSnapshot>> stores({
    bool forceRefresh = false,
    RequestCancellation? cancel,
  }) async {
    calls++;
    return onStores?.call() ?? const Ok(BranchesSnapshot(branches: []));
  }
}

List<Branch> _fixtureBranches() {
  Map<String, dynamic> load(String name) =>
      jsonDecode(File('test/fixtures/branches/$name').readAsStringSync())
          as Map<String, dynamic>;
  return mapStores({
    'data': [
      load('Store.valid.json'),
      load('Store.upcoming.json'),
      load('Store.missing-whatsapp.json'),
    ],
  });
}

Future<FakeExternalLauncher> _pumpBranches(
  WidgetTester tester, {
  required _FakeBranchesRepository repo,
  String initialLocation = Routes.branches,
  FakeExternalLauncher? launcher,
  double textScale = 1,
  List<Override> extra = const [],
}) async {
  final fakeLauncher = launcher ?? FakeExternalLauncher();
  tester.view
    ..physicalSize = const Size(360, 1800)
    ..devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearAllTestValues();
  });

  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: Routes.branches, builder: (_, _) => const BranchesScreen()),
      GoRoute(
        path: '${Routes.branches}/:slug',
        builder: (_, state) =>
            BranchDetailScreen(slug: state.pathParameters['slug']!),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: testOverrides(
        launcher: fakeLauncher,
        extra: [branchesRepositoryProvider.overrideWithValue(repo), ...extra],
      ),
      child: MaterialApp.router(
        theme: IprTheme.light(),
        locale: iprLocale,
        localizationsDelegates: iprLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  await _settle(tester, () => find.byType(BranchesMap).evaluate().isNotEmpty);
  return fakeLauncher;
}

/// Espera (con tiempo real) a que se cumpla [done]: la lista y el mapa se
/// leen de forma asíncrona (repositorio y asset).
Future<void> _settle(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 60 && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
}

/// Espera a que el mapa dibujado esté en pantalla.
Future<void> _waitForMapDrawn(WidgetTester tester) => _settle(
  tester,
  () => find
      .descendant(
        of: find.byType(BranchesMap),
        matching: find.byType(CustomPaint),
      )
      .evaluate()
      .isNotEmpty,
);

void main() {
  group('TC-124 / TC-138 · Listado de sedes sin sesión', () {
    testWidgets(
      'TC-124 · AC-072-1..4 · agrupa por ciudad, Próximamente sin navegación y abre ficha operativa',
      (tester) async {
        final repo = _FakeBranchesRepository()
          ..onStores = () => Ok(BranchesSnapshot(branches: _fixtureBranches()));
        await _pumpBranches(tester, repo: repo);

        expect(find.text('Medellín'), findsOneWidget);
        expect(find.text('Cartagena'), findsOneWidget);
        expect(find.text('Bogotá'), findsOneWidget);
        expect(find.text('Próximamente'), findsOneWidget);

        // Tocar sede Próximamente no navega.
        await tester.tap(find.text('QA-SEDE-2 Próxima'));
        await tester.pumpAndSettle();
        expect(find.text('Sedes'), findsOneWidget);

        // Tocar sede operativa abre la ficha.
        await tester.tap(find.text('QA-SEDE-1 Centro'));
        await tester.pumpAndSettle();
        expect(find.text('Detalle de sede'), findsOneWidget);
        expect(find.text('Escribir por WhatsApp'), findsOneWidget);
        expect(find.text('Cómo llegar'), findsOneWidget);
        expect(find.textContaining('Fijo / PBX'), findsOneWidget);
      },
    );

    testWidgets(
      'AC-072-5 · error de red muestra Reintentar y al reintentar carga sedes',
      (tester) async {
        final repo = _FakeBranchesRepository()
          ..onStores = () => const Err(NoConnection());
        await _pumpBranches(tester, repo: repo);
        expect(find.text('Reintentar'), findsOneWidget);

        repo.onStores = () =>
            Ok(BranchesSnapshot(branches: _fixtureBranches()));
        await tester.tap(find.text('Reintentar'));
        await tester.pump();
        await tester.pump();
        expect(find.text('QA-SEDE-1 Centro'), findsOneWidget);
      },
    );
  });

  group(
    'TC-125 · Ficha de sede: omitir faltantes, Llamar, WhatsApp y Cómo llegar',
    () {
      testWidgets(
        'TC-124 · AC-073-2/3 · AC-074-4 · omite WhatsApp faltante sin null y muestra marcador sin imagen',
        (tester) async {
          final repo = _FakeBranchesRepository()
            ..onStores = () =>
                Ok(BranchesSnapshot(branches: _fixtureBranches()));
          await _pumpBranches(
            tester,
            repo: repo,
            initialLocation: Routes.branchDetail('sede-sin-whatsapp'),
          );
          expect(find.text('QA-SEDE-3 Norte'), findsOneWidget);
          expect(find.text('Escribir por WhatsApp'), findsNothing);
          expect(find.textContaining('null'), findsNothing);
          expect(
            find.byIcon(Icons.image_not_supported_outlined),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'TC-125 · AC-074-1..3 · AC-075-1/3 · lanza tel:, WhatsApp de la sede, fallback AC-063-1 y Cómo llegar',
        (tester) async {
          final repo = _FakeBranchesRepository()
            ..onStores = () =>
                Ok(BranchesSnapshot(branches: _fixtureBranches()));
          final launcher = FakeExternalLauncher(
            results: [true, true, false, false],
          );
          await _pumpBranches(
            tester,
            repo: repo,
            initialLocation: Routes.branchDetail('sede-prueba-centro'),
            launcher: launcher,
            textScale: 2,
          );

          // Cómo llegar
          final mapsBtn = find.text('Cómo llegar');
          await tester.ensureVisible(mapsBtn);
          await tester.tap(mapsBtn);
          await tester.pump();
          expect(launcher.opened.last.host, 'www.google.com');
          expect(
            launcher.opened.last.queryParameters['query'],
            'Calle 0 # 0-00, Medellín',
          );

          // Llamar
          final callBtn = find.textContaining('(604) 3604440');
          await tester.ensureVisible(callBtn);
          await tester.tap(callBtn);
          await tester.pump();
          expect(launcher.opened.last.toString(), 'tel:+576043604440');

          // WhatsApp de la sede falla -> diálogo AC-063-1
          final waBtn = find.text('Escribir por WhatsApp');
          await tester.ensureVisible(waBtn);
          await tester.tap(waBtn);
          await tester.pumpAndSettle();
          expect(launcher.opened.last.path, '/573000000009');
          expect(find.text('No pudimos abrir WhatsApp'), findsOneWidget);
          await tester.tap(find.text('Cerrar'));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
        },
      );

      testWidgets('AC-074-5 · ficha de sede próximamente no muestra acciones', (
        tester,
      ) async {
        final repo = _FakeBranchesRepository()
          ..onStores = () => Ok(BranchesSnapshot(branches: _fixtureBranches()));
        await _pumpBranches(
          tester,
          repo: repo,
          initialLocation: Routes.branchDetail('sede-proxima-cartagena'),
        );
        expect(find.text('Próximamente'), findsOneWidget);
        expect(find.text('Cómo llegar'), findsNothing);
        expect(find.text('Escribir por WhatsApp'), findsNothing);
        expect(find.byIcon(Icons.phone_outlined), findsNothing);
      });
    },
  );

  group('W3-03 · mapa de sedes y filtro por ciudad', () {
    ColombiaMap realMap() => ColombiaMap.fromJson(
      jsonDecode(File('assets/map/colombia_map.json').readAsStringSync()),
    );

    _FakeBranchesRepository repoWithFixtures() =>
        _FakeBranchesRepository()
          ..onStores = () => Ok(BranchesSnapshot(branches: _fixtureBranches()));

    /// Posición en pantalla del pin de [city] en el mapa dibujado.
    Offset pinAt(WidgetTester tester, String city) {
      final rect = tester.getRect(
        find.descendant(
          of: find.byType(BranchesMap),
          matching: find.byType(CustomPaint),
        ),
      );
      final map = realMap();
      final at = map.cities[city]!;
      final scale = rect.width / map.width;
      return rect.topLeft + Offset(at.x * scale, at.y * scale);
    }

    testWidgets('muestra el mapa y un botón por ciudad', (tester) async {
      await _pumpBranches(tester, repo: repoWithFixtures());
      expect(find.byType(BranchesMap), findsOneWidget);
      expect(find.text('Todas las ciudades'), findsOneWidget);
      expect(find.textContaining('Medellín ·'), findsOneWidget);
      expect(find.textContaining('Bogotá ·'), findsOneWidget);
      expect(find.text('Cartagena · próximamente'), findsOneWidget);
    });

    testWidgets('el mapa se anuncia como una sola imagen', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpBranches(tester, repo: repoWithFixtures());
      await _waitForMapDrawn(tester);
      expect(
        find.bySemanticsLabel(
          'Mapa de Colombia con las ciudades donde hay sedes. '
          'Elige una ciudad en los botones de abajo.',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets(
      'un botón de ciudad deja solo esa ciudad y "Todas" la restaura',
      (tester) async {
        await _pumpBranches(tester, repo: repoWithFixtures());
        expect(find.text('Medellín'), findsOneWidget);

        await tester.tap(find.textContaining('Bogotá ·'));
        await tester.pump();
        expect(find.text('Bogotá'), findsOneWidget);
        expect(find.text('Medellín'), findsNothing);
        expect(find.text('Cartagena'), findsNothing);

        await tester.tap(find.text('Todas las ciudades'));
        await tester.pump();
        expect(find.text('Medellín'), findsOneWidget);
        expect(find.text('Cartagena'), findsOneWidget);
      },
    );

    testWidgets('tocar de nuevo el botón elegido vuelve a todas', (
      tester,
    ) async {
      await _pumpBranches(tester, repo: repoWithFixtures());
      await tester.tap(find.textContaining('Bogotá ·'));
      await tester.pump();
      expect(find.text('Medellín'), findsNothing);
      await tester.tap(find.textContaining('Bogotá ·'));
      await tester.pump();
      expect(find.text('Medellín'), findsOneWidget);
    });

    testWidgets('tocar el pin de una ciudad en el mapa la elige', (
      tester,
    ) async {
      await _pumpBranches(tester, repo: repoWithFixtures());
      await _waitForMapDrawn(tester);
      await tester.tapAt(pinAt(tester, 'Bogotá'));
      await tester.pump();
      expect(find.text('Bogotá'), findsOneWidget);
      expect(find.text('Medellín'), findsNothing);

      // Tocar otra vez el mismo pin la deselecciona.
      await tester.tapAt(pinAt(tester, 'Bogotá'));
      await tester.pump();
      expect(find.text('Medellín'), findsOneWidget);
    });

    testWidgets('tocar fuera de cualquier pin no cambia nada', (tester) async {
      await _pumpBranches(tester, repo: repoWithFixtures());
      await _waitForMapDrawn(tester);
      // Esquina superior izquierda del mapa: océano.
      final rect = tester.getRect(
        find.descendant(
          of: find.byType(BranchesMap),
          matching: find.byType(CustomPaint),
        ),
      );
      await tester.tapAt(rect.topLeft + const Offset(4, 4));
      await tester.pump();
      expect(find.text('Medellín'), findsOneWidget);
      expect(find.text('Bogotá'), findsOneWidget);
    });

    testWidgets('sin mapa (asset ilegible) la pantalla sigue con su lista', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pumpBranches(
        tester,
        repo: repoWithFixtures(),
        extra: [colombiaMapProvider.overrideWith((ref) => ColombiaMap.empty)],
      );
      // Sin geometría no hay mapa que anunciar ni dibujar...
      expect(find.bySemanticsLabel(RegExp('^Mapa de Colombia')), findsNothing);
      // ...pero los botones de ciudad y la lista siguen.
      expect(find.text('Todas las ciudades'), findsOneWidget);
      expect(find.text('Medellín'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('texto al 200 % sin desbordar', (tester) async {
      await _pumpBranches(tester, repo: repoWithFixtures(), textScale: 2);
      expect(tester.takeException(), isNull);
    });
  });

  group('W3-03 · pin más cercano', () {
    const positions = {
      'Medellín': Offset(100, 100),
      'Rionegro': Offset(112, 106),
      'Cali': Offset(40, 200),
    };

    test('elige el más cercano dentro del radio', () {
      expect(
        BranchesMap.nearestPin(tap: const Offset(98, 99), positions: positions),
        'Medellín',
      );
      // Entre dos pines casi pegados gana el más cercano.
      expect(
        BranchesMap.nearestPin(
          tap: const Offset(111, 106),
          positions: positions,
        ),
        'Rionegro',
      );
    });

    test('fuera del radio no elige nada', () {
      expect(
        BranchesMap.nearestPin(
          tap: const Offset(300, 300),
          positions: positions,
        ),
        isNull,
      );
      expect(
        BranchesMap.nearestPin(tap: Offset.zero, positions: const {}),
        isNull,
      );
    });
  });
}
