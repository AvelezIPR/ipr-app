import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/orders/domain/entities/order_entities.dart';
import 'package:ipr_mobile/features/orders/domain/repositories/orders_repository.dart';
import 'package:ipr_mobile/features/orders/orders_providers.dart';
import 'package:ipr_mobile/shared/widgets/ui_state.dart';
import 'package:meta/meta.dart';

/// Datos cargados del historial de pedidos con paginación infinita.
@immutable
final class OrdersListData {
  const new({
    required this.items,
    required this.hasMore,
    this.nextPage = 2,
    this.loadingMore = false,
    this.refreshing = false,
    this.pageFailure,
  });

  final List<OrderSummary> items;
  final bool hasMore;
  final int nextPage;
  final bool loadingMore;
  final bool refreshing;

  /// Error al cargar la página [nextPage]: las páginas anteriores se conservan.
  final AppFailure? pageFailure;

  OrdersListData copyWith({
    List<OrderSummary>? items,
    bool? hasMore,
    int? nextPage,
    bool? loadingMore,
    bool? refreshing,
    AppFailure? pageFailure,
    bool clearPageFailure = false,
  }) => OrdersListData(
    items: items ?? this.items,
    hasMore: hasMore ?? this.hasMore,
    nextPage: nextPage ?? this.nextPage,
    loadingMore: loadingMore ?? this.loadingMore,
    refreshing: refreshing ?? this.refreshing,
    pageFailure: clearPageFailure ? null : (pageFailure ?? this.pageFailure),
  );
}

final NotifierProvider<OrdersListController, UiState<OrdersListData>>
ordersListProvider =
    NotifierProvider.autoDispose<OrdersListController, UiState<OrdersListData>>(
      OrdersListController.new,
    );

/// Controlador del historial paginado de pedidos (`GET /orders`, RF-107).
///
/// * Estado solo en memoria (`autoDispose`, RNF-062).
/// * Cancelación en vuelo al salir de la pantalla.
/// * Paginación sin duplicados; error en página >= 2 conserva lo ya cargado.
class OrdersListController extends Notifier<UiState<OrdersListData>> {
  RequestCancellation _cancel = RequestCancellation();
  int _generation = 0;

  @override
  UiState<OrdersListData> build() {
    ref.onDispose(() => _cancel.cancel());
    unawaited(Future.microtask(_loadFirst));
    return const UiLoading();
  }

  Future<void> _loadFirst() async {
    _cancel.cancel();
    _cancel = RequestCancellation();
    final generation = ++_generation;
    state = const UiLoading();
    final result = await ref
        .read(ordersRepositoryProvider)
        .listOrders(cancellation: _cancel);
    if (!ref.mounted || generation != _generation) return;
    switch (result) {
      case Ok<OrderPage>(:final value):
        if (value.items.isEmpty) {
          state = const UiEmpty();
        } else {
          state = UiData(
            OrdersListData(
              items: _dedupe(const [], value.items),
              hasMore: _canLoadMore(value, requested: 1),
            ),
          );
        }
      case Err<OrderPage>(:final failure):
        state = UiFailure(failure);
    }
  }

  Future<void> reload() => _loadFirst();

  Future<void> refresh() async {
    final current = state;
    if (current is! UiData<OrdersListData>) {
      await _loadFirst();
      return;
    }
    _cancel.cancel();
    _cancel = RequestCancellation();
    final generation = ++_generation;
    state = UiData(
      current.value.copyWith(
        refreshing: true,
        loadingMore: false,
        clearPageFailure: true,
      ),
    );
    final result = await ref
        .read(ordersRepositoryProvider)
        .listOrders(cancellation: _cancel);
    if (!ref.mounted || generation != _generation) return;
    switch (result) {
      case Ok<OrderPage>(:final value):
        if (value.items.isEmpty) {
          state = const UiEmpty();
        } else {
          state = UiData(
            OrdersListData(
              items: _dedupe(const [], value.items),
              hasMore: _canLoadMore(value, requested: 1),
            ),
          );
        }
      case Err<OrderPage>(:final failure):
        state = UiData(
          current.value.copyWith(refreshing: false, pageFailure: failure),
        );
    }
  }

  Future<void> loadMore({bool retry = false}) async {
    final current = state;
    if (current is! UiData<OrdersListData>) return;
    final data = current.value;
    if (data.loadingMore || data.refreshing || !data.hasMore) return;
    if (data.pageFailure != null && !retry) return;

    final generation = _generation;
    final page = data.nextPage;
    state = UiData(data.copyWith(loadingMore: true, clearPageFailure: true));
    final result = await ref
        .read(ordersRepositoryProvider)
        .listOrders(page: page, cancellation: _cancel);
    if (!ref.mounted || generation != _generation) return;
    final latest = state;
    if (latest is! UiData<OrdersListData>) return;

    switch (result) {
      case Ok<OrderPage>(:final value):
        final merged = _dedupe(latest.value.items, value.items);
        final added = merged.length - latest.value.items.length;
        final hasMore = _canLoadMore(value, requested: page);
        state = UiData(
          latest.value.copyWith(
            items: merged,
            hasMore: hasMore,
            nextPage: page + 1,
            loadingMore: false,
          ),
        );
        if (added == 0 && hasMore) await loadMore();
      case Err<OrderPage>(:final failure):
        state = UiData(
          latest.value.copyWith(loadingMore: false, pageFailure: failure),
        );
    }
  }

  static bool _canLoadMore(OrderPage page, {required int requested}) =>
      page.hasMore &&
      page.items.isNotEmpty &&
      requested < OrdersRepository.maxPage;

  static List<OrderSummary> _dedupe(
    List<OrderSummary> existing,
    List<OrderSummary> incoming,
  ) {
    final seen = {for (final o in existing) o.id};
    return [
      ...existing,
      for (final o in incoming)
        if (seen.add(o.id)) o,
    ];
  }
}
