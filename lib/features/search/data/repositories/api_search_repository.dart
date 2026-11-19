import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/search/data/datasources/search_remote_datasource.dart';
import 'package:ipr_mobile/features/search/data/mappers/search_mapper.dart';
import 'package:ipr_mobile/features/search/domain/entities/search_page.dart';
import 'package:ipr_mobile/features/search/domain/entities/search_suggestion.dart';
import 'package:ipr_mobile/features/search/domain/repositories/search_repository.dart';

/// Implementación sobre `/mobile/v1`. La búsqueda y las sugerencias viven solo
/// en memoria (`flutter_app_architecture.md` §9): no hay caché en disco, así
/// que el texto buscado nunca se persiste.
final class ApiSearchRepository implements SearchRepository {
  const new(this._remote);

  final SearchRemoteDataSource _remote;

  @override
  Future<Result<SearchPage>> search(
    String query, {
    int page = 1,
    RequestCancellation? cancellation,
  }) {
    final safePage = page.clamp(1, searchMaxPage);
    return _remote.search(
      query,
      page: safePage,
      decode: (json) => mapSearchPage(json, page: safePage),
      cancellation: cancellation,
    );
  }

  @override
  Future<Result<SearchSuggestions>> suggestions(
    String query, {
    RequestCancellation? cancellation,
  }) => _remote.suggestions(
    query,
    decode: mapSearchSuggestions,
    cancellation: cancellation,
  );
}
