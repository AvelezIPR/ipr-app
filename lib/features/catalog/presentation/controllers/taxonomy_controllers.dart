import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show NotifierProviderFamily;
import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/catalog/catalog_providers.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/brand.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/category_node.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/filter_dimension.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/product_page.dart';
import 'package:ipr_mobile/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:ipr_mobile/shared/widgets/ui_state.dart';

/// Carga una lista de taxonomía (categorías, marcas o filtros) con caché SWR.
/// `UiEmpty` solo si el servidor respondió 200 con lista vacía; un fallo sin
/// dato guardado es `UiFailure` (nunca "vacío").
abstract class TaxonomyController<T> extends Notifier<UiState<List<T>>> {
  final RequestCancellation _cancel = RequestCancellation();
  int _generation = 0;

  Future<Result<Cached<List<T>>>> fetch(
    CatalogRepository repository, {
    required bool forceRefresh,
    required RequestCancellation cancel,
  });

  @override
  UiState<List<T>> build() {
    ref.onDispose(_cancel.cancel);
    unawaited(Future.microtask(load));
    return const UiLoading();
  }

  /// Carga (o recarga). Con [forceRefresh] se ignora el dato vigente.
  Future<void> load({bool forceRefresh = false}) async {
    final generation = ++_generation;
    if (state is! UiData<List<T>>) state = const UiLoading();
    final result = await fetch(
      ref.read(catalogRepositoryProvider),
      forceRefresh: forceRefresh,
      cancel: _cancel,
    );
    if (!ref.mounted || generation != _generation) return;
    state = switch (result) {
      Ok<Cached<List<T>>>(:final value) =>
        value.value.isEmpty
            ? const UiEmpty()
            : UiData(value.value, stale: value.stale),
      Err<Cached<List<T>>>(:final failure) => UiFailure(failure),
    };
  }

  /// "Reintentar" tras un fallo.
  Future<void> retry() {
    state = const UiLoading();
    return load(forceRefresh: true);
  }
}

/// Árbol de categorías (pestaña Catálogo y filtro de categoría).
class CategoriesController extends TaxonomyController<CategoryNode> {
  @override
  Future<Result<Cached<List<CategoryNode>>>> fetch(
    CatalogRepository repository, {
    required bool forceRefresh,
    required RequestCancellation cancel,
  }) => repository.categories(forceRefresh: forceRefresh, cancel: cancel);
}

final categoriesProvider =
    NotifierProvider<CategoriesController, UiState<List<CategoryNode>>>(
      CategoriesController.new,
    );

/// Directorio de marcas.
class BrandsController extends TaxonomyController<Brand> {
  @override
  Future<Result<Cached<List<Brand>>>> fetch(
    CatalogRepository repository, {
    required bool forceRefresh,
    required RequestCancellation cancel,
  }) => repository.brands(forceRefresh: forceRefresh, cancel: cancel);
}

final brandsProvider = NotifierProvider<BrandsController, UiState<List<Brand>>>(
  BrandsController.new,
);

/// Dimensiones de filtro de una categoría (`null` = sin categoría).
class FilterDimensionsController extends TaxonomyController<FilterDimension> {
  new(this.categorySlug);

  final String? categorySlug;

  @override
  Future<Result<Cached<List<FilterDimension>>>> fetch(
    CatalogRepository repository, {
    required bool forceRefresh,
    required RequestCancellation cancel,
  }) => repository.filters(
    categorySlug: categorySlug,
    forceRefresh: forceRefresh,
    cancel: cancel,
  );
}

final NotifierProviderFamily<
  FilterDimensionsController,
  UiState<List<FilterDimension>>,
  String?
>
filterDimensionsProvider = NotifierProvider.autoDispose
    .family<
      FilterDimensionsController,
      UiState<List<FilterDimension>>,
      String?
    >(FilterDimensionsController.new);
