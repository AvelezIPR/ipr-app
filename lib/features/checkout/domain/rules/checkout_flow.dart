import 'package:ipr_mobile/features/checkout/domain/entities/cart_review.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/checkout_attempt.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/checkout_status.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/payment_state.dart';
import 'package:ipr_mobile/features/checkout/domain/rules/checkout_failure.dart';
import 'package:meta/meta.dart';

/// Estados del flujo de pago (`flutter_app_architecture.md` §6.3, ADR-008).
enum CheckoutPhase {
  /// Nada en curso; se puede pagar.
  idle,

  /// Revalidando el carrito (N-05).
  revalidating,

  /// Hay cambios o productos no disponibles: el usuario decide (RF-050).
  needsReview,

  /// Pidiendo el ticket (`POST /checkout`).
  requestingTicket,

  /// Ticket vencido/inválido: un único reintento automático (RNF-026).
  ticketExpired,

  /// URL aceptada por la política: abriendo el navegador seguro.
  openingBrowser,

  /// El usuario paga en el navegador; se espera su regreso.
  awaitingResult,

  /// Consultando y sondeando `GET /checkout/{ref}`.
  verifying,

  /// Pedido verificado como pagado (único que vacía el carrito).
  paid,

  /// Pago en verificación o estado por confirmar.
  pending,

  /// Pago fallido o reembolsado.
  failed,

  /// Pago cancelado.
  cancelled,

  /// Sin pedido tras la espera máxima.
  noOrder,

  /// El flujo no pudo continuar ([CheckoutFlowState.failureKind]).
  failure;

  /// Estados con un resultado verificado o final del intento.
  bool get isOutcome => switch (this) {
    paid || pending || failed || cancelled || noOrder => true,
    _ => false,
  };

  /// Hay un intento que avanza solo (no se debe crear otro ticket).
  bool get isBusy => switch (this) {
    revalidating ||
    requestingTicket ||
    ticketExpired ||
    openingBrowser ||
    awaitingResult ||
    verifying => true,
    _ => false,
  };
}

/// Estado inmutable del flujo. **No contiene la URL ni el ticket**: solo
/// referencias opacas (`checkoutRef`, id de intento) y resultados.
@immutable
final class CheckoutFlowState {
  const new({
    required this.phase,
    this.attempt,
    this.checkoutRef,
    this.review,
    this.order,
    this.failureKind,
    this.retryAfterSeconds,
    this.ticketRetried = false,
    this.afterRejection = false,
    this.retrySameAttempt = false,
    this.pendingVerification = false,
    this.priorPending = false,
  });

  const new idle({bool priorPending = false})
    : this(phase: CheckoutPhase.idle, priorPending: priorPending);

  final CheckoutPhase phase;

  /// Intento en curso (clave de idempotencia incluida). `null` al reanudar
  /// tras un cierre forzado.
  final CheckoutAttempt? attempt;

  /// UUID del intento que el BFF correlaciona con el pedido.
  final String? checkoutRef;

  /// Resultado de la última revalidación (en `needsReview`).
  final CartReview? review;

  /// Pedido verificado por el servidor (en `paid`, `pending`, `failed`,
  /// `cancelled`).
  final VerifiedOrder? order;

  /// Motivo (solo en `failure`).
  final CheckoutFailureKind? failureKind;

  /// Espera sugerida por el servidor (429).
  final int? retryAfterSeconds;

  /// Ya se usó el único reintento automático de ticket.
  final bool ticketRetried;

  /// La revalidación en curso la provocó un 400/409 del servidor.
  final bool afterRejection;

  /// Un reintento del MISMO intento (misma clave) es seguro.
  final bool retrySameAttempt;

  /// El fallo ocurrió consultando el estado: hay un `checkoutRef` por
  /// verificar y NO se debe crear otro ticket antes.
  final bool pendingVerification;

  /// Hubo un pedido con pago en verificación antes de este estado (PA-11:
  /// la política ante un pedido pendiente es DESCONOCIDA; solo se advierte).
  final bool priorPending;

  /// ¿Se puede continuar tras revisar los cambios?
  bool get canContinueAfterReview =>
      phase == CheckoutPhase.needsReview && (review?.checkoutAllowed ?? false);

  @override
  bool operator ==(Object other) =>
      other is CheckoutFlowState &&
      other.phase == phase &&
      other.attempt == attempt &&
      other.checkoutRef == checkoutRef &&
      other.review == review &&
      other.order == order &&
      other.failureKind == failureKind &&
      other.retryAfterSeconds == retryAfterSeconds &&
      other.ticketRetried == ticketRetried &&
      other.afterRejection == afterRejection &&
      other.retrySameAttempt == retrySameAttempt &&
      other.pendingVerification == pendingVerification &&
      other.priorPending == priorPending;

  @override
  int get hashCode => Object.hash(
    phase,
    attempt,
    checkoutRef,
    review,
    order,
    failureKind,
    retryAfterSeconds,
    ticketRetried,
    afterRejection,
    retrySameAttempt,
    pendingVerification,
    priorPending,
  );

  @override
  String toString() =>
      'CheckoutFlowState(${phase.name}'
      '${failureKind == null ? '' : ', ${failureKind!.name}'}'
      '${checkoutRef == null ? '' : ', ref: $checkoutRef'})';
}

/// Eventos que mueven el flujo. Los efectos (red, navegador, disco) los hace
/// el controlador y luego informa el resultado con uno de estos eventos.
sealed class CheckoutEvent {
  const new();
}

/// El usuario tocó "Pagar" (intento nuevo con su propia clave).
final class PayRequested extends CheckoutEvent {
  const new(this.attempt);
  final CheckoutAttempt attempt;
}

/// Antes de empezar no se puede pagar (sin sesión, checkout apagado…).
final class PayBlocked extends CheckoutEvent {
  const new(this.kind);
  final CheckoutFailureKind kind;
}

/// Terminó la revalidación del carrito.
final class ReviewCompleted extends CheckoutEvent {
  const new(this.review);
  final CartReview review;
}

/// No se pudo revalidar el carrito.
final class ReviewFailed extends CheckoutEvent {
  const new(this.kind, {this.retryAfterSeconds});
  final CheckoutFailureKind kind;
  final int? retryAfterSeconds;
}

/// El usuario aceptó continuar tras revisar los cambios. Lleva un intento
/// NUEVO: el carrito pudo cambiar y la clave anterior no debe reutilizarse con
/// otro cuerpo.
final class ReviewAccepted extends CheckoutEvent {
  const new(this.attempt);
  final CheckoutAttempt attempt;
}

/// Llegó el ticket. [urlAllowed] es la decisión de `CheckoutUrlPolicy`
/// (https, sin credenciales, host en la intersección local ∩ remota).
final class TicketReceived extends CheckoutEvent {
  const new({required this.checkoutRef, required this.urlAllowed});
  final String checkoutRef;
  final bool urlAllowed;
}

/// Falló la petición del ticket.
final class RequestFailed extends CheckoutEvent {
  const new(this.kind, {this.retryAfterSeconds});
  final CheckoutFailureKind kind;
  final int? retryAfterSeconds;
}

/// Empieza el único reintento automático de ticket.
final class RetryTicket extends CheckoutEvent {
  const new();
}

/// El usuario reintenta el MISMO intento (misma clave de idempotencia).
final class RetryRequested extends CheckoutEvent {
  const new();
}

/// El navegador seguro se abrió.
final class BrowserOpened extends CheckoutEvent {
  const new();
}

/// El navegador seguro no se pudo abrir.
final class BrowserFailed extends CheckoutEvent {
  const new();
}

/// Enlace de retorno, regreso a primer plano o cierre del navegador.
final class ReturnDetected extends CheckoutEvent {
  const new();
}

/// Reanudación tras un cierre forzado de la app (registro sin PII vigente).
final class Restored extends CheckoutEvent {
  const new(this.checkoutRef);
  final String checkoutRef;
}

/// Volver a consultar el mismo `checkoutRef` (sin crear otro ticket).
final class ResumeVerification extends CheckoutEvent {
  const new();
}

/// Respuesta de `GET /checkout/{ref}`.
final class StatusReceived extends CheckoutEvent {
  const new(this.status);
  final CheckoutStatus status;
}

/// La consulta falló de forma que esperar no lo arregla (sesión, permiso o
/// contrato).
final class StatusFailed extends CheckoutEvent {
  const new(this.kind);
  final CheckoutFailureKind kind;
}

/// Se agotó el tiempo de verificación. [lastPollFailed]: la última consulta
/// falló (el estado real se desconoce) en vez de responder `awaiting_order`.
final class PollTimedOut extends CheckoutEvent {
  const new({required this.lastPollFailed});
  final bool lastPollFailed;
}

/// Volver a `idle` (salir del resultado, cierre de sesión).
final class Reset extends CheckoutEvent {
  const new();
}

/// Máquina de estados del checkout como **función pura**: sin reloj, sin
/// azar, sin efectos. Un evento que no corresponde al estado actual se ignora
/// (devuelve el mismo estado): así un doble toque o un evento tardío no
/// pueden crear un segundo ticket ni saltar la verificación.
abstract final class CheckoutMachine {
  /// ¿Se puede iniciar un intento nuevo desde [s]? Nunca mientras haya uno en
  /// curso, tras un pedido pendiente ni con una verificación sin terminar.
  static bool canStartPayment(CheckoutFlowState s) => switch (s.phase) {
    CheckoutPhase.idle ||
    CheckoutPhase.needsReview ||
    CheckoutPhase.failed ||
    CheckoutPhase.cancelled ||
    CheckoutPhase.noOrder => true,
    CheckoutPhase.failure => !s.pendingVerification,
    _ => false,
  };

  /// ¿Se puede volver a consultar el estado del intento de [s]?
  static bool canResumeVerification(CheckoutFlowState s) =>
      s.checkoutRef != null &&
      ((s.phase == CheckoutPhase.failure && s.pendingVerification) ||
          s.phase == CheckoutPhase.noOrder);

  /// ¿Se puede repetir el mismo intento (misma clave) desde [s]?
  static bool canRetrySameAttempt(CheckoutFlowState s) =>
      s.phase == CheckoutPhase.failure &&
      s.retrySameAttempt &&
      !s.pendingVerification &&
      s.attempt != null;

  static CheckoutFlowState transition(CheckoutFlowState s, CheckoutEvent e) =>
      switch (e) {
        PayRequested() => _payRequested(s, e),
        PayBlocked() => _payBlocked(s, e),
        ReviewCompleted() => _reviewCompleted(s, e),
        ReviewFailed() => _reviewFailed(s, e),
        ReviewAccepted() => _reviewAccepted(s, e),
        TicketReceived() => _ticketReceived(s, e),
        RequestFailed() => _requestFailed(s, e),
        RetryTicket() => _retryTicket(s),
        RetryRequested() => _retryRequested(s),
        BrowserOpened() => _browserOpened(s),
        BrowserFailed() => _browserFailed(s),
        ReturnDetected() => _returnDetected(s),
        Restored() => _restored(s, e),
        ResumeVerification() => _resumeVerification(s),
        StatusReceived() => _statusReceived(s, e),
        StatusFailed() => _statusFailed(s, e),
        PollTimedOut() => _pollTimedOut(s, e),
        Reset() => _reset(s),
      };

  static CheckoutFlowState _payRequested(CheckoutFlowState s, PayRequested e) =>
      canStartPayment(s)
      ? CheckoutFlowState(phase: CheckoutPhase.revalidating, attempt: e.attempt)
      : s;

  static CheckoutFlowState _payBlocked(CheckoutFlowState s, PayBlocked e) =>
      canStartPayment(s)
      ? CheckoutFlowState(phase: CheckoutPhase.failure, failureKind: e.kind)
      : s;

  static CheckoutFlowState _reviewCompleted(
    CheckoutFlowState s,
    ReviewCompleted e,
  ) {
    if (s.phase != CheckoutPhase.revalidating) return s;
    final review = e.review;
    if (!review.checkoutAllowed || review.needsAttention) {
      return CheckoutFlowState(
        phase: CheckoutPhase.needsReview,
        attempt: s.attempt,
        review: review,
        afterRejection: s.afterRejection,
        ticketRetried: s.ticketRetried,
      );
    }
    if (s.afterRejection) {
      // El servidor rechazó el carrito pero la revalidación no ve cambios:
      // no se reenvía por sí solo (un toque = una solicitud).
      return CheckoutFlowState(
        phase: CheckoutPhase.failure,
        attempt: s.attempt,
        failureKind: CheckoutFailureKind.cartInvalid,
      );
    }
    return CheckoutFlowState(
      phase: CheckoutPhase.requestingTicket,
      attempt: s.attempt,
      review: review,
    );
  }

  static CheckoutFlowState _reviewFailed(CheckoutFlowState s, ReviewFailed e) =>
      s.phase == CheckoutPhase.revalidating
      ? CheckoutFlowState(
          phase: CheckoutPhase.failure,
          attempt: s.attempt,
          failureKind: e.kind,
          retryAfterSeconds: e.retryAfterSeconds,
        )
      : s;

  static CheckoutFlowState _reviewAccepted(
    CheckoutFlowState s,
    ReviewAccepted e,
  ) => s.canContinueAfterReview
      ? CheckoutFlowState(
          phase: CheckoutPhase.requestingTicket,
          attempt: e.attempt,
          review: s.review,
        )
      : s;

  static CheckoutFlowState _ticketReceived(
    CheckoutFlowState s,
    TicketReceived e,
  ) {
    if (s.phase != CheckoutPhase.requestingTicket) return s;
    if (!e.urlAllowed) {
      // Una respuesta que contradice la política no se obedece y el
      // `checkoutRef` no se conserva: nunca se abrió nada que verificar.
      return CheckoutFlowState(
        phase: CheckoutPhase.failure,
        attempt: s.attempt,
        failureKind: CheckoutFailureKind.urlNotAllowed,
      );
    }
    return CheckoutFlowState(
      phase: CheckoutPhase.openingBrowser,
      attempt: s.attempt,
      checkoutRef: e.checkoutRef,
      ticketRetried: s.ticketRetried,
    );
  }

  static CheckoutFlowState _requestFailed(
    CheckoutFlowState s,
    RequestFailed e,
  ) {
    if (s.phase != CheckoutPhase.requestingTicket) return s;
    switch (e.kind) {
      case CheckoutFailureKind.cartInvalid:
        return CheckoutFlowState(
          phase: CheckoutPhase.revalidating,
          attempt: s.attempt,
          afterRejection: true,
          ticketRetried: s.ticketRetried,
        );
      case CheckoutFailureKind.ticketInvalid when !s.ticketRetried:
        return CheckoutFlowState(
          phase: CheckoutPhase.ticketExpired,
          attempt: s.attempt,
          ticketRetried: true,
        );
      case _:
        return CheckoutFlowState(
          phase: CheckoutPhase.failure,
          attempt: s.attempt,
          failureKind: e.kind,
          retryAfterSeconds: e.retryAfterSeconds,
          retrySameAttempt: e.kind.retrySameAttempt,
          ticketRetried: s.ticketRetried,
        );
    }
  }

  static CheckoutFlowState _retryTicket(CheckoutFlowState s) =>
      s.phase == CheckoutPhase.ticketExpired
      ? CheckoutFlowState(
          phase: CheckoutPhase.requestingTicket,
          attempt: s.attempt,
          ticketRetried: true,
        )
      : s;

  static CheckoutFlowState _retryRequested(CheckoutFlowState s) =>
      canRetrySameAttempt(s)
      ? CheckoutFlowState(
          phase: CheckoutPhase.requestingTicket,
          attempt: s.attempt,
          // El reintento automático de ticket es UNO por intento: un
          // reintento manual no lo devuelve.
          ticketRetried: s.ticketRetried,
        )
      : s;

  static CheckoutFlowState _browserOpened(CheckoutFlowState s) =>
      s.phase == CheckoutPhase.openingBrowser
      ? CheckoutFlowState(
          phase: CheckoutPhase.awaitingResult,
          attempt: s.attempt,
          checkoutRef: s.checkoutRef,
        )
      : s;

  static CheckoutFlowState _browserFailed(CheckoutFlowState s) =>
      s.phase == CheckoutPhase.openingBrowser
      ? CheckoutFlowState(
          phase: CheckoutPhase.failure,
          attempt: s.attempt,
          failureKind: CheckoutFailureKind.browserUnavailable,
          retrySameAttempt: true,
        )
      : s;

  static CheckoutFlowState _returnDetected(CheckoutFlowState s) =>
      s.phase == CheckoutPhase.awaitingResult
      ? CheckoutFlowState(
          phase: CheckoutPhase.verifying,
          attempt: s.attempt,
          checkoutRef: s.checkoutRef,
        )
      : s;

  static CheckoutFlowState _restored(CheckoutFlowState s, Restored e) =>
      s.phase == CheckoutPhase.idle
      ? CheckoutFlowState(
          phase: CheckoutPhase.verifying,
          checkoutRef: e.checkoutRef,
        )
      : s;

  static CheckoutFlowState _resumeVerification(CheckoutFlowState s) =>
      canResumeVerification(s)
      ? CheckoutFlowState(
          phase: CheckoutPhase.verifying,
          attempt: s.attempt,
          checkoutRef: s.checkoutRef,
        )
      : s;

  static CheckoutFlowState _statusReceived(
    CheckoutFlowState s,
    StatusReceived e,
  ) {
    if (s.phase != CheckoutPhase.verifying) return s;
    final status = e.status;
    // Una respuesta de otro intento no es la verdad de este.
    if (status.checkoutRef != s.checkoutRef) return s;
    final order = status.order;
    if (order == null) return s; // awaiting_order: se sigue sondeando
    final phase = switch (order.paymentState) {
      PaymentState.paid => CheckoutPhase.paid,
      PaymentState.cancelled => CheckoutPhase.cancelled,
      PaymentState.failed || PaymentState.refunded => CheckoutPhase.failed,
      // `unknown` es "por confirmar": nunca pagado (SC-025).
      PaymentState.pending || PaymentState.unknown => CheckoutPhase.pending,
    };
    return CheckoutFlowState(
      phase: phase,
      attempt: s.attempt,
      checkoutRef: s.checkoutRef,
      order: order,
    );
  }

  static CheckoutFlowState _statusFailed(CheckoutFlowState s, StatusFailed e) =>
      s.phase == CheckoutPhase.verifying
      ? CheckoutFlowState(
          phase: CheckoutPhase.failure,
          attempt: s.attempt,
          checkoutRef: s.checkoutRef,
          failureKind: e.kind,
          pendingVerification: true,
        )
      : s;

  static CheckoutFlowState _pollTimedOut(CheckoutFlowState s, PollTimedOut e) {
    if (s.phase != CheckoutPhase.verifying) return s;
    if (e.lastPollFailed) {
      return CheckoutFlowState(
        phase: CheckoutPhase.failure,
        attempt: s.attempt,
        checkoutRef: s.checkoutRef,
        failureKind: CheckoutFailureKind.statusUnavailable,
        pendingVerification: true,
      );
    }
    return CheckoutFlowState(
      phase: CheckoutPhase.noOrder,
      attempt: s.attempt,
      checkoutRef: s.checkoutRef,
    );
  }

  static CheckoutFlowState _reset(CheckoutFlowState s) =>
      CheckoutFlowState.idle(
        priorPending:
            s.phase == CheckoutPhase.pending ||
            (s.phase == CheckoutPhase.idle && s.priorPending),
      );
}
