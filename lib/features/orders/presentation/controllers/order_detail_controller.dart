import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;
import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/orders/domain/entities/order_entities.dart';
import 'package:ipr_mobile/features/orders/orders_providers.dart';
import 'package:ipr_mobile/shared/widgets/ui_state.dart';

/// Controlador del detalle de un pedido (`GET /orders/{orderId}`, RF-108).
final NotifierProviderFamily<OrderDetailController, UiState<OrderDetail>, int>
orderDetailProvider = NotifierProvider.autoDispose
    .family<OrderDetailController, UiState<OrderDetail>, int>(
      OrderDetailController.new,
    );

class OrderDetailController extends Notifier<UiState<OrderDetail>> {
  new(this.orderId);

  final int orderId;
  RequestCancellation _cancel = RequestCancellation();
  int _generation = 0;

  @override
  UiState<OrderDetail> build() {
    ref.onDispose(() => _cancel.cancel());
    unawaited(Future.microtask(load));
    return const UiLoading();
  }

  Future<void> load() async {
    _cancel.cancel();
    _cancel = RequestCancellation();
    final generation = ++_generation;
    state = const UiLoading();
    final result = await ref
        .read(ordersRepositoryProvider)
        .getOrder(orderId, cancellation: _cancel);
    if (!ref.mounted || generation != _generation) return;
    state = switch (result) {
      Ok<OrderDetail>(:final value) => UiData(value),
      Err<OrderDetail>(:final failure) => UiFailure(failure),
    };
  }
}
