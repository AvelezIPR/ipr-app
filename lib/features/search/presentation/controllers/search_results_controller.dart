import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/search/domain/entities/search_page.dart';
import 'package:ipr_mobile/features/search/domain/entities/search_query.dart';
import 'package:ipr_mobile/features/search/search_providers.dart';
import 'package:ipr_mobile/shared/domain/product_summary.dart';
import 'package:ipr_mobile/shared/widgets/ui_state.dart';
import 'package:meta/meta.dart';

/// Resultados acumulados de una búsqueda (paginación infinita, AC-011-2/3).
@immutable
final class SearchListing {
  const new({
    required this.items,
    required this.page,
    required this.hasMore,
    required this.total,
    this.isLoadingMore = false,
    this.loadMoreFailure,
  });

  final List<ProductSummary> items;
  final int page;
  final bool hasMore;
  final int total;
  final bool isLoadingMore;

  /// Falló la carga de la página siguiente: las anteriores se conservan y se
  /// ofrece "Reintentar".
  final AppFailure? loadMoreFailure;

  SearchListing copyWith({
    List<ProductSummary>? items,
    int? page,
    bool? hasMore,
    int? total,
    bool? isLoadingMore,
    AppFailure? loadMoreFailure,
    bool clearFailure = false,
  }) => SearchListing(
    items: items ?? this.items,
    page: page ?? this.page,
    hasMore: hasMore ?? this.hasMore,
    total: total ?? this.total,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    loadMoreFailure: clearFailure
        ? null
        : (loadMoreFailure ?? this.loadMoreFailure),
  );
}

/// Estado de la búsqueda enviada. [query] es el texto normalizado que se
/// buscó (dato del usuario: solo en memoria, jamás en logs ni analítica).
///
/// * `query` vacío → aún no se ha buscado (reposo).
/// * [UiEmpty] **solo** si el servidor respondió 200 con lista vacía.
/// * Un fallo de red o de servidor es [UiFailure], nunca [UiEmpty] (AC-023-5).
@immutable
final class SearchResultsState {
  const new({required this.query, required this.ui});

  const new idle() : query = '', ui = const UiLoading();

  final String query;
  final UiState<SearchListing> ui;

  bool get isIdle => query.isEmpty;
}

final NotifierProvider<SearchResultsController, SearchResultsState>
searchResultsControllerProvider =
    NotifierProvider.autoDispose<SearchResultsController, SearchResultsState>(
      SearchResultsController.new,
    );

/// Controlador de resultados (RF-020, RF-022, RF-023).
class SearchResultsController extends Notifier<SearchResultsState> {
  RequestCancellation? _inflight;

  /// Se incrementa con cada búsqueda nueva o cancelación: toda respuesta de
  /// una generación anterior se descarta (nunca pisa a la más reciente).
  int _generation = 0;

  @override
  SearchResultsState build() {
    ref.onDispose(_cancelInflight);
    return const SearchResultsState.idle();
  }

  /// Busca [raw]. Devuelve `false` (sin petición) si, normalizado, queda
  /// vacío (AC-020-3).
  bool submit(String raw) {
    final query = SearchQuery.normalize(raw);
    if (query.isEmpty) return false;
    unawaited(_runFirstPage(query));
    return true;
  }

  /// Repite la búsqueda actual (error o "volver a buscar").
  void retry() {
    final query = state.query;
    if (query.isNotEmpty) unawaited(_runFirstPage(query));
  }

  /// Vuelve al reposo y cancela lo que esté en vuelo.
  void clear() {
    _cancelInflight();
    state = const SearchResultsState.idle();
  }

  /// Pide la página siguiente. Un fallo conserva las páginas anteriores.
  Future<void> loadMore() async {
    final current = state.ui;
    if (current is! UiData<SearchListing>) return;
    final listing = current.value;
    if (!listing.hasMore || listing.isLoadingMore) return;

    final query = state.query;
    final generation = _generation;
    final cancellation = _newCancellation();
    state = SearchResultsState(
      query: query,
      ui: UiData(listing.copyWith(isLoadingMore: true, clearFailure: true)),
    );
    final result = await ref
        .read(searchRepositoryProvider)
        .search(query, page: listing.page + 1, cancellation: cancellation);
    if (!_isCurrent(generation)) return;

    final ui = switch (result) {
      Ok<SearchPage>(:final value) => UiData(_append(listing, value)),
      Err<SearchPage>(:final failure) => UiData(
        listing.copyWith(isLoadingMore: false, loadMoreFailure: failure),
      ),
    };
    state = SearchResultsState(query: query, ui: ui);
  }

  SearchListing _append(SearchListing listing, SearchPage next) {
    final known = {for (final p in listing.items) p.id};
    return SearchListing(
      items: [
        ...listing.items,
        for (final p in next.items)
          if (!known.contains(p.id)) p,
      ],
      page: next.page,
      hasMore: next.hasMore,
      total: next.total,
    );
  }

  Future<void> _runFirstPage(String query) async {
    final generation = ++_generation;
    final cancellation = _newCancellation();
    state = SearchResultsState(query: query, ui: const UiLoading());
    final result = await ref
        .read(searchRepositoryProvider)
        .search(query, cancellation: cancellation);
    if (!_isCurrent(generation)) return;

    final ui = switch (result) {
      Ok<SearchPage>(:final value) when value.items.isEmpty =>
        const UiEmpty<SearchListing>(),
      Ok<SearchPage>(:final value) => UiData(
        SearchListing(
          items: value.items,
          page: value.page,
          hasMore: value.hasMore,
          total: value.total,
        ),
      ),
      Err<SearchPage>(:final failure) => UiFailure<SearchListing>(failure),
    };
    state = SearchResultsState(query: query, ui: ui);
  }

  /// Cancela la petición anterior y crea la de la petición actual.
  RequestCancellation _newCancellation() {
    _inflight?.cancel();
    return _inflight = RequestCancellation();
  }

  void _cancelInflight() {
    _generation++;
    _inflight?.cancel();
    _inflight = null;
  }

  bool _isCurrent(int generation) => ref.mounted && generation == _generation;
}
