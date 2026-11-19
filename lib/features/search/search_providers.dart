import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ipr_mobile/core/providers.dart';
import 'package:ipr_mobile/features/search/data/datasources/search_remote_datasource.dart';
import 'package:ipr_mobile/features/search/data/repositories/api_search_repository.dart';
import 'package:ipr_mobile/features/search/domain/repositories/search_repository.dart';

/// Repositorio de búsqueda. Las pruebas lo sustituyen con un doble de la
/// interfaz de dominio. Vive en la raíz de la feature porque los controladores
/// (presentation) no pueden importar `data/` (D4).
final searchRepositoryProvider = Provider<SearchRepository>(
  (ref) =>
      ApiSearchRepository(SearchRemoteDataSource(ref.watch(apiClientProvider))),
);
