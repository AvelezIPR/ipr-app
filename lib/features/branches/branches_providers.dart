import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ipr_mobile/core/providers.dart';
import 'package:ipr_mobile/features/branches/data/datasources/branches_remote_datasource.dart';
import 'package:ipr_mobile/features/branches/data/repositories/api_branches_repository.dart';
import 'package:ipr_mobile/features/branches/domain/repositories/branches_repository.dart';

/// Repositorio de sedes sobre `ApiClient` y `CacheStore` (`CachePolicy.stores`).
/// Las pruebas de widgets sustituyen este proveedor con un doble (D4).
final branchesRepositoryProvider = Provider<BranchesRepository>(
  (ref) => ApiBranchesRepository(
    remote: BranchesRemoteDataSource(ref.watch(apiClientProvider)),
    cache: ref.watch(cacheStoreProvider),
  ),
);
