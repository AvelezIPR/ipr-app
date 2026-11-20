import 'package:ipr_mobile/core/network/api_client.dart';
import 'package:ipr_mobile/core/network/api_request.dart';
import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';

/// Petición pública de sedes (`GET /stores`). Nunca adjunta sesión.
final class BranchesRemoteDataSource {
  const new(this._client);

  final ApiClient _client;

  Future<Result<ApiResponse>> listStores({RequestCancellation? cancel}) =>
      _client.send(const ApiRequest.get('/stores'), cancellation: cancel);
}
