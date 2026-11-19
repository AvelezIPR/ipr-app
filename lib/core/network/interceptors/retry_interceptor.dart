import 'dart:math';

import 'package:dio/dio.dart';
import 'package:ipr_mobile/core/network/api_request.dart';
import 'package:ipr_mobile/core/network/failure_mapper.dart';

/// Interceptor 3: reintentos controlados.
///
/// Solo GET/HEAD ante error de red, tiempo agotado, 429, 502, 503 y 504;
/// máximo [maxRetries] reintentos con retroceso exponencial y *jitter*,
/// respetando `Retry-After` si es ≤ [maxRetryAfter]. **POST nunca se
/// reintenta** (RNF-021, RNF-024, CR-005).
final class RetryInterceptor extends Interceptor {
  new({
    required this.dio,
    this.maxRetries = 2,
    this.baseDelay = const Duration(milliseconds: 400),
    this.maxRetryAfter = const Duration(seconds: 10),
    Future<void> Function(Duration)? sleep,
    Random? random,
  }) : _sleep = sleep ?? Future<void>.delayed,
       _random = random ?? Random();

  final Dio dio;
  final int maxRetries;
  final Duration baseDelay;
  final Duration maxRetryAfter;
  final Future<void> Function(Duration) _sleep;
  final Random _random;

  static const _retryableStatuses = {429, 502, 503, 504};

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final method = options.method.toUpperCase();
    final attempt = (options.extra[ApiExtra.retryCount] as int?) ?? 0;

    if ((method != 'GET' && method != 'HEAD') ||
        attempt >= maxRetries ||
        !_isRetryable(err)) {
      handler.next(err);
      return;
    }

    final retryAfter = parseRetryAfter(err.response?.headers.map);
    if (retryAfter != null && Duration(seconds: retryAfter) > maxRetryAfter) {
      // Demasiado largo: se devuelve el fallo con ese valor (AppFailure).
      handler.next(err);
      return;
    }

    await _sleep(
      retryAfter != null ? Duration(seconds: retryAfter) : _backoff(attempt),
    );
    options.extra[ApiExtra.retryCount] = attempt + 1;
    try {
      final response = await dio.fetch<Object?>(options);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  bool _isRetryable(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return true;
      case DioExceptionType.badResponse:
        return _retryableStatuses.contains(err.response?.statusCode);
      case DioExceptionType.transformTimeout:
      case DioExceptionType.badCertificate:
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        return false;
    }
  }

  Duration _backoff(int attempt) {
    final exponential = baseDelay.inMilliseconds * pow(3, attempt).toInt();
    final jitter = _random.nextInt(baseDelay.inMilliseconds ~/ 2 + 1);
    return Duration(milliseconds: exponential + jitter);
  }
}
