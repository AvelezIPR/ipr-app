import 'package:dio/dio.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/problem.dart';

/// Segundos de la cabecera `Retry-After` (solo el formato de segundos).
int? parseRetryAfter(Map<String, List<String>>? headers) {
  final values = headers?['retry-after'];
  if (values == null || values.isEmpty) return null;
  final seconds = int.tryParse(values.first.trim());
  if (seconds == null || seconds < 0) return null;
  return seconds;
}

/// Convierte una respuesta HTTP de error en [AppFailure].
///
/// Mapea por `Problem.code` y no solo por el estado HTTP (CR-062, CR-073).
AppFailure mapErrorResponse({
  required int status,
  Object? body,
  Map<String, List<String>>? headers,
}) {
  final problem = Problem.tryParse(body, fallbackStatus: status);
  final retryAfter = problem?.retryAfter ?? parseRetryAfter(headers);

  if (problem == null) {
    // Sin Problem JSON del BFF: respuesta del borde o de un proxy.
    return switch (status) {
      401 => const Unauthorized(),
      403 => const BlockedByEdge(),
      404 => const NotFound(),
      429 => RateLimited(retryAfter: retryAfter),
      502 || 503 || 504 => ServiceUnavailable(retryAfter: retryAfter),
      >= 500 => const ServerFailure(),
      _ => const UnknownFailure(),
    };
  }

  final code = problem.code;
  switch (status) {
    case 400:
      if (code == 'token_in_url_forbidden') {
        return const ContractFailure(detail: 'token_in_url_forbidden');
      }
      return Validation(fields: problem.errors, code: code);
    case 401:
      return Unauthorized(code: code);
    case 403:
      if (code == 'current_password_invalid') {
        return Validation(
          fields: [
            FieldError(
              field: 'currentPassword',
              code: code,
              message: problem.detail ?? '',
            ),
          ],
          code: code,
        );
      }
      return Forbidden(code: code);
    case 404:
      return const NotFound();
    case 409:
      return Conflict(code: code);
    case 426:
      return const UpgradeRequired();
    case 429:
      return RateLimited(retryAfter: retryAfter);
    case 502 || 503 || 504:
      return ServiceUnavailable(retryAfter: retryAfter, code: code);
  }
  if (status >= 500) return const ServerFailure();
  return const UnknownFailure();
}

/// Convierte una [DioException] en [AppFailure].
AppFailure mapDioException(DioException exception) {
  final existing = exception.error;
  if (existing is AppFailure) return existing;
  switch (exception.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return const RequestTimeout();
    case DioExceptionType.connectionError:
      return const NoConnection();
    case DioExceptionType.badCertificate:
      // Nunca se acepta un certificado inválido (SC-036): se trata como fallo
      // de conexión, sin callback que lo omita.
      return const NoConnection();
    case DioExceptionType.cancel:
      return const UnknownFailure();
    case DioExceptionType.badResponse:
      final response = exception.response;
      return mapErrorResponse(
        status: response?.statusCode ?? 0,
        body: response?.data,
        headers: response?.headers.map,
      );
    case DioExceptionType.unknown:
      final error = exception.error;
      if (error is FormatException) {
        return const ContractFailure(detail: 'respuesta no interpretable');
      }
      return const NoConnection();
  }
}
