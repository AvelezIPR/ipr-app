import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ipr_mobile/core/providers.dart';
import 'package:ipr_mobile/features/catalog/data/datasources/catalog_remote_datasource.dart';
import 'package:ipr_mobile/features/catalog/data/repositories/api_catalog_repository.dart';
import 'package:ipr_mobile/features/catalog/domain/repositories/catalog_repository.dart';

/// Repositorio del catálogo sobre `ApiClient` y la caché pública. Las pruebas
/// de widgets lo sustituyen con un doble de [CatalogRepository].
///
/// Vive en la raíz de la feature (no en `presentation/`) porque cablea la capa
/// `data/` (D4).
final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => ApiCatalogRepository(
    remote: CatalogRemoteDataSource(ref.watch(apiClientProvider)),
    cache: ref.watch(cacheStoreProvider),
  ),
);
