import 'package:ipr_mobile/core/network/api_client.dart';
import 'package:ipr_mobile/core/network/api_request.dart';
import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';

/// Acceso HTTP a `/search` y `/search/suggestions` (ambos públicos: sin
/// sesión, AC-020-7). El término viaja como parámetro de consulta codificado
/// por el cliente; nunca se concatena a la ruta ni se registra. Cancelar la
/// [RequestCancellation] aborta la conexión.
final class SearchRemoteDataSource {
  const new(this._client);

  final ApiClient _client;

  /// `GET /search?q=&page=&perPage=`.
  Future<Result<T>> search<T>(
    String query, {
    required int page,
    required T Function(Object? json) decode,
    RequestCancellation? cancellation,
  }) => _client.sendDecoded(
    ApiRequest.get('/search', query: {'q': query, 'page': page, 'perPage': 24}),
    decode,
    cancellation: cancellation,
  );

  /// `GET /search/suggestions?q=`.
  Future<Result<T>> suggestions<T>(
    String query, {
    required T Function(Object? json) decode,
    RequestCancellation? cancellation,
  }) => _client.sendDecoded(
    ApiRequest.get('/search/suggestions', query: {'q': query}),
    decode,
    cancellation: cancellation,
  );
}
