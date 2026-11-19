import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/catalog/catalog_providers.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/product_filters.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/product_page.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/product_query.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/product_sort.dart';
import 'package:ipr_mobile/shared/domain/product_summary.dart';
import 'package:ipr_mobile/shared/widgets/ui_state.dart';
import 'package:meta/meta.dart';

/// Datos de un listado cargado. Un listado **vacío** (200 sin productos) es
/// un `ProductListData` con `items` vacío: la pantalla conserva la barra de
/// filtros para poder "Limpiar filtros" (AC-013-4).
@immutable
final class ProductListData {
  const new({
    required this.filters,
    required this.items,
    required this.hasMore,
    this.total,
    this.nextPage = 2,
    this.loadingMore = false,
    this.refreshing = false,
    this.pageFailure,
    this.applyFailure,
    this.pendingFilters,
  });

  /// Filtros con los que se cargaron [items] (los confirmados).
  final ProductFilters filters;
  final List<ProductSummary> items;
  final bool hasMore;

  /// Total del servidor; `null` si no lo informó.
  final int? total;
  final int nextPage;

  /// Cargando la página siguiente.
  final bool loadingMore;

  /// Aplicando filtros/orden o refrescando: se sigue mostrando [items].
  final bool refreshing;

  /// Falló la página [nextPage]: las anteriores se conservan (AC-009-5).
  final AppFailure? pageFailure;

  /// Falló aplicar [pendingFilters]: se conserva el listado y los filtros
  /// previos y se ofrece reintentar (AC-013-5, AC-009-7).
  final AppFailure? applyFailure;
  final ProductFilters? pendingFilters;

  /// Contador de resultados: el del servidor, o la cantidad cargada si ya no
  /// hay más páginas. `null` si aún no se sabe.
  int? get resultCount => total ?? (hasMore ? null : items.length);

  ProductListData copyWith({
    List<ProductSummary>? items,
    bool? hasMore,
    int? total,
    int? nextPage,
    bool? loadingMore,
    bool? refreshing,
    AppFailure? pageFailure,
    bool clearPageFailure = false,
    AppFailure? applyFailure,
    ProductFilters? pendingFilters,
    bool clearApplyFailure = false,
  }) => ProductListData(
    filters: filters,
    items: items ?? this.items,
    hasMore: hasMore ?? this.hasMore,
    total: total ?? this.total,
    nextPage: nextPage ?? this.nextPage,
    loadingMore: loadingMore ?? this.loadingMore,
    refreshing: refreshing ?? this.refreshing,
    pageFailure: clearPageFailure ? null : (pageFailure ?? this.pageFailure),
    applyFailure: clearApplyFailure
        ? null
        : (applyFailure ?? this.applyFailure),
    pendingFilters: clearApplyFailure
        ? null
        : (pendingFilters ?? this.pendingFilters),
  );
}

/// Listado paginado de productos de una categoría, una marca o liquidaciones.
///
/// * Paginación infinita: una sola solicitud por página, sin ids repetidos
///   (AC-011-2, AC-011-8) y sin más solicitudes tras la última (AC-011-3).
/// * Un fallo en la página N **no** borra las anteriores (AC-009-5).
/// * Cambiar filtros u orden recarga desde la página 1; si falla, se conservan
///   el listado y los filtros previos (AC-013-5, AC-015-2).
/// * Las respuestas de peticiones obsoletas se descartan por generación.
class ProductListController extends Notifier<UiState<ProductListData>> {
  new(this.scope);

  final ListScope scope;

  final RequestCancellation _cancel = RequestCancellation();
  int _generation = 0;
  ProductFilters _filters = ProductFilters.empty;

  /// Filtros vigentes (los confirmados, o los iniciales antes de cargar).
  ProductFilters get filters {
    final current = state;
    return current is UiData<ProductListData>
        ? current.value.filters
        : _filters;
  }

  @override
  UiState<ProductListData> build() {
    ref.onDispose(_cancel.cancel);
    unawaited(Future.microtask(_loadFirst));
    return const UiLoading();
  }

  Future<void> _loadFirst({bool forceRefresh = false}) async {
    final generation = ++_generation;
    state = const UiLoading();
    final result = await ref
        .read(catalogRepositoryProvider)
        .products(
          ProductQuery(scope: scope, filters: _filters),
          forceRefresh: forceRefresh,
          cancel: _cancel,
        );
    if (!ref.mounted || generation != _generation) return;
    state = switch (result) {
      Ok<Cached<ProductPage>>(:final value) => UiData(
        _fromFirstPage(value.value, _filters),
        stale: value.stale,
      ),
      Err<Cached<ProductPage>>(:final failure) => UiFailure(failure),
    };
  }

  ProductListData _fromFirstPage(ProductPage page, ProductFilters filters) {
    final items = _dedupe(const [], page.items);
    return ProductListData(
      filters: filters,
      items: items,
      hasMore: _hasMore(page, requested: 1),
      total: page.total,
    );
  }

  static bool _hasMore(ProductPage page, {required int requested}) =>
      page.hasMore && page.items.isNotEmpty && requested < ProductQuery.maxPage;

  /// Añade los productos de [incoming] que aún no están (por id).
  static List<ProductSummary> _dedupe(
    List<ProductSummary> existing,
    List<ProductSummary> incoming,
  ) {
    final seen = {for (final p in existing) p.id};
    return [
      ...existing,
      for (final p in incoming)
        if (seen.add(p.id)) p,
    ];
  }

  /// "Reintentar" tras fallar la primera carga.
  Future<void> reload() => _loadFirst(forceRefresh: true);

  /// Tirar para refrescar: vuelve a pedir la página 1 con los mismos filtros.
  Future<void> refresh() => applyFilters(filters, forceRefresh: true);

  /// Aplica [next] (filtros, orden o búsqueda) recargando desde la página 1.
  Future<void> applyFilters(
    ProductFilters next, {
    bool forceRefresh = false,
  }) async {
    final current = state;
    if (current is! UiData<ProductListData>) {
      _filters = next;
      await _loadFirst(forceRefresh: forceRefresh);
      return;
    }
    final generation = ++_generation;
    state = UiData(
      current.value.copyWith(
        refreshing: true,
        loadingMore: false,
        clearApplyFailure: true,
      ),
      stale: current.stale,
    );
    final result = await ref
        .read(catalogRepositoryProvider)
        .products(
          ProductQuery(scope: scope, filters: next),
          forceRefresh: forceRefresh,
          cancel: _cancel,
        );
    if (!ref.mounted || generation != _generation) return;
    switch (result) {
      case Ok<Cached<ProductPage>>(:final value):
        _filters = next;
        state = UiData(_fromFirstPage(value.value, next), stale: value.stale);
      case Err<Cached<ProductPage>>(:final failure):
        // Se conserva el listado y los filtros previos.
        state = UiData(
          current.value.copyWith(
            refreshing: false,
            loadingMore: false,
            applyFailure: failure,
            pendingFilters: next,
          ),
          stale: current.stale,
        );
    }
  }

  /// Reintenta aplicar los filtros que fallaron.
  Future<void> retryApply() {
    final current = state;
    final pending = current is UiData<ProductListData>
        ? current.value.pendingFilters
        : null;
    return applyFilters(pending ?? filters, forceRefresh: true);
  }

  Future<void> setSort(ProductSort sort) =>
      applyFilters(filters.withSort(sort));

  Future<void> removeChoice(FilterChoice choice) =>
      applyFilters(filters.without(choice));

  Future<void> removeCategory() => applyFilters(filters.withCategory(null));

  Future<void> clearFilters() => applyFilters(filters.cleared());

  /// Búsqueda interna de marca (RF-016); vacío la quita.
  Future<void> search(String? term) => applyFilters(filters.withSearch(term));

  /// Carga la página siguiente (una sola solicitud a la vez). Tras fallar una
  /// página no se reintenta sola: solo con [retry] (el botón del pie).
  Future<void> loadMore({bool retry = false}) async {
    final current = state;
    if (current is! UiData<ProductListData>) return;
    final data = current.value;
    if (data.loadingMore || data.refreshing || !data.hasMore) return;
    if (data.pageFailure != null && !retry) return;

    final generation = _generation;
    final page = data.nextPage;
    state = UiData(
      data.copyWith(loadingMore: true, clearPageFailure: true),
      stale: current.stale,
    );
    final result = await ref
        .read(catalogRepositoryProvider)
        .products(
          ProductQuery(scope: scope, filters: data.filters, page: page),
          cancel: _cancel,
        );
    if (!ref.mounted || generation != _generation) return;
    final latest = state;
    if (latest is! UiData<ProductListData>) return;

    switch (result) {
      case Ok<Cached<ProductPage>>(:final value):
        final merged = _dedupe(latest.value.items, value.value.items);
        final added = merged.length - latest.value.items.length;
        final hasMore = _hasMore(value.value, requested: page);
        state = UiData(
          latest.value.copyWith(
            items: merged,
            hasMore: hasMore,
            total: value.value.total,
            nextPage: page + 1,
            loadingMore: false,
          ),
          stale: latest.stale || value.stale,
        );
        // Página sin productos nuevos (ids repetidos): se sigue pidiendo para
        // no dejar la lista sin avanzar (AC-011-8).
        if (added == 0 && hasMore) await loadMore();
      case Err<Cached<ProductPage>>(:final failure):
        state = UiData(
          latest.value.copyWith(loadingMore: false, pageFailure: failure),
          stale: latest.stale,
        );
    }
  }
}

/// Un controlador por contexto de listado; se libera al salir de la pantalla.
final NotifierProviderFamily<
  ProductListController,
  UiState<ProductListData>,
  ListScope
>
productListProvider = NotifierProvider.autoDispose
    .family<ProductListController, UiState<ProductListData>, ListScope>(
      ProductListController.new,
    );
