import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/search/domain/entities/search_page.dart';
import 'package:ipr_mobile/features/search/domain/entities/search_suggestion.dart';

/// Búsqueda de productos (`/mobile/v1/search` y `/search/suggestions`).
///
/// Devuelve `Result`: un fallo de red o de servidor es `Err`, **nunca** una
/// página vacía (AC-023-5). Una página vacía (`Ok`) solo significa que el
/// servidor respondió 200 sin coincidencias.
abstract interface class SearchRepository {
  /// [query] ya normalizada con `SearchQuery.normalize`; [page] de 1 a 50.
  Future<Result<SearchPage>> search(
    String query, {
    int page = 1,
    RequestCancellation? cancellation,
  });

  /// [query] ya normalizada y con al menos 2 caracteres.
  Future<Result<SearchSuggestions>> suggestions(
    String query, {
    RequestCancellation? cancellation,
  });
}
