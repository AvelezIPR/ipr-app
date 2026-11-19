import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/home/domain/entities/home_brand.dart';
import 'package:ipr_mobile/features/home/domain/entities/home_category.dart';
import 'package:ipr_mobile/features/home/domain/entities/section_data.dart';
import 'package:ipr_mobile/features/home/domain/repositories/home_repository.dart';
import 'package:ipr_mobile/features/home/home_providers.dart';
import 'package:ipr_mobile/shared/domain/product_summary.dart';
import 'package:ipr_mobile/shared/widgets/ui_state.dart';

/// Controlador de UNA sección del inicio. Cada sección tiene su propio estado:
/// que una falle no afecta a las demás (AC-003-4, AC-002-3).
///
/// Estado: [UiLoading] → [UiData] (con `stale` si son datos guardados) ·
/// [UiEmpty] (solo si el servidor respondió 200 con lista vacía) ·
/// [UiFailure] (fallo de red/servidor sin caché).
abstract class HomeSectionController<T> extends Notifier<UiState<List<T>>> {
  /// Pide la sección al repositorio.
  Future<Result<SectionData<List<T>>>> fetch(
    HomeRepository repository, {
    required bool forceRefresh,
  });

  int _generation = 0;

  @override
  UiState<List<T>> build() {
    unawaited(Future<void>.microtask(load));
    return UiLoading<List<T>>();
  }

  /// Carga la sección. [forceRefresh] ignora la caché vigente (pull-to-refresh
  /// y "Reintentar"). Con datos ya visibles, el refresco no los reemplaza por
  /// un indicador de carga: solo [UiLoading] si no había nada.
  Future<void> load({bool forceRefresh = false}) async {
    final generation = ++_generation;
    if (state is UiFailure<List<T>>) state = UiLoading<List<T>>();
    final result = await fetch(
      ref.read(homeRepositoryProvider),
      forceRefresh: forceRefresh,
    );
    // Una carga más nueva o un controlador ya descartado no pisan el estado.
    if (!ref.mounted || generation != _generation) return;
    state = switch (result) {
      Ok<SectionData<List<T>>>(:final value) =>
        value.value.isEmpty
            ? UiEmpty<List<T>>()
            : UiData<List<T>>(value.value, stale: value.stale),
      Err<SectionData<List<T>>>(:final failure) => switch (state) {
        // Con datos ya en pantalla, un fallo al refrescar los conserva como
        // obsoletos en lugar de borrarlos.
        UiData<List<T>>(:final value) => UiData<List<T>>(value, stale: true),
        _ => UiFailure<List<T>>(failure),
      },
    };
  }
}

class HomeCategoriesController extends HomeSectionController<HomeCategory> {
  @override
  Future<Result<SectionData<List<HomeCategory>>>> fetch(
    HomeRepository repository, {
    required bool forceRefresh,
  }) => repository.categories(forceRefresh: forceRefresh);
}

class HomeBrandsController extends HomeSectionController<HomeBrand> {
  @override
  Future<Result<SectionData<List<HomeBrand>>>> fetch(
    HomeRepository repository, {
    required bool forceRefresh,
  }) => repository.brands(forceRefresh: forceRefresh);
}

class HomeFeaturedController extends HomeSectionController<ProductSummary> {
  @override
  Future<Result<SectionData<List<ProductSummary>>>> fetch(
    HomeRepository repository, {
    required bool forceRefresh,
  }) => repository.featuredProducts(forceRefresh: forceRefresh);
}

final homeCategoriesProvider =
    NotifierProvider<HomeCategoriesController, UiState<List<HomeCategory>>>(
      HomeCategoriesController.new,
    );

final homeBrandsProvider =
    NotifierProvider<HomeBrandsController, UiState<List<HomeBrand>>>(
      HomeBrandsController.new,
    );

final homeFeaturedProvider =
    NotifierProvider<HomeFeaturedController, UiState<List<ProductSummary>>>(
      HomeFeaturedController.new,
    );

/// Recarga las tres secciones saltando la caché vigente (pull-to-refresh).
/// Cada una es independiente: un fallo no interrumpe a las otras.
Future<void> refreshHome(WidgetRef ref) => Future.wait([
  ref.read(homeCategoriesProvider.notifier).load(forceRefresh: true),
  ref.read(homeBrandsProvider.notifier).load(forceRefresh: true),
  ref.read(homeFeaturedProvider.notifier).load(forceRefresh: true),
]);
