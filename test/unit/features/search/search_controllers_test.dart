import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/features/search/presentation/controllers/search_results_controller.dart';
import 'package:ipr_mobile/features/search/presentation/controllers/search_suggestions_controller.dart';
import 'package:ipr_mobile/features/search/search_providers.dart';
import 'package:ipr_mobile/shared/widgets/ui_state.dart';

import 'support/search_fakes.dart';

ProviderContainer containerWith(FakeSearchRepository repo) {
  final container = ProviderContainer(
    overrides: [searchRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  // Mantiene vivos los providers autoDispose durante la prueba.
  container
    ..listen(searchResultsControllerProvider, (_, _) {})
    ..listen(searchSuggestionsControllerProvider, (_, _) {});
  return container;
}

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  group('M1 · RF-020 · SearchResultsController', () {
    test('AC-020-3 · vacío o solo espacios: sin petición', () {
      final repo = FakeSearchRepository();
      final c = containerWith(repo);
      final ctrl = c.read(searchResultsControllerProvider.notifier);
      expect(ctrl.submit(''), isFalse);
      expect(ctrl.submit('   \t '), isFalse);
      expect(repo.searchCalls, isEmpty);
      expect(c.read(searchResultsControllerProvider).isIdle, isTrue);
    });

    test('AC-020-1 · carga → datos; la consulta se normaliza', () async {
      final repo = FakeSearchRepository();
      final c = containerWith(repo);
      final ctrl = c.read(searchResultsControllerProvider.notifier);
      expect(ctrl.submit('  QA-0001   '), isTrue);
      expect(
        c.read(searchResultsControllerProvider).ui,
        isA<UiLoading<SearchListing>>(),
      );
      expect(repo.searchCalls.single.query, 'QA-0001');
      repo.searchCalls.single.ok(
        pageOf([product(1)], hasMore: true, total: 30),
      );
      await flush();
      final ui = c.read(searchResultsControllerProvider).ui;
      expect(ui, isA<UiData<SearchListing>>());
      final listing = (ui as UiData<SearchListing>).value;
      expect(listing.items.single.id, 1);
      expect(listing.total, 30);
      expect(listing.hasMore, isTrue);
    });

    test('RF-023 · 200 vacío → UiEmpty', () async {
      final repo = FakeSearchRepository();
      final c = containerWith(repo);
      c
          .read(searchResultsControllerProvider.notifier)
          .submit('qa-sin-resultados');
      repo.searchCalls.single.ok(pageOf([]));
      await flush();
      expect(
        c.read(searchResultsControllerProvider).ui,
        isA<UiEmpty<SearchListing>>(),
      );
    });

    test(
      'AC-023-5 · fallo de red/servidor → UiFailure, nunca UiEmpty',
      () async {
        final repo = FakeSearchRepository();
        final c = containerWith(repo);
        final ctrl = c.read(searchResultsControllerProvider.notifier)
          ..submit('válvula');
        repo.searchCalls.single.fail(const NoConnection());
        await flush();
        var ui = c.read(searchResultsControllerProvider).ui;
        expect(ui, isA<UiFailure<SearchListing>>());
        expect((ui as UiFailure<SearchListing>).failure, isA<NoConnection>());

        ctrl.retry();
        repo.searchCalls.last.fail(const ServiceUnavailable());
        await flush();
        ui = c.read(searchResultsControllerProvider).ui;
        expect(
          (ui as UiFailure<SearchListing>).failure,
          isA<ServiceUnavailable>(),
        );
        expect(repo.searchCalls, hasLength(2));
        expect(repo.searchCalls.last.query, 'válvula');
      },
    );

    test(
      'paginación infinita: añade páginas sin duplicar y se detiene',
      () async {
        final repo = FakeSearchRepository();
        final c = containerWith(repo);
        final ctrl = c.read(searchResultsControllerProvider.notifier)
          ..submit('valvula');
        repo.searchCalls.single.ok(
          pageOf([product(1), product(2)], hasMore: true, total: 3),
        );
        await flush();

        final more = ctrl.loadMore();
        expect(repo.searchCalls.last.page, 2);
        // Una segunda petición simultánea no se emite.
        await ctrl.loadMore();
        expect(repo.searchCalls, hasLength(2));
        repo.searchCalls.last.ok(
          pageOf([product(2), product(3)], page: 2, total: 3),
        );
        await more;
        final listing =
            (c.read(searchResultsControllerProvider).ui
                    as UiData<SearchListing>)
                .value;
        expect(listing.items.map((p) => p.id), [1, 2, 3]);
        expect(listing.page, 2);
        expect(listing.hasMore, isFalse);
        expect(listing.isLoadingMore, isFalse);
        await ctrl.loadMore(); // sin más páginas
        expect(repo.searchCalls, hasLength(2));
      },
    );

    test(
      'un error en la página N conserva las anteriores y se puede reintentar',
      () async {
        final repo = FakeSearchRepository();
        final c = containerWith(repo);
        final ctrl = c.read(searchResultsControllerProvider.notifier)
          ..submit('valvula');
        repo.searchCalls.single.ok(
          pageOf([product(1)], hasMore: true, total: 2),
        );
        await flush();

        final first = ctrl.loadMore();
        repo.searchCalls.last.fail(const NoConnection());
        await first;
        var listing =
            (c.read(searchResultsControllerProvider).ui
                    as UiData<SearchListing>)
                .value;
        expect(listing.items.map((p) => p.id), [1]);
        expect(listing.loadMoreFailure, isA<NoConnection>());
        expect(listing.isLoadingMore, isFalse);
        expect(listing.hasMore, isTrue);

        final retry = ctrl.loadMore();
        repo.searchCalls.last.ok(pageOf([product(2)], page: 2, total: 2));
        await retry;
        listing =
            (c.read(searchResultsControllerProvider).ui
                    as UiData<SearchListing>)
                .value;
        expect(listing.items.map((p) => p.id), [1, 2]);
        expect(listing.loadMoreFailure, isNull);
      },
    );

    test('AC-021-2 · una búsqueda nueva descarta la respuesta tardía de la anterior', () async {
      final repo = FakeSearchRepository();
      final c = containerWith(repo);
      final ctrl = c.read(searchResultsControllerProvider.notifier)
        ..submit('uno');
      final first = repo.searchCalls.single;
      ctrl.submit('dos');
      final second = repo.searchCalls.last;
      expect(first.cancellation!.isCancelled, isTrue);
      expect(second.cancellation!.isCancelled, isFalse);

      second.ok(pageOf([product(2)]));
      await flush();
      first.ok(pageOf([product(1)])); // llega tarde
      await flush();
      final state = c.read(searchResultsControllerProvider);
      expect(state.query, 'dos');
      expect((state.ui as UiData<SearchListing>).value.items.single.id, 2);
    });

    test('loadMore en vuelo se descarta si se lanza otra búsqueda', () async {
      final repo = FakeSearchRepository();
      final c = containerWith(repo);
      final ctrl = c.read(searchResultsControllerProvider.notifier)
        ..submit('uno');
      repo.searchCalls.single.ok(pageOf([product(1)], hasMore: true, total: 9));
      await flush();
      final more = ctrl.loadMore();
      final stalePage = repo.searchCalls.last;
      ctrl.submit('dos');
      repo.searchCalls.last.ok(pageOf([product(7)]));
      await flush();
      stalePage.ok(pageOf([product(2)], page: 2));
      await more;
      final listing =
          (c.read(searchResultsControllerProvider).ui as UiData<SearchListing>)
              .value;
      expect(listing.items.map((p) => p.id), [7]);
    });

    test('clear vuelve al reposo y cancela lo pendiente', () async {
      final repo = FakeSearchRepository();
      final c = containerWith(repo);
      final ctrl = c.read(searchResultsControllerProvider.notifier)
        ..submit('uno');
      final call = repo.searchCalls.single;
      ctrl.clear();
      expect(call.cancellation!.isCancelled, isTrue);
      call.ok(pageOf([product(1)]));
      await flush();
      expect(c.read(searchResultsControllerProvider).isIdle, isTrue);
    });

    test('salir de la pantalla (dispose) cancela la petición en vuelo', () {
      final repo = FakeSearchRepository();
      final container = ProviderContainer(
        overrides: [searchRepositoryProvider.overrideWithValue(repo)],
      );
      final sub = container.listen(searchResultsControllerProvider, (_, _) {});
      container.read(searchResultsControllerProvider.notifier).submit('uno');
      final call = repo.searchCalls.single;
      sub.close();
      container.dispose();
      expect(call.cancellation!.isCancelled, isTrue);
      call.ok(pageOf([product(1)])); // no debe fallar tras el dispose
    });

    test('retry sin consulta previa no hace nada', () {
      final repo = FakeSearchRepository();
      final c = containerWith(repo);
      c.read(searchResultsControllerProvider.notifier).retry();
      expect(repo.searchCalls, isEmpty);
    });
  });

  group('M1 · RF-021 · SearchSuggestionsController', () {
    testWidgets(
      'AC-021-1 · debounce de 300 ms: nada antes, una petición después',
      (tester) async {
        final repo = FakeSearchRepository();
        final c = containerWith(repo);
        c
            .read(searchSuggestionsControllerProvider.notifier)
            .onTextChanged('val');
        await tester.pump(const Duration(milliseconds: 299));
        expect(repo.suggestionCalls, isEmpty);
        expect(c.read(searchSuggestionsControllerProvider).loading, isTrue);
        await tester.pump(const Duration(milliseconds: 1));
        expect(repo.suggestionCalls.single.query, 'val');
        repo.suggestionCalls.single.ok([
          suggestion(1),
          suggestion(2),
        ], total: 12);
        await tester.pump();
        final state = c.read(searchSuggestionsControllerProvider);
        expect(state.loading, isFalse);
        expect(state.items, hasLength(2));
        expect(state.total, 12);
        expect(state.query, 'val');
      },
    );

    testWidgets('escribir de nuevo reinicia el debounce: una sola petición', (
      tester,
    ) async {
      final repo = FakeSearchRepository();
      final c = containerWith(repo);
      final ctrl = c.read(searchSuggestionsControllerProvider.notifier)
        ..onTextChanged('va');
      await tester.pump(const Duration(milliseconds: 200));
      ctrl.onTextChanged('val');
      await tester.pump(const Duration(milliseconds: 200));
      expect(repo.suggestionCalls, isEmpty);
      await tester.pump(const Duration(milliseconds: 100));
      expect(repo.suggestionCalls.map((x) => x.query), ['val']);
    });

    testWidgets('mínimo 2 caracteres: con 0 o 1 no hay petición', (
      tester,
    ) async {
      final repo = FakeSearchRepository();
      final c = containerWith(repo);
      final ctrl = c.read(searchSuggestionsControllerProvider.notifier)
        ..onTextChanged('a')
        ..onTextChanged('  ')
        ..onTextChanged('');
      await tester.pump(const Duration(seconds: 1));
      expect(repo.suggestionCalls, isEmpty);
      expect(c.read(searchSuggestionsControllerProvider).items, isEmpty);
      // Un espacio final no cuenta como cambio relevante.
      ctrl
        ..onTextChanged('ab')
        ..onTextChanged('ab ');
      await tester.pump(const Duration(seconds: 1));
      expect(repo.suggestionCalls, hasLength(1));
    });

    testWidgets(
      'AC-021-2 · la respuesta de "ab" llega después que la de "abc": solo "abc"',
      (tester) async {
        final repo = FakeSearchRepository();
        final c = containerWith(repo);
        final ctrl = c.read(searchSuggestionsControllerProvider.notifier)
          ..onTextChanged('ab');
        await tester.pump(SearchSuggestionsController.debounce);
        final ab = repo.suggestionCalls.single;
        ctrl.onTextChanged('abc');
        // La petición anterior se cancela al seguir escribiendo.
        expect(ab.cancellation!.isCancelled, isTrue);
        await tester.pump(SearchSuggestionsController.debounce);
        final abc = repo.suggestionCalls.last;
        expect(abc.query, 'abc');

        abc.ok([suggestion(3)]);
        await tester.pump();
        ab.ok([suggestion(1), suggestion(2)]); // llega tarde
        await tester.pump();
        final state = c.read(searchSuggestionsControllerProvider);
        expect(state.query, 'abc');
        expect(state.items.map((s) => s.id), [3]);
      },
    );

    testWidgets('AC-021-4 · si el servicio falla: lista vacía, sin error', (
      tester,
    ) async {
      final repo = FakeSearchRepository();
      final c = containerWith(repo);
      c.read(searchSuggestionsControllerProvider.notifier).onTextChanged('val');
      await tester.pump(SearchSuggestionsController.debounce);
      repo.suggestionCalls.single.fail(const ServiceUnavailable());
      await tester.pump();
      final state = c.read(searchSuggestionsControllerProvider);
      expect(state.items, isEmpty);
      expect(state.total, isNull);
      expect(state.loading, isFalse);
    });

    testWidgets('AC-021-5 · borrar el texto quita las sugerencias y cancela', (
      tester,
    ) async {
      final repo = FakeSearchRepository();
      final c = containerWith(repo);
      final ctrl = c.read(searchSuggestionsControllerProvider.notifier)
        ..onTextChanged('val');
      await tester.pump(SearchSuggestionsController.debounce);
      final call = repo.suggestionCalls.single;
      ctrl.onTextChanged('');
      expect(call.cancellation!.isCancelled, isTrue);
      call.ok([suggestion(1)]);
      await tester.pump();
      final state = c.read(searchSuggestionsControllerProvider);
      expect(state.items, isEmpty);
      expect(state.query, isEmpty);
    });

    testWidgets('dispose cancela el temporizador pendiente', (tester) async {
      final repo = FakeSearchRepository();
      final container = ProviderContainer(
        overrides: [searchRepositoryProvider.overrideWithValue(repo)],
      );
      final sub = container.listen(
        searchSuggestionsControllerProvider,
        (_, _) {},
      );
      container
          .read(searchSuggestionsControllerProvider.notifier)
          .onTextChanged('val');
      sub.close();
      container.dispose();
      await tester.pump(const Duration(seconds: 1));
      expect(repo.suggestionCalls, isEmpty);
    });

    testWidgets(
      'dispose cancela la petición en vuelo y descarta su respuesta',
      (tester) async {
        final repo = FakeSearchRepository();
        final container = ProviderContainer(
          overrides: [searchRepositoryProvider.overrideWithValue(repo)],
        );
        final sub = container.listen(
          searchSuggestionsControllerProvider,
          (_, _) {},
        );
        container
            .read(searchSuggestionsControllerProvider.notifier)
            .onTextChanged('val');
        await tester.pump(SearchSuggestionsController.debounce);
        final call = repo.suggestionCalls.single;
        sub.close();
        container.dispose();
        expect(call.cancellation!.isCancelled, isTrue);
        call.ok([suggestion(1)]); // no debe fallar tras el dispose
        await tester.pump();
      },
    );

    test('clear sin estado previo no cambia nada', () {
      final repo = FakeSearchRepository();
      final c = containerWith(repo);
      c.read(searchSuggestionsControllerProvider.notifier).clear();
      expect(c.read(searchSuggestionsControllerProvider).items, isEmpty);
    });
  });
}
