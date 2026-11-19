/// Claves de mensaje de usuario. Los textos viven en `l10n/app_es.arb`
/// (`failure*`); `core` no conoce la interfaz (D1).
enum FailureMessage {
  noConnection,
  timeout,
  notFound,
  serviceUnavailable,
  rateLimited,
  unauthorized,
  forbidden,
  blockedByEdge,
  validation,
  conflict,
  upgradeRequired,
  server,
  contract,
  unknown,
}

/// Error de un campo de formulario devuelto por el BFF (`Problem.errors`).
final class FieldError {
  const new({required this.field, required this.code, required this.message});

  final String field;
  final String code;
  final String message;

  @override
  String toString() => 'FieldError($field, $code)';
}

/// Taxonomía cerrada de fallos (`flutter_app_architecture.md` §7.3).
///
/// Los repositorios devuelven `Result<T>` con un [AppFailure]; ninguna
/// excepción de red llega a `presentation`.
sealed class AppFailure implements Exception {
  const new();

  FailureMessage get message;

  /// Si tiene sentido ofrecer "Reintentar".
  bool get retryable;

  /// Segundos sugeridos por el servidor antes de reintentar, si los hay.
  int? get retryAfterSeconds => null;
}

/// Sin red, DNS o socket.
final class NoConnection extends AppFailure {
  const new();
  @override
  FailureMessage get message => FailureMessage.noConnection;
  @override
  bool get retryable => true;
}

/// Tiempo de conexión, envío o recepción agotado.
final class RequestTimeout extends AppFailure {
  const new();
  @override
  FailureMessage get message => FailureMessage.timeout;
  @override
  bool get retryable => true;
}

/// 404: el recurso de verdad no existe (nunca por una caída del servidor).
final class NotFound extends AppFailure {
  const new();
  @override
  FailureMessage get message => FailureMessage.notFound;
  @override
  bool get retryable => false;
}

/// 502, 503 y 504: el servidor o el origen no están disponibles (CR-073).
final class ServiceUnavailable extends AppFailure {
  const new({this.retryAfter, this.code});
  final int? retryAfter;
  final String? code;
  @override
  int? get retryAfterSeconds => retryAfter;
  @override
  FailureMessage get message => FailureMessage.serviceUnavailable;
  @override
  bool get retryable => true;
}

/// 429.
final class RateLimited extends AppFailure {
  const new({this.retryAfter});
  final int? retryAfter;
  @override
  int? get retryAfterSeconds => retryAfter;
  @override
  FailureMessage get message => FailureMessage.rateLimited;
  @override
  bool get retryable => true;
}

/// 401. [code] distingue `invalid_credentials` (login) de la sesión vencida.
final class Unauthorized extends AppFailure {
  const new({this.code = 'unauthorized'});
  final String code;
  @override
  FailureMessage get message => FailureMessage.unauthorized;
  @override
  bool get retryable => false;
}

/// 403 del BFF (p. ej. `account_locked`).
final class Forbidden extends AppFailure {
  const new({this.code = 'forbidden'});
  final String code;
  @override
  FailureMessage get message => FailureMessage.forbidden;
  @override
  bool get retryable => false;
}

/// 403/HTML del borde (Cloudflare): respuesta que no es JSON del BFF.
final class BlockedByEdge extends AppFailure {
  const new();
  @override
  FailureMessage get message => FailureMessage.blockedByEdge;
  @override
  bool get retryable => false;
}

/// 400 con detalle por campo (nunca 422: CR-062).
final class Validation extends AppFailure {
  const new({this.fields = const [], this.code = 'validation_failed'});
  final List<FieldError> fields;
  final String code;
  @override
  FailureMessage get message => FailureMessage.validation;
  @override
  bool get retryable => false;
}

/// 409 (`email_in_use`, `idempotency_conflict`, `refresh_in_progress`...).
final class Conflict extends AppFailure {
  const new({required this.code});
  final String code;
  @override
  FailureMessage get message => FailureMessage.conflict;
  @override
  bool get retryable => false;
}

/// 426 `app_version_unsupported`.
final class UpgradeRequired extends AppFailure {
  const new();
  @override
  FailureMessage get message => FailureMessage.upgradeRequired;
  @override
  bool get retryable => false;
}

/// 500 genérico.
final class ServerFailure extends AppFailure {
  const new();
  @override
  FailureMessage get message => FailureMessage.server;
  @override
  bool get retryable => true;
}

/// JSON inesperado o mapeo fallido.
final class ContractFailure extends AppFailure {
  const new({this.detail});

  /// Descripción técnica sin cuerpos ni PII (solo ruta y versión).
  final String? detail;
  @override
  FailureMessage get message => FailureMessage.contract;
  @override
  bool get retryable => false;
}

/// Resto de casos.
final class UnknownFailure extends AppFailure {
  const new();
  @override
  FailureMessage get message => FailureMessage.unknown;
  @override
  bool get retryable => true;
}
