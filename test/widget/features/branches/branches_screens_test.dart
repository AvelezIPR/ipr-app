import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/branches/branches.dart';
import 'package:ipr_mobile/features/branches/data/mappers/branches_mappers.dart';
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
}) async {
  final fakeLauncher = launcher ?? FakeExternalLauncher();
  tester.view
    ..physicalSize = const Size(360, 800)
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
        extra: [branchesRepositoryProvider.overrideWithValue(repo)],
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
  return fakeLauncher;
}

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
}
