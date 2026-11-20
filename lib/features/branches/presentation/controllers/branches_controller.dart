import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderFamily;
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/branches/branches_providers.dart';
import 'package:ipr_mobile/features/branches/domain/entities/branch.dart';
import 'package:ipr_mobile/features/branches/domain/repositories/branches_repository.dart';
import 'package:ipr_mobile/shared/widgets/ui_state.dart';

final NotifierProvider<BranchesController, UiState<List<Branch>>>
branchesProvider =
    NotifierProvider.autoDispose<BranchesController, UiState<List<Branch>>>(
      BranchesController.new,
    );

/// Listado completo de sedes (`GET /stores`, RF-072, RF-076).
class BranchesController extends Notifier<UiState<List<Branch>>> {
  final RequestCancellation _cancel = RequestCancellation();
  int _generation = 0;

  @override
  UiState<List<Branch>> build() {
    ref.onDispose(_cancel.cancel);
    unawaited(Future.microtask(load));
    return const UiLoading();
  }

  Future<void> load({bool forceRefresh = false}) async {
    final generation = ++_generation;
    if (forceRefresh || state is! UiData<List<Branch>>) {
      state = const UiLoading();
    }
    final result = await ref
        .read(branchesRepositoryProvider)
        .stores(forceRefresh: forceRefresh, cancel: _cancel);
    if (!ref.mounted || generation != _generation) return;
    state = switch (result) {
      Ok<BranchesSnapshot>(:final value) => UiData(
        value.branches,
        stale: value.stale,
      ),
      Err<BranchesSnapshot>(:final failure) => UiFailure(failure),
    };
  }

  Future<void> retry() => load(forceRefresh: true);

  Future<void> refresh() => load(forceRefresh: true);
}

/// Ficha de una sede concreta buscada por `slug` dentro de [branchesProvider].
final ProviderFamily<UiState<Branch>, String> branchBySlugProvider = Provider
    .autoDispose
    .family<UiState<Branch>, String>((ref, slug) {
      final listState = ref.watch(branchesProvider);
      return switch (listState) {
        UiLoading<List<Branch>>() => const UiLoading(),
        UiEmpty<List<Branch>>() => const UiEmpty(),
        UiFailure<List<Branch>>(:final failure) => UiFailure(failure),
        UiData<List<Branch>>(:final value, :final stale) => () {
          for (final branch in value) {
            if (branch.slug == slug) {
              return UiData(branch, stale: stale);
            }
          }
          return const UiFailure<Branch>(NotFound());
        }(),
      };
    });
