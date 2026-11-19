import 'package:dio/dio.dart';
import 'package:ipr_mobile/core/config/app_config.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/api_request.dart';
import 'package:ipr_mobile/core/network/failure_mapper.dart';
import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';

/// Cliente HTTP del BFF `/mobile/v1` (ADR-006). Es la única puerta de salida
/// a la red; los repositorios solo ven `Result` y `AppFailure`.
final class ApiClient {
  new(this._dio);

  /// Crea el [Dio] con los tiempos acordados (CR-014) y los interceptores en
  /// el orden estricto de `flutter_app_architecture.md` §7.2.
  factory build({
    required AppConfig config,
    required List<Interceptor> Function(Dio dio) interceptors,
    HttpClientAdapter? adapter,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: config.apiBaseUrl.toString(),
        connectTimeout: ApiTimeouts.connect,
        receiveTimeout: ApiTimeouts.receive,
        sendTimeout: ApiTimeouts.receive,
        // 304 es éxito (ETag); el resto de 3xx/4xx/5xx llega como error.
        validateStatus: (s) => s != null && ((s >= 200 && s < 300) || s == 304),
        followRedirects: false,
      ),
    );
    if (adapter != null) dio.httpClientAdapter = adapter;
    dio.interceptors.addAll(interceptors(dio));
    return ApiClient(dio);
  }

  final Dio _dio;

  /// Para pruebas y para construir interceptores que reintentan.
  Dio get dio => _dio;

  /// Envía [request] y devuelve la respuesta o un [AppFailure].
  Future<Result<ApiResponse>> send(
    ApiRequest request, {
    CancelToken? cancelToken,
    RequestCancellation? cancellation,
  }) async {
    final token = cancellation == null
        ? cancelToken
        : _link(cancelToken ?? CancelToken(), cancellation);
    if (request.requiresIdempotency &&
        (request.idempotencyKey == null || request.idempotencyKey!.isEmpty)) {
      // Error de programación: nunca se envía sin clave (CR-005).
      throw ArgumentError(
        'La petición ${request.method} ${request.path} exige Idempotency-Key',
      );
    }
    final headers = <String, Object?>{
      ...?request.headers,
      if (request.idempotencyKey != null)
        'Idempotency-Key': request.idempotencyKey,
    };
    try {
      final response = await _dio.request<Object?>(
        request.path,
        data: request.body,
        queryParameters: request.query,
        cancelToken: token,
        options: Options(
          method: request.method,
          headers: headers,
          receiveTimeout: request.receiveTimeout,
          extra: {ApiExtra.requiresAuth: request.requiresAuth},
        ),
      );
      return Ok(
        ApiResponse(
          statusCode: response.statusCode ?? 200,
          data: response.data,
          headers: response.headers.map,
        ),
      );
    } on DioException catch (e) {
      return Err(mapDioException(e));
    }
  }

  static CancelToken _link(CancelToken token, RequestCancellation source) {
    source.onCancel(() {
      if (!token.isCancelled) token.cancel();
    });
    return token;
  }

  /// Como [send], pero decodifica `body` con [decode]. Un fallo de mapeo se
  /// convierte en [ContractFailure] (sin volcar el cuerpo).
  Future<Result<T>> sendDecoded<T>(
    ApiRequest request,
    T Function(Object? json) decode, {
    CancelToken? cancelToken,
    RequestCancellation? cancellation,
  }) async {
    final result = await send(
      request,
      cancelToken: cancelToken,
      cancellation: cancellation,
    );
    return switch (result) {
      Err<ApiResponse>(:final failure) => Err(failure),
      Ok<ApiResponse>(:final value) => _decode(request, value, decode),
    };
  }

  Result<T> _decode<T>(
    ApiRequest request,
    ApiResponse response,
    T Function(Object? json) decode,
  ) {
    try {
      return Ok(decode(response.data));
    } on Object {
      return Err(ContractFailure(detail: '${request.method} ${request.path}'));
    }
  }
}
