import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;
import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/product_detail/domain/entities/product_detail.dart';
import 'package:ipr_mobile/features/product_detail/product_detail_providers.dart';
import 'package:ipr_mobile/shared/widgets/ui_state.dart';

/// Estado de la ficha de un producto (por slug). Se libera al salir de la
/// pantalla (`autoDispose`); la caché la gestiona el repositorio.
final NotifierProviderFamily<
  ProductDetailController,
  UiState<ProductDetail>,
  String
>
productDetailControllerProvider = NotifierProvider.autoDispose
    .family<ProductDetailController, UiState<ProductDetail>, String>(
      ProductDetailController.new,
    );

class ProductDetailController extends Notifier<UiState<ProductDetail>> {
  new(this.slug);

  final String slug;

  RequestCancellation? _inFlight;

  @override
  UiState<ProductDetail> build() {
    // Al salir de la pantalla se aborta la petición en vuelo.
    ref.onDispose(() => _inFlight?.cancel());
    unawaited(Future.microtask(_load));
    return const UiLoading();
  }

  /// Vuelve a pedir la ficha ignorando la caché vigente ("Reintentar").
  Future<void> retry() async {
    state = const UiLoading();
    await _load(forceRefresh: true);
  }

  Future<void> _load({bool forceRefresh = false}) async {
    if (!ref.mounted) return;
    _inFlight?.cancel();
    final cancellation = _inFlight = RequestCancellation();
    final repository = ref.read(productDetailRepositoryProvider);
    final result = await repository.load(
      slug,
      forceRefresh: forceRefresh,
      cancellation: cancellation,
    );
    // Una petición cancelada (otra nueva o salida de pantalla) no escribe.
    if (!ref.mounted || cancellation.isCancelled) return;
    state = switch (result) {
      Ok(:final value) => UiData(value.product, stale: value.stale),
      Err(:final failure) => UiFailure(failure),
    };
  }
}
