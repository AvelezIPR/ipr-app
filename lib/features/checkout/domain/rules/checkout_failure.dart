import 'package:ipr_mobile/core/errors/app_failure.dart';

/// Por qué el flujo de pago no avanzó (RF-058). Cerrado: la interfaz tiene un
/// mensaje legible por cada valor; nunca se muestra texto del servidor.
enum CheckoutFailureKind {
  /// Sin red (RNF-020).
  noConnection,

  /// Tiempo agotado (20 s, RNF-021).
  timeout,

  /// 502/503/504: la tienda no está disponible.
  storeUnavailable,

  /// 429.
  rateLimited,

  /// 400/409: el carrito cambió o el servidor lo rechazó.
  cartInvalid,

  /// Ticket vencido, usado o inválido (RNF-026).
  ticketInvalid,

  /// 401: la sesión terminó.
  unauthorized,

  /// 403 o bloqueo del borde.
  forbidden,

  /// El BFF respondió algo que no cumple el contrato (sin ticket válido).
  contract,

  /// La URL del ticket no pasó la política (https, host permitido…).
  urlNotAllowed,

  /// El navegador seguro no pudo abrirse.
  browserUnavailable,

  /// `remoteConfig.checkoutEnabled` apagado o configuración sin cargar.
  disabled,

  /// No se pudo consultar el estado del pago (AC-056-7).
  statusUnavailable,

  /// Cualquier otro caso.
  unknown;

  /// Clasifica un [AppFailure] del BFF.
  static CheckoutFailureKind from(AppFailure failure) => switch (failure) {
    NoConnection() => noConnection,
    RequestTimeout() => timeout,
    ServiceUnavailable(:final code) =>
      TicketFailureCodes.isTicketProblem(code)
          ? ticketInvalid
          : storeUnavailable,
    RateLimited() => rateLimited,
    Validation() => cartInvalid,
    Conflict(:final code) =>
      TicketFailureCodes.isTicketProblem(code) ? ticketInvalid : cartInvalid,
    Unauthorized() => unauthorized,
    Forbidden() || BlockedByEdge() => forbidden,
    ContractFailure() => contract,
    NotFound() ||
    UpgradeRequired() ||
    ServerFailure() ||
    UnknownFailure() => unknown,
  };

  /// Si un reintento del MISMO intento (misma `Idempotency-Key`) es seguro y
  /// evita crear otro `checkoutRef`: solo fallos transitorios de la petición
  /// del ticket. Un 400/409, 401 o 403 exigen un intento nuevo.
  bool get retrySameAttempt => switch (this) {
    noConnection ||
    timeout ||
    storeUnavailable ||
    rateLimited ||
    ticketInvalid ||
    contract ||
    browserUnavailable ||
    unknown => true,
    cartInvalid ||
    unauthorized ||
    forbidden ||
    urlNotAllowed ||
    disabled ||
    statusUnavailable => false,
  };

  /// Fallos de la consulta de estado que NO se resuelven esperando (el
  /// sondeo se detiene): sesión, permiso o contrato.
  bool get stopsPolling => switch (this) {
    unauthorized || forbidden || contract => true,
    _ => false,
  };
}

/// Códigos `Problem.code` que significan "ticket vencido, usado o inválido".
///
/// **DESCONOCIDO**: el contrato (`openapi.yaml`) no fija el código; EP-23
/// solo dice `502 upstream_bad_response` (ticket inválido o rechazo de
/// WordPress) y `409` si el ticket anterior ya se consumió. Aislado aquí
/// para ajustarlo cuando el BFF exista (PT-07).
abstract final class TicketFailureCodes {
  static const _codes = {
    'ticket_expired',
    'ticket_invalid',
    'ticket_used',
    'ticket_consumed',
    'upstream_bad_response',
  };

  static bool isTicketProblem(String? code) =>
      code != null && _codes.contains(code);
}
