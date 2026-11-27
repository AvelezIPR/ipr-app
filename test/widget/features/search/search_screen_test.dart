import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/search/domain/entities/search_suggestion.dart';
import 'package:ipr_mobile/features/search/search.dart';
import 'package:ipr_mobile/features/search/search_providers.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/ipr_localizations.dart';
import 'package:ipr_mobile/shared/design_system/ipr_theme.dart';
import 'package:ipr_mobile/shared/domain/image_ref.dart';
import 'package:ipr_mobile/shared/domain/money.dart';
import 'package:ipr_mobile/shared/domain/price_status.dart';
import 'package:ipr_mobile/shared/navigation/routes.dart';
import 'package:ipr_mobile/shared/widgets/product_card.dart';
import 'package:ipr_mobile/shared/widgets/product_image.dart';
import 'package:ipr_mobile/shared/widgets/state_widgets.dart';
import 'package:ipr_mobile/shared/widgets/whatsapp_button.dart';
import 'package:material_ui/material_ui.dart';

import '../../../mocks/test_providers.dart';
import '../../../unit/features/search/support/search_fakes.dart';

/// Monta `SearchScreen` dentro de un `GoRouter` mínimo: `/` y la ficha
/// (`/product/:slug`), para comprobar la navegación sin tocar `app/`.
Future<({FakeSearchRepository repo, FakeExternalLauncher launcher})> pumpSearch(
  WidgetTester tester, {
  String? initialQuery,
  FakeSearchRepository? repo,
  double textScale = 1,
}) async {
  final fake = repo ?? FakeSearchRepository();
  final launcher = FakeExternalLauncher();
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
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => SearchScreen(initialQuery: initialQuery),
      ),
      GoRoute(
        path: '${Routes.productPrefix}/:slug',
        builder: (_, state) =>
            Scaffold(body: Text('FICHA ${state.pathParameters['slug']}')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: testOverrides(
        launcher: launcher,
        extra: [searchRepositoryProvider.overrideWithValue(fake)],
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
  return (repo: fake, launcher: launcher);
}

Finder get field => find.byType(TextField);

Future<void> type(WidgetTester tester, String text) async {
  await tester.enterText(field, text);
  await tester.pump();
}

Future<void> submit(WidgetTester tester) async {
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pump();
}

bool hasFocus(WidgetTester tester) =>
    tester.widget<TextField>(field).focusNode!.hasFocus;

void main() {
  group('TC-111 · AC-020-3 · campo y búsqueda vacía', () {
    testWidgets('AC-001-2 · el campo abre enfocado y con etiqueta accesible', (
      tester,
    ) async {
      await pumpSearch(tester);
      expect(hasFocus(tester), isTrue);
      expect(find.text('Buscar productos'), findsOneWidget);
      expect(
        find.text(
          'Escribe el nombre, la marca o la referencia (SKU) del producto.',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'AC-001-2 · /search?q= con q vacío o en blanco: sin petición y campo enfocado',
      (tester) async {
        for (final q in ['', '   ']) {
          final h = await pumpSearch(tester, initialQuery: q);
          await tester.pump();
          expect(h.repo.searchCalls, isEmpty, reason: 'q="$q"');
          expect(hasFocus(tester), isTrue, reason: 'q="$q"');
          expect(find.byType(ErrorState), findsNothing);
          await tester.pumpWidget(const SizedBox());
        }
      },
    );

    testWidgets(
      'AC-020-3 · vacío y solo espacios: sin petición y foco en el campo',
      (tester) async {
        final h = await pumpSearch(tester);
        await submit(tester);
        expect(h.repo.searchCalls, isEmpty);
        expect(hasFocus(tester), isTrue);

        await type(tester, '     ');
        await submit(tester);
        expect(h.repo.searchCalls, isEmpty);
        expect(hasFocus(tester), isTrue);
      },
    );
  });

  group('TC-113 · RF-021 · sugerencias', () {
    testWidgets('AC-021-1 · debounce 300 ms y sugerencias bajo el campo', (
      tester,
    ) async {
      final h = await pumpSearch(tester);
      h.repo.autoSuggestions = (q) => Ok(
        SearchSuggestions(items: [suggestion(1), suggestion(2)], total: 2),
      );
      await type(tester, 'val');
      await tester.pump(const Duration(milliseconds: 299));
      expect(h.repo.suggestionCalls, isEmpty);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1));
      expect(h.repo.suggestionCalls.single.query, 'val');
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('Válvula solenoide 1'), findsOneWidget);
      expect(find.text('Válvula solenoide 2'), findsOneWidget);
      expect(
        find.text('Ver todos los resultados para “val” (2)'),
        findsOneWidget,
      );
    });

    testWidgets('con 1 carácter no hay petición ni panel', (tester) async {
      final h = await pumpSearch(tester);
      await type(tester, 'v');
      await tester.pump(const Duration(seconds: 1));
      expect(h.repo.suggestionCalls, isEmpty);
      expect(find.textContaining('Ver todos los resultados'), findsNothing);
    });

    testWidgets('AC-021-3 · tocar una sugerencia abre la ficha del producto', (
      tester,
    ) async {
      final h = await pumpSearch(tester);
      h.repo.autoSuggestions = (q) =>
          Ok(SearchSuggestions(items: [suggestion(7)], total: 1));
      await type(tester, 'val');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await tester.tap(find.text('Válvula solenoide 7'));
      await tester.pumpAndSettle();
      expect(find.text('FICHA producto-7'), findsOneWidget);
    });

    testWidgets(
      'AC-021-4 · si las sugerencias fallan no hay error y se puede buscar',
      (tester) async {
        final h = await pumpSearch(tester);
        h.repo
          ..autoSuggestions = ((q) => const Err(ServiceUnavailable()))
          ..autoSearch = (q, p) => Ok(pageOf([product(1)]));
        await type(tester, 'val');
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();
        expect(find.byType(ErrorState), findsNothing);
        expect(
          find.text('Ver todos los resultados para “val”'),
          findsOneWidget,
        );

        await tester.tap(find.text('Ver todos los resultados para “val”'));
        await tester.pump();
        await tester.pump();
        expect(h.repo.searchCalls.single.query, 'val');
        expect(find.byType(ProductCard), findsOneWidget);
      },
    );

    testWidgets('AC-021-5 · al borrar el texto desaparecen las sugerencias', (
      tester,
    ) async {
      final h = await pumpSearch(tester);
      h.repo.autoSuggestions = (q) =>
          Ok(SearchSuggestions(items: [suggestion(1)], total: 1));
      await type(tester, 'val');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(find.text('Válvula solenoide 1'), findsOneWidget);
      await type(tester, '');
      expect(find.text('Válvula solenoide 1'), findsNothing);
      expect(find.textContaining('Ver todos los resultados'), findsNothing);
    });

    testWidgets('sugerencias enriquecidas muestran miniatura, precio y total', (
      tester,
    ) async {
      final h = await pumpSearch(tester);
      h.repo.autoSuggestions = (q) => Ok(
        SearchSuggestions(
          items: [
            suggestion(
              1,
              image: const ImageRef(
                url: 'https://staging.invalid/img/s-1.jpg',
                alt: 'Válvula 1',
              ),
              price: const Priced(Money(185000)),
            ),
            suggestion(2, price: const OnRequest()),
            suggestion(3),
          ],
          total: 12,
        ),
      );
      await type(tester, 'val');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(find.byType(ProductImage), findsOneWidget);
      expect(find.byIcon(Icons.search), findsWidgets);
      expect(find.text(r'$ 185.000'), findsOneWidget);
      expect(find.text('Más información'), findsOneWidget);
      expect(find.textContaining(r'$ 0'), findsNothing);
      expect(
        find.text('Ver todos los resultados para “val” (12)'),
        findsOneWidget,
      );
    });
  });

  group('TC-111 · RF-020 · resultados', () {
    testWidgets('AC-020-1 · envía, muestra el total y las tarjetas', (
      tester,
    ) async {
      final h = await pumpSearch(tester);
      h.repo.autoSearch = (q, p) => Ok(
        pageOf([
          product(1),
          product(2, price: const OnRequest()),
          product(3),
        ], total: 3),
      );
      await type(tester, '  QA-0001 ');
      await submit(tester);
      await tester.pump();
      expect(h.repo.searchCalls.single.query, 'QA-0001');
      expect(find.byType(ProductCard), findsNWidgets(3));
      expect(find.text('3 resultados'), findsOneWidget);
      expect(find.text('Más información'), findsOneWidget); // nunca "$0"
      expect(find.textContaining(r'$ 0'), findsNothing);
      expect(hasFocus(tester), isFalse);
    });

    testWidgets('un solo resultado usa el singular', (tester) async {
      final h = await pumpSearch(tester);
      h.repo.autoSearch = (q, p) => Ok(pageOf([product(1)]));
      await type(tester, 'QA-0001');
      await submit(tester);
      await tester.pump();
      expect(find.text('1 resultado'), findsOneWidget);
    });

    testWidgets('tocar una tarjeta navega a Routes.product(slug)', (
      tester,
    ) async {
      final h = await pumpSearch(tester);
      h.repo.autoSearch = (q, p) => Ok(pageOf([product(5)]));
      await type(tester, 'valvula');
      await submit(tester);
      await tester.pump();
      await tester.tap(find.byType(ProductCard));
      await tester.pumpAndSettle();
      expect(find.text('FICHA producto-5'), findsOneWidget);
    });

    testWidgets('initialQuery (/search?q=) busca de inmediato, sin enfocar', (
      tester,
    ) async {
      final h = await pumpSearch(tester, initialQuery: '  válvula  ');
      await tester.pump();
      expect(h.repo.searchCalls.single.query, 'válvula');
      expect(tester.widget<TextField>(field).controller!.text, 'válvula');
      expect(hasFocus(tester), isFalse);
    });

    testWidgets(
      'AC-020-4 · caracteres especiales se envían y se muestran como texto',
      (tester) async {
        final h = await pumpSearch(tester);
        h.repo.autoSearch = (q, p) => Ok(pageOf([]));
        const term = '\' " < > % & # válvula';
        await type(tester, term);
        await submit(tester);
        await tester.pump();
        expect(h.repo.searchCalls.single.query, term);
        expect(find.text('No encontramos “$term”'), findsOneWidget);
      },
    );

    testWidgets(
      'AC-020-2 · paginación infinita: al llegar al final pide la página 2',
      (tester) async {
        final h = await pumpSearch(tester);
        h.repo.autoSearch = (q, p) => switch (p) {
          1 => Ok(
            pageOf(
              [for (var i = 1; i <= 24; i++) product(i)],
              hasMore: true,
              total: 30,
            ),
          ),
          _ => Ok(
            pageOf(
              [for (var i = 25; i <= 30; i++) product(i)],
              page: 2,
              total: 30,
            ),
          ),
        };
        await type(tester, 'valvula');
        await submit(tester);
        await tester.pump();
        expect(h.repo.searchCalls.map((c) => c.page), [1]);

        await tester.dragUntilVisible(
          find.text('Válvula solenoide 24'),
          find.byType(ListView).last,
          const Offset(0, -300),
        );
        await tester.pumpAndSettle();
        expect(h.repo.searchCalls.map((c) => c.page), [1, 2]);
        await tester.dragUntilVisible(
          find.text('Válvula solenoide 30'),
          find.byType(ListView).last,
          const Offset(0, -300),
        );
        expect(find.text('Válvula solenoide 30'), findsOneWidget);
        expect(h.repo.searchCalls, hasLength(2)); // sin más páginas
      },
    );

    testWidgets(
      'un error en la página 2 conserva las anteriores y permite reintentar',
      (tester) async {
        final h = await pumpSearch(tester);
        var failPage2 = true;
        h.repo.autoSearch = (q, p) {
          if (p == 1) {
            return Ok(
              pageOf(
                [for (var i = 1; i <= 24; i++) product(i)],
                hasMore: true,
                total: 26,
              ),
            );
          }
          if (failPage2) return const Err(NoConnection());
          return Ok(pageOf([product(25), product(26)], page: 2, total: 26));
        };
        await type(tester, 'valvula');
        await submit(tester);
        await tester.pump();
        await tester.dragUntilVisible(
          find.text('No pudimos cargar más resultados.'),
          find.byType(ListView).last,
          const Offset(0, -300),
        );
        await tester.pump();
        expect(find.text('No pudimos cargar más resultados.'), findsOneWidget);
        expect(find.byType(ProductCard), findsWidgets); // las anteriores siguen
        expect(find.byType(ErrorState), findsNothing);

        failPage2 = false;
        await tester.tap(find.text('Reintentar'));
        await tester.pumpAndSettle();
        expect(find.text('No pudimos cargar más resultados.'), findsNothing);
        await tester.dragUntilVisible(
          find.text('Válvula solenoide 26'),
          find.byType(ListView).last,
          const Offset(0, -300),
        );
        expect(find.text('Válvula solenoide 26'), findsOneWidget);
      },
    );

    testWidgets(
      'el botón Borrar texto reinicia campo, sugerencias y resultados',
      (tester) async {
        final h = await pumpSearch(tester);
        h.repo.autoSearch = (q, p) => Ok(pageOf([product(1)]));
        await type(tester, 'valvula');
        await submit(tester);
        await tester.pump();
        expect(find.byType(ProductCard), findsOneWidget);
        await tester.tap(find.byTooltip('Borrar texto'));
        await tester.pump();
        expect(tester.widget<TextField>(field).controller!.text, isEmpty);
        expect(find.byType(ProductCard), findsNothing);
        expect(hasFocus(tester), isTrue);
      },
    );

    testWidgets(
      'cuadrícula alinea filas con IntrinsicHeight y muestra insignia Oferta',
      (tester) async {
        final h = await pumpSearch(tester);
        h.repo.autoSearch = (q, p) => Ok(
          pageOf([
            product(
              1,
              name: 'Válvula solenoide en oferta con nombre largo para probar altura',
              regularPrice: const Money(210000),
              onSale: true,
            ),
            product(2, name: 'Filtro corto'),
          ]),
        );
        await type(tester, 'valvula');
        await submit(tester);
        await tester.pump();

        expect(find.byType(IntrinsicHeight), findsOneWidget);
        expect(find.text('Oferta'), findsOneWidget);
        expect(find.byIcon(Icons.local_offer), findsOneWidget);
        expect(find.text(r'Antes $ 210.000'), findsOneWidget);
      },
    );
  });

  group('TC-114 · RF-023 · sin resultados y WhatsApp', () {
    testWidgets(
      'AC-023-1 · 200 vacío: mensaje con el término y botón de WhatsApp',
      (tester) async {
        final h = await pumpSearch(tester);
        h.repo.autoSearch = (q, p) => Ok(pageOf([]));
        await type(tester, 'qa-sin-resultados');
        await submit(tester);
        await tester.pump();
        expect(find.text('No encontramos “qa-sin-resultados”'), findsOneWidget);
        expect(find.byType(WhatsAppButton), findsOneWidget);
        expect(find.text('Escribir por WhatsApp'), findsOneWidget);
        expect(find.byType(ErrorState), findsNothing);
      },
    );

    testWidgets(
      'AC-023-2/3 · el mensaje de WhatsApp lleva el término exacto codificado',
      (tester) async {
        final h = await pumpSearch(tester);
        h.repo.autoSearch = (q, p) => Ok(pageOf([]));
        const term = 'válvula 1/4 & tubo #3';
        await type(tester, term);
        await submit(tester);
        await tester.pump();
        await tester.tap(find.text('Escribir por WhatsApp'));
        await tester.pump();
        final uri = h.launcher.opened.single;
        expect(uri.host, 'wa.me');
        expect(uri.queryParameters['text'], contains('"$term"'));
        expect(uri.toString(), isNot(contains('&tubo')));
        expect(uri.toString(), isNot(contains('#3')));
      },
    );

    testWidgets('AC-023-6 · funciona sin sesión (no pide iniciar sesión)', (
      tester,
    ) async {
      final h = await pumpSearch(tester);
      h.repo.autoSearch = (q, p) => Ok(pageOf([]));
      await type(tester, 'xyz');
      await submit(tester);
      await tester.pump();
      expect(find.textContaining('sesión'), findsNothing);
    });

    testWidgets('"Volver a buscar" repite la misma consulta', (tester) async {
      final h = await pumpSearch(tester);
      h.repo.autoSearch = (q, p) => Ok(pageOf([]));
      await type(tester, 'xyz');
      await submit(tester);
      await tester.pump();
      await tester.tap(find.text('Volver a buscar'));
      await tester.pump();
      expect(h.repo.searchCalls.map((c) => c.query), ['xyz', 'xyz']);
    });

    testWidgets(
      'AC-023-5 · error de red: ErrorState con Reintentar, NO vacío ni WhatsApp',
      (tester) async {
        final h = await pumpSearch(tester);
        h.repo.autoSearch = (q, p) => const Err(NoConnection());
        await type(tester, 'válvula');
        await submit(tester);
        await tester.pump();
        expect(find.byType(ErrorState), findsOneWidget);
        expect(
          find.text('No tienes conexión. Revisa tu internet.'),
          findsOneWidget,
        );
        expect(find.text('Reintentar'), findsOneWidget);
        expect(find.textContaining('No encontramos'), findsNothing);
        expect(find.byType(WhatsAppButton), findsNothing);

        h.repo.autoSearch = (q, p) => Ok(pageOf([product(1)]));
        await tester.tap(find.text('Reintentar'));
        await tester.pump();
        await tester.pump();
        expect(find.byType(ProductCard), findsOneWidget);
        expect(find.byType(ErrorState), findsNothing);
      },
    );

    testWidgets('503 (índice calentando) también es error, no vacío', (
      tester,
    ) async {
      final h = await pumpSearch(tester);
      h.repo.autoSearch = (q, p) =>
          const Err(ServiceUnavailable(retryAfter: 5));
      await type(tester, 'válvula');
      await submit(tester);
      await tester.pump();
      expect(
        find.text('La tienda no está disponible en este momento.'),
        findsOneWidget,
      );
      expect(find.byType(WhatsAppButton), findsNothing);
    });

    testWidgets('mientras carga muestra el indicador, no el vacío', (
      tester,
    ) async {
      final h = await pumpSearch(tester);
      await type(tester, 'válvula');
      await submit(tester);
      await tester.pump();
      expect(find.byType(LoadingState), findsOneWidget);
      expect(find.textContaining('No encontramos'), findsNothing);
      h.repo.searchCalls.single.ok(pageOf([product(1)]));
      await tester.pump();
      expect(find.byType(LoadingState), findsNothing);
    });
  });

  group('RNF-068/070/075 · accesibilidad y texto al 200 %', () {
    for (final scale in [1.0, 2.0]) {
      testWidgets('sugerencias enriquecidas a texto ×$scale sin desbordar', (
        tester,
      ) async {
        final h = await pumpSearch(tester, textScale: scale);
        h.repo.autoSuggestions = (q) => Ok(
          SearchSuggestions(
            items: [
              suggestion(
                1,
                image: const ImageRef(
                  url: 'https://staging.invalid/img/s-1.jpg',
                  alt: 'Detector',
                ),
                price: const Priced(Money(1445000)),
              ),
              suggestion(2, price: const OnRequest()),
            ],
            total: 15,
          ),
        );
        await type(tester, 'detector');
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();
        expect(tester.takeException(), isNull);
        final seeAll = find.text(
          'Ver todos los resultados para “detector” (15)',
        );
        await tester.scrollUntilVisible(
          seeAll,
          120,
          scrollable: find.descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(seeAll, findsOneWidget);
      });

      testWidgets('resultados a texto ×$scale sin desbordar', (tester) async {
        final h = await pumpSearch(tester, textScale: scale);
        h.repo.autoSearch = (q, p) => Ok(
          pageOf([
            product(
              1,
              name: 'Detector de fugas de refrigerante CO2 R744 Elitech',
              regularPrice: const Money(1650000),
              onSale: true,
            ),
            product(2, price: const OnRequest()),
            product(3, price: const Priced(Money(1445000))),
          ]),
        );
        await type(tester, 'detector');
        await submit(tester);
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.byType(ProductCard), findsWidgets);
        expect(find.text('Oferta'), findsOneWidget);
      });

      testWidgets('vacío y error a texto ×$scale sin desbordar', (
        tester,
      ) async {
        final h = await pumpSearch(tester, textScale: scale);
        h.repo.autoSearch = (q, p) => Ok(pageOf([]));
        await type(
          tester,
          'una consulta bastante larga que no existe en el catálogo',
        );
        await submit(tester);
        await tester.pump();
        expect(tester.takeException(), isNull);
        h.repo.autoSearch = (q, p) => const Err(NoConnection());
        await tester.ensureVisible(find.text('Volver a buscar'));
        await tester.tap(find.text('Volver a buscar'));
        await tester.pump();
        await tester.pump();
        expect(find.byType(ErrorState), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
      'guías de objetivo táctil, etiquetas y contraste (resultados)',
      (tester) async {
        final handle = tester.ensureSemantics();
        final h = await pumpSearch(tester);
        h.repo.autoSearch = (q, p) => Ok(pageOf([product(1), product(2)]));
        await type(tester, 'valvula');
        await submit(tester);
        await tester.pump();
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      },
    );

    testWidgets('guías de accesibilidad (sin resultados y sugerencias)', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final h = await pumpSearch(tester);
      h.repo.autoSuggestions = (q) =>
          Ok(SearchSuggestions(items: [suggestion(1)], total: 1));
      await type(tester, 'val');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));

      h.repo.autoSearch = (q, p) => Ok(pageOf([]));
      await tester.tap(find.text('Ver todos los resultados para “val” (1)'));
      await tester.pump();
      await tester.pump();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });

    testWidgets(
      'el campo anuncia su etiqueta y el botón de borrar tiene tooltip',
      (tester) async {
        final handle = tester.ensureSemantics();
        await pumpSearch(tester);
        await type(tester, 'a');
        expect(find.bySemanticsLabel(RegExp('Buscar productos')), findsWidgets);
        expect(find.byTooltip('Borrar texto'), findsOneWidget);
        handle.dispose();
      },
    );
  });

  group('M1 · RF-020 · ciclo de vida', () {
    testWidgets('salir de la pantalla cancela la búsqueda en vuelo', (
      tester,
    ) async {
      final h = await pumpSearch(tester);
      await type(tester, 'valvula');
      await submit(tester);
      await tester.pump();
      final cancellation = h.repo.searchCalls.single.cancellation!;
      expect(cancellation.isCancelled, isFalse);
      await tester.pumpWidget(const SizedBox());
      expect(cancellation.isCancelled, isTrue);
    });
  });
}
