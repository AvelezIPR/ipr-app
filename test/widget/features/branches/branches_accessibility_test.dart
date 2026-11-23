import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/branches/branches.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/ipr_localizations.dart';
import 'package:ipr_mobile/shared/design_system/ipr_theme.dart';
import 'package:ipr_mobile/shared/domain/image_ref.dart';
import 'package:ipr_mobile/shared/navigation/routes.dart';
import 'package:material_ui/material_ui.dart';

import '../../../mocks/test_providers.dart';

final class _FakeBranchesRepository implements BranchesRepository {
  new({this.result});

  final Result<BranchesSnapshot>? result;

  @override
  Future<Result<BranchesSnapshot>> stores({
    bool forceRefresh = false,
    RequestCancellation? cancel,
  }) async => result ?? const Ok(BranchesSnapshot(branches: []));
}

List<Branch> _syntheticBranches() => const [
  Branch(
    slug: 'qa-sede-centro',
    city: 'Medellín',
    name: 'QA-SEDE-1 Centro',
    address: 'Calle 0 # 0-00, Local 1, Medellín',
    upcoming: false,
    phones: [
      BranchPhone(
        type: BranchPhoneType.landline,
        display: '(604) 0000001',
        dial: '+576040000001',
      ),
      BranchPhone(
        type: BranchPhoneType.salesParts,
        display: '300 000 0001',
        dial: '3000000001',
      ),
      BranchPhone(
        type: BranchPhoneType.salesAc,
        display: '300 000 0002',
        dial: '3000000002',
      ),
      BranchPhone(
        type: BranchPhoneType.mobile,
        display: '300 000 0003',
        dial: '3000000003',
      ),
      BranchPhone(
        type: BranchPhoneType.mobileSecondary,
        display: '300 000 0004',
        dial: '3000000004',
      ),
    ],
    whatsappNumber: '573000000009',
    image: ImageRef(
      url: 'https://otro-host.invalid/sede-qa-1.jpg',
      alt: 'QA-SEDE-1 Centro',
    ),
    mapsQuery: 'Calle 0 # 0-00, Medellín',
  ),
  Branch(
    slug: 'qa-sede-proxima',
    city: 'Cartagena',
    name: 'QA-SEDE-2 Próxima',
    address: 'Avenida 0 # 0-00, Cartagena',
    upcoming: true,
    phones: [],
  ),
  Branch(
    slug: 'qa-sede-sin-whatsapp',
    city: 'Bogotá',
    name: 'QA-SEDE-3 Norte',
    address: '',
    upcoming: false,
    phones: [
      BranchPhone(
        type: BranchPhoneType.landline,
        display: '(601) 0000001',
        dial: '+576010000001',
      ),
    ],
  ),
];

Future<void> _pumpBranches(
  WidgetTester tester, {
  required _FakeBranchesRepository repo,
  String initialLocation = Routes.branches,
  double textScale = 1,
  Size size = const Size(360, 800),
}) async {
  tester.view
    ..physicalSize = size
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
  await tester.pumpAndSettle();
}

Future<void> _scrollToBottom(WidgetTester tester) async {
  final scrollables = find.byType(Scrollable);
  if (scrollables.evaluate().isEmpty) return;
  final scrollable = scrollables.first;
  for (var i = 0; i < 12; i++) {
    final state = tester.state<ScrollableState>(scrollable);
    if (state.position.pixels >= state.position.maxScrollExtent) break;
    await tester.drag(scrollable, const Offset(0, -400));
    await tester.pumpAndSettle();
  }
}

Future<void> _expectAllGuidelines(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}

typedef _BranchScenarioBuilder = Future<void> Function(
  WidgetTester tester, {
  double textScale,
  Size size,
});

final Map<String, _BranchScenarioBuilder> _scenarios = {
  'BranchesScreen · sedes por ciudad y próxima apertura':
      (tester, {textScale = 1, size = const Size(360, 800)}) => _pumpBranches(
        tester,
        textScale: textScale,
        size: size,
        repo: _FakeBranchesRepository(
          result: Ok(BranchesSnapshot(branches: _syntheticBranches())),
        ),
      ),
  'BranchesScreen · lista vacía':
      (tester, {textScale = 1, size = const Size(360, 800)}) => _pumpBranches(
        tester,
        textScale: textScale,
        size: size,
        repo: _FakeBranchesRepository(),
      ),
  'BranchesScreen · fallo de red':
      (tester, {textScale = 1, size = const Size(360, 800)}) => _pumpBranches(
        tester,
        textScale: textScale,
        size: size,
        repo: _FakeBranchesRepository(result: const Err(NoConnection())),
      ),
  'BranchDetailScreen · sede operativa completa':
      (tester, {textScale = 1, size = const Size(360, 800)}) => _pumpBranches(
        tester,
        initialLocation: Routes.branchDetail('qa-sede-centro'),
        textScale: textScale,
        size: size,
        repo: _FakeBranchesRepository(
          result: Ok(BranchesSnapshot(branches: _syntheticBranches())),
        ),
      ),
  'BranchDetailScreen · sede sin WhatsApp ni imagen':
      (tester, {textScale = 1, size = const Size(360, 800)}) => _pumpBranches(
        tester,
        initialLocation: Routes.branchDetail('qa-sede-sin-whatsapp'),
        textScale: textScale,
        size: size,
        repo: _FakeBranchesRepository(
          result: Ok(BranchesSnapshot(branches: _syntheticBranches())),
        ),
      ),
  'BranchDetailScreen · sede próximamente':
      (tester, {textScale = 1, size = const Size(360, 800)}) => _pumpBranches(
        tester,
        initialLocation: Routes.branchDetail('qa-sede-proxima'),
        textScale: textScale,
        size: size,
        repo: _FakeBranchesRepository(
          result: Ok(BranchesSnapshot(branches: _syntheticBranches())),
        ),
      ),
  'BranchDetailScreen · fallo de red':
      (tester, {textScale = 1, size = const Size(360, 800)}) => _pumpBranches(
        tester,
        initialLocation: Routes.branchDetail('qa-sede-centro'),
        textScale: textScale,
        size: size,
        repo: _FakeBranchesRepository(result: const Err(NoConnection())),
      ),
};

void main() {
  group('TC-157 · RNF-067..076 · Branches · texto al 200 % sin desbordes', () {
    for (final entry in _scenarios.entries) {
      for (final size in const [Size(360, 800), Size(320, 568)]) {
        testWidgets(
          'TC-157 · RNF-067..076 · ${entry.key} · texto 200 % en ${size.width.toInt()}x${size.height.toInt()}',
          (tester) async {
            await entry.value(tester, textScale: 2, size: size);
            expect(tester.takeException(), isNull);
            await _scrollToBottom(tester);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });

  group('TC-157 · RNF-067..076 · Branches · guías automáticas WCAG 2.2 AA', () {
    for (final entry in _scenarios.entries) {
      testWidgets(
        'TC-157 · RNF-067..076 · ${entry.key} · 4 guías de accesibilidad',
        (tester) async {
          final handle = tester.ensureSemantics();
          try {
            await entry.value(tester, size: const Size(360, 1600));
            await _expectAllGuidelines(tester);
          } finally {
            handle.dispose();
          }
        },
      );
    }
  });

  group('TC-157 · RNF-067..076 · Branches · semántica y no solo color', () {
    testWidgets(
      'TC-157 · RNF-067..076 · BranchesScreen · ciudades son encabezados, tarjetas ≥ 48 dp y badge Próximamente lleva ícono + texto',
      (tester) async {
        final handle = tester.ensureSemantics();
        try {
          await _scenarios['BranchesScreen · sedes por ciudad y próxima apertura']!(
            tester,
            size: const Size(360, 1600),
          );
          for (final city in ['Medellín', 'Cartagena', 'Bogotá']) {
            expect(
              tester.getSemantics(find.text(city)),
              isSemantics(isHeader: true, label: city),
            );
          }
          expect(find.byIcon(Icons.schedule_outlined), findsOneWidget);
          expect(find.text('Próximamente'), findsOneWidget);
          expect(
            tester.getSize(find.byType(Card).first).height,
            greaterThanOrEqualTo(48),
          );
        } finally {
          handle.dispose();
        }
      },
    );

    testWidgets(
      'TC-157 · RNF-067..076 · BranchDetailScreen · encabezados nombre y teléfonos, botones ≥ 48 dp',
      (tester) async {
        final handle = tester.ensureSemantics();
        try {
          await _scenarios['BranchDetailScreen · sede operativa completa']!(
            tester,
            size: const Size(360, 1600),
          );
          expect(
            tester.getSemantics(find.text('QA-SEDE-1 Centro')),
            isSemantics(isHeader: true, label: 'QA-SEDE-1 Centro'),
          );
          expect(
            tester.getSemantics(find.text('Teléfonos')),
            isSemantics(isHeader: true, label: 'Teléfonos'),
          );
          expect(
            tester
                .getSize(
                  find.ancestor(
                    of: find.text('Cómo llegar'),
                    matching: find.bySubtype<FilledButton>(),
                  ),
                )
                .height,
            greaterThanOrEqualTo(48),
          );
        } finally {
          handle.dispose();
        }
      },
    );
  });
}
