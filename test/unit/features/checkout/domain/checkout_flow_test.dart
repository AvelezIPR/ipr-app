import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/cart_review.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/checkout_attempt.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/checkout_status.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/payment_state.dart';
import 'package:ipr_mobile/features/checkout/domain/rules/checkout_failure.dart';
import 'package:ipr_mobile/features/checkout/domain/rules/checkout_flow.dart';

import '../support/checkout_fakes.dart';

final _t0 = DateTime.utc(2026, 11, 20, 15);
final attemptA = CheckoutAttempt(
  id: 'attempt-a',
  idempotencyKey: 'key-a',
  createdAt: _t0,
);
final attemptB = CheckoutAttempt(
  id: 'attempt-b',
  idempotencyKey: 'key-b',
  createdAt: _t0,
);

const _clean = CartReview(checkoutAllowed: true);
const _changed = CartReview(checkoutAllowed: true, hasChanges: true);
const _blocked = CartReview(checkoutAllowed: false, hasUnavailable: true);

VerifiedOrder _order(PaymentState state) => VerifiedOrder(
  id: 1001,
  number: '1001',
  statusLabel: 'x',
  paymentState: state,
);

/// Un estado representativo por fase.
CheckoutFlowState stateIn(CheckoutPhase phase) => switch (phase) {
  CheckoutPhase.idle => const CheckoutFlowState.idle(),
  CheckoutPhase.revalidating => CheckoutFlowState(
    phase: phase,
    attempt: attemptA,
  ),
  CheckoutPhase.needsReview => CheckoutFlowState(
    phase: phase,
    attempt: attemptA,
    review: _changed,
  ),
  CheckoutPhase.requestingTicket => CheckoutFlowState(
    phase: phase,
    attempt: attemptA,
  ),
  CheckoutPhase.ticketExpired => CheckoutFlowState(
    phase: phase,
    attempt: attemptA,
    ticketRetried: true,
  ),
  CheckoutPhase.openingBrowser || CheckoutPhase.awaitingResult =>
    CheckoutFlowState(phase: phase, attempt: attemptA, checkoutRef: refA),
  CheckoutPhase.verifying || CheckoutPhase.noOrder => CheckoutFlowState(
    phase: phase,
    attempt: attemptA,
    checkoutRef: refA,
  ),
  CheckoutPhase.paid => CheckoutFlowState(
    phase: phase,
    checkoutRef: refA,
    order: _order(PaymentState.paid),
  ),
  CheckoutPhase.pending => CheckoutFlowState(
    phase: phase,
    checkoutRef: refA,
    order: _order(PaymentState.pending),
  ),
  CheckoutPhase.failed => CheckoutFlowState(
    phase: phase,
    checkoutRef: refA,
    order: _order(PaymentState.failed),
  ),
  CheckoutPhase.cancelled => CheckoutFlowState(
    phase: phase,
    checkoutRef: refA,
    order: _order(PaymentState.cancelled),
  ),
  CheckoutPhase.failure => CheckoutFlowState(
    phase: phase,
    attempt: attemptA,
    failureKind: CheckoutFailureKind.noConnection,
    retrySameAttempt: true,
  ),
};

/// Un evento representativo por tipo (nombre → evento).
final Map<String, CheckoutEvent> events = {
  'PayRequested': PayRequested(attemptB),
  'PayBlocked': const PayBlocked(CheckoutFailureKind.disabled),
  'ReviewCompleted': const ReviewCompleted(_clean),
  'ReviewFailed': const ReviewFailed(CheckoutFailureKind.noConnection),
  'ReviewAccepted': ReviewAccepted(attemptB),
  'TicketReceived': const TicketReceived(checkoutRef: refA, urlAllowed: true),
  'RequestFailed': const RequestFailed(CheckoutFailureKind.timeout),
  'RetryTicket': const RetryTicket(),
  'RetryRequested': const RetryRequested(),
  'BrowserOpened': const BrowserOpened(),
  'BrowserFailed': const BrowserFailed(),
  'ReturnDetected': const ReturnDetected(),
  'Restored': const Restored(refA),
  'ResumeVerification': const ResumeVerification(),
  'StatusReceived': StatusReceived(orderStatus(PaymentState.paid)),
  'StatusFailed': const StatusFailed(CheckoutFailureKind.unauthorized),
  'PollTimedOut': const PollTimedOut(lastPollFailed: false),
  'Reset': const Reset(),
};

/// Transiciones que SÍ cambian de fase; todo lo demás debe ignorarse
/// (devolver exactamente el mismo estado).
const Map<CheckoutPhase, Map<String, CheckoutPhase>> expected = {
  CheckoutPhase.idle: {
    'PayRequested': CheckoutPhase.revalidating,
    'PayBlocked': CheckoutPhase.failure,
    'Restored': CheckoutPhase.verifying,
    'Reset': CheckoutPhase.idle,
  },
  CheckoutPhase.revalidating: {
    'ReviewCompleted': CheckoutPhase.requestingTicket,
    'ReviewFailed': CheckoutPhase.failure,
    'Reset': CheckoutPhase.idle,
  },
  CheckoutPhase.needsReview: {
    'PayRequested': CheckoutPhase.revalidating,
    'PayBlocked': CheckoutPhase.failure,
    'ReviewAccepted': CheckoutPhase.requestingTicket,
    'Reset': CheckoutPhase.idle,
  },
  CheckoutPhase.requestingTicket: {
    'TicketReceived': CheckoutPhase.openingBrowser,
    'RequestFailed': CheckoutPhase.failure,
    'Reset': CheckoutPhase.idle,
  },
  CheckoutPhase.ticketExpired: {
    'RetryTicket': CheckoutPhase.requestingTicket,
    'Reset': CheckoutPhase.idle,
  },
  CheckoutPhase.openingBrowser: {
    'BrowserOpened': CheckoutPhase.awaitingResult,
    'BrowserFailed': CheckoutPhase.failure,
    'Reset': CheckoutPhase.idle,
  },
  CheckoutPhase.awaitingResult: {
    'ReturnDetected': CheckoutPhase.verifying,
    'Reset': CheckoutPhase.idle,
  },
  CheckoutPhase.verifying: {
    'StatusReceived': CheckoutPhase.paid,
    'StatusFailed': CheckoutPhase.failure,
    'PollTimedOut': CheckoutPhase.noOrder,
    'Reset': CheckoutPhase.idle,
  },
  CheckoutPhase.paid: {'Reset': CheckoutPhase.idle},
  CheckoutPhase.pending: {'Reset': CheckoutPhase.idle},
  CheckoutPhase.failed: {
    'PayRequested': CheckoutPhase.revalidating,
    'PayBlocked': CheckoutPhase.failure,
    'Reset': CheckoutPhase.idle,
  },
  CheckoutPhase.cancelled: {
    'PayRequested': CheckoutPhase.revalidating,
    'PayBlocked': CheckoutPhase.failure,
    'Reset': CheckoutPhase.idle,
  },
  CheckoutPhase.noOrder: {
    'PayRequested': CheckoutPhase.revalidating,
    'PayBlocked': CheckoutPhase.failure,
    'ResumeVerification': CheckoutPhase.verifying,
    'Reset': CheckoutPhase.idle,
  },
  CheckoutPhase.failure: {
    'PayRequested': CheckoutPhase.revalidating,
    'PayBlocked': CheckoutPhase.failure,
    'RetryRequested': CheckoutPhase.requestingTicket,
    'Reset': CheckoutPhase.idle,
  },
};

CheckoutFlowState step(CheckoutFlowState s, CheckoutEvent e) =>
    CheckoutMachine.transition(s, e);

void main() {
  group('M3 · RF-052 · máquina de estados §6.3 (función pura)', () {
    test('la tabla cubre todas las fases y todos los tipos de evento', () {
      expect(expected.keys.toSet(), CheckoutPhase.values.toSet());
      // `sealed`: si se añade un evento sin entrada aquí, esta cuenta falla.
      expect(events, hasLength(18));
    });

    for (final phase in CheckoutPhase.values) {
      for (final entry in events.entries) {
        final target = expected[phase]![entry.key];
        test(
          target == null
              ? 'TC-062 · AC-052-6 · ${phase.name} + ${entry.key}: se ignora'
              : 'M3 · RF-052 · ${phase.name} + ${entry.key} → ${target.name}',
          () {
            final before = stateIn(phase);
            final after = step(before, entry.value);
            if (target == null) {
              expect(after, equals(before));
              expect(identical(after, before), isTrue);
            } else {
              expect(after.phase, target);
            }
          },
        );
      }
    }

    test(
      'es pura: el mismo estado y evento dan siempre el mismo resultado',
      () {
        final s = stateIn(CheckoutPhase.verifying);
        final e = StatusReceived(orderStatus(PaymentState.paid));
        expect(step(s, e), equals(step(s, e)));
      },
    );
  });

  group('TC-062 · AC-052-6 · AC-057-7 · nunca dos intentos a la vez', () {
    test('solo se puede empezar desde estados en reposo', () {
      final canStart = {
        for (final p in CheckoutPhase.values)
          p: CheckoutMachine.canStartPayment(stateIn(p)),
      };
      expect(canStart.entries.where((e) => e.value).map((e) => e.key).toSet(), {
        CheckoutPhase.idle,
        CheckoutPhase.needsReview,
        CheckoutPhase.failed,
        CheckoutPhase.cancelled,
        CheckoutPhase.noOrder,
        CheckoutPhase.failure,
      });
    });

    test('dos "Pagar" seguidos: el segundo se ignora', () {
      final first = step(
        const CheckoutFlowState.idle(),
        PayRequested(attemptA),
      );
      expect(first.phase, CheckoutPhase.revalidating);
      final second = step(first, PayRequested(attemptB));
      expect(second, equals(first));
      expect(second.attempt, attemptA);
    });

    test('con un intento esperando o verificando no se crea otro ticket', () {
      for (final phase in [
        CheckoutPhase.awaitingResult,
        CheckoutPhase.verifying,
        CheckoutPhase.pending,
      ]) {
        expect(
          step(stateIn(phase), PayRequested(attemptB)),
          equals(stateIn(phase)),
        );
      }
    });

    test('tras un fallo al consultar el estado no se crea otro ticket', () {
      final unverified = step(
        stateIn(CheckoutPhase.verifying),
        const StatusFailed(CheckoutFailureKind.forbidden),
      );
      expect(unverified.pendingVerification, isTrue);
      expect(CheckoutMachine.canStartPayment(unverified), isFalse);
      expect(step(unverified, PayRequested(attemptB)), equals(unverified));
      expect(step(unverified, const RetryRequested()), equals(unverified));
      expect(CheckoutMachine.canResumeVerification(unverified), isTrue);
      expect(
        step(unverified, const ResumeVerification()).phase,
        CheckoutPhase.verifying,
      );
    });
  });

  group('TC-064 · AC-058-1 · revisión del carrito', () {
    test('cambios o no disponibles → needsReview; limpio → ticket', () {
      final revalidating = stateIn(CheckoutPhase.revalidating);
      expect(
        step(revalidating, const ReviewCompleted(_clean)).phase,
        CheckoutPhase.requestingTicket,
      );
      expect(
        step(revalidating, const ReviewCompleted(_changed)).phase,
        CheckoutPhase.needsReview,
      );
      expect(
        step(
          revalidating,
          const ReviewCompleted(
            CartReview(checkoutAllowed: true, hasUnavailable: true),
          ),
        ).phase,
        CheckoutPhase.needsReview,
      );
      // El servidor no permite pagar aunque no se vean cambios.
      final blocked = step(revalidating, const ReviewCompleted(_blocked));
      expect(blocked.phase, CheckoutPhase.needsReview);
      expect(blocked.canContinueAfterReview, isFalse);
    });

    test('si el servidor no permite pagar, "continuar" se ignora', () {
      final blocked = step(
        stateIn(CheckoutPhase.revalidating),
        const ReviewCompleted(_blocked),
      );
      expect(step(blocked, ReviewAccepted(attemptB)), equals(blocked));
    });

    test('aceptar los cambios continúa con un intento NUEVO', () {
      final review = step(
        stateIn(CheckoutPhase.revalidating),
        const ReviewCompleted(_changed),
      );
      expect(review.canContinueAfterReview, isTrue);
      final next = step(review, ReviewAccepted(attemptB));
      expect(next.phase, CheckoutPhase.requestingTicket);
      expect(next.attempt, attemptB);
    });

    test('un fallo al revalidar es un fallo (sin ticket)', () {
      final failed = step(
        stateIn(CheckoutPhase.revalidating),
        const ReviewFailed(
          CheckoutFailureKind.rateLimited,
          retryAfterSeconds: 30,
        ),
      );
      expect(failed.phase, CheckoutPhase.failure);
      expect(failed.failureKind, CheckoutFailureKind.rateLimited);
      expect(failed.retryAfterSeconds, 30);
      expect(failed.retrySameAttempt, isFalse);
    });
  });

  group('TC-064 · TC-074 · AC-058-1 · AC-058-4 · fallos del ticket', () {
    final requesting = stateIn(CheckoutPhase.requestingTicket);

    test('400/409 vuelve a revalidar; el servidor sigue sin autorizar', () {
      final rejected = step(
        requesting,
        const RequestFailed(CheckoutFailureKind.cartInvalid),
      );
      expect(rejected.phase, CheckoutPhase.revalidating);
      expect(rejected.afterRejection, isTrue);
      // Sin cambios visibles: NO se reenvía por sí solo.
      final clean = step(rejected, const ReviewCompleted(_clean));
      expect(clean.phase, CheckoutPhase.failure);
      expect(clean.failureKind, CheckoutFailureKind.cartInvalid);
      expect(clean.retrySameAttempt, isFalse);
      // Con cambios: el usuario decide.
      final review = step(rejected, const ReviewCompleted(_changed));
      expect(review.phase, CheckoutPhase.needsReview);
      expect(review.afterRejection, isTrue);
    });

    test('ticket inválido: UN solo reintento automático y luego error', () {
      final expired = step(
        requesting,
        const RequestFailed(CheckoutFailureKind.ticketInvalid),
      );
      expect(expired.phase, CheckoutPhase.ticketExpired);
      expect(expired.ticketRetried, isTrue);
      final retry = step(expired, const RetryTicket());
      expect(retry.phase, CheckoutPhase.requestingTicket);
      expect(retry.attempt, attemptA, reason: 'misma clave de idempotencia');
      final second = step(
        retry,
        const RequestFailed(CheckoutFailureKind.ticketInvalid),
      );
      expect(second.phase, CheckoutPhase.failure);
      expect(second.failureKind, CheckoutFailureKind.ticketInvalid);
      expect(second.retrySameAttempt, isTrue);
    });

    test('401, 403 y otros: fallo; solo los transitorios reintentan igual', () {
      for (final kind in CheckoutFailureKind.values) {
        if (kind == CheckoutFailureKind.cartInvalid ||
            kind == CheckoutFailureKind.ticketInvalid) {
          continue;
        }
        final failed = step(requesting, RequestFailed(kind));
        expect(failed.phase, CheckoutPhase.failure, reason: kind.name);
        expect(failed.failureKind, kind);
        expect(failed.retrySameAttempt, kind.retrySameAttempt);
      }
    });

    test('el reintento manual del mismo intento conserva la clave', () {
      final failed = step(
        requesting,
        const RequestFailed(CheckoutFailureKind.timeout),
      );
      expect(CheckoutMachine.canRetrySameAttempt(failed), isTrue);
      final retry = step(failed, const RetryRequested());
      expect(retry.phase, CheckoutPhase.requestingTicket);
      expect(retry.attempt, attemptA);
      expect(retry.ticketRetried, isFalse);
    });

    test('tras 400/409, 401 o 403 NO se reutiliza la clave', () {
      for (final kind in [
        CheckoutFailureKind.unauthorized,
        CheckoutFailureKind.forbidden,
        CheckoutFailureKind.urlNotAllowed,
        CheckoutFailureKind.disabled,
      ]) {
        final failed = step(requesting, RequestFailed(kind));
        expect(CheckoutMachine.canRetrySameAttempt(failed), isFalse);
        expect(step(failed, const RetryRequested()), equals(failed));
      }
    });

    test('un fallo sin intento no se puede reintentar con la misma clave', () {
      const blocked = CheckoutFlowState(
        phase: CheckoutPhase.failure,
        failureKind: CheckoutFailureKind.noConnection,
        retrySameAttempt: true,
      );
      expect(CheckoutMachine.canRetrySameAttempt(blocked), isFalse);
    });
  });

  group('TC-066 · AC-052-13 · apertura del navegador', () {
    final requesting = stateIn(CheckoutPhase.requestingTicket);

    test('URL que no pasa la política: no se abre y no se guarda el ref', () {
      final next = step(
        requesting,
        const TicketReceived(checkoutRef: refA, urlAllowed: false),
      );
      expect(next.phase, CheckoutPhase.failure);
      expect(next.failureKind, CheckoutFailureKind.urlNotAllowed);
      expect(next.checkoutRef, isNull);
    });

    test('URL aceptada: se guarda solo el checkoutRef', () {
      final next = step(
        requesting,
        const TicketReceived(checkoutRef: refA, urlAllowed: true),
      );
      expect(next.phase, CheckoutPhase.openingBrowser);
      expect(next.checkoutRef, refA);
    });

    test('si el navegador no abre: error y se puede reintentar', () {
      final failed = step(
        stateIn(CheckoutPhase.openingBrowser),
        const BrowserFailed(),
      );
      expect(failed.failureKind, CheckoutFailureKind.browserUnavailable);
      expect(failed.retrySameAttempt, isTrue);
      expect(failed.checkoutRef, isNull);
    });
  });

  group('TC-079 · AC-056-9 · resultado verificado por paymentState', () {
    final verifying = stateIn(CheckoutPhase.verifying);

    const mapping = {
      PaymentState.paid: CheckoutPhase.paid,
      PaymentState.pending: CheckoutPhase.pending,
      PaymentState.failed: CheckoutPhase.failed,
      PaymentState.cancelled: CheckoutPhase.cancelled,
      PaymentState.refunded: CheckoutPhase.failed,
      PaymentState.unknown: CheckoutPhase.pending,
    };

    for (final entry in mapping.entries) {
      test('${entry.key.name} → ${entry.value.name}', () {
        final next = step(verifying, StatusReceived(orderStatus(entry.key)));
        expect(next.phase, entry.value);
        expect(next.order?.paymentState, entry.key);
        expect(next.checkoutRef, refA);
      });
    }

    test('AC-057-9 · solo paid llega a la fase "pagado"', () {
      final paidPhases = {
        for (final state in PaymentState.values)
          state:
              step(verifying, StatusReceived(orderStatus(state))).phase ==
              CheckoutPhase.paid,
      };
      expect(paidPhases[PaymentState.paid], isTrue);
      expect(paidPhases.entries.where((e) => e.value).map((e) => e.key), [
        PaymentState.paid,
      ]);
    });

    test('awaiting_order: se sigue verificando', () {
      expect(
        step(verifying, StatusReceived(awaitingStatus())),
        equals(verifying),
      );
    });

    test('la respuesta de OTRO intento no es la verdad de este', () {
      expect(
        step(
          verifying,
          StatusReceived(orderStatus(PaymentState.paid, ref: refB)),
        ),
        equals(verifying),
      );
    });

    test('AC-056-7 · fallo al consultar: ni éxito ni fallo del pago', () {
      final failed = step(verifying, const PollTimedOut(lastPollFailed: true));
      expect(failed.phase, CheckoutPhase.failure);
      expect(failed.failureKind, CheckoutFailureKind.statusUnavailable);
      expect(failed.pendingVerification, isTrue);
      expect(failed.checkoutRef, refA);
    });

    test('120 s sin pedido: noOrder, conserva el ref para verificar', () {
      final next = step(verifying, const PollTimedOut(lastPollFailed: false));
      expect(next.phase, CheckoutPhase.noOrder);
      expect(next.checkoutRef, refA);
      expect(CheckoutMachine.canResumeVerification(next), isTrue);
    });
  });

  group('M3 · RF-057 · reanudación y reinicio', () {
    test('Restored solo desde reposo y sin intento', () {
      final restored = step(
        const CheckoutFlowState.idle(),
        const Restored(refA),
      );
      expect(restored.phase, CheckoutPhase.verifying);
      expect(restored.checkoutRef, refA);
      expect(restored.attempt, isNull);
      expect(
        step(stateIn(CheckoutPhase.paid), const Restored(refA)).phase,
        CheckoutPhase.paid,
      );
    });

    test('reanudar sin ref no es posible', () {
      expect(
        CheckoutMachine.canResumeVerification(
          const CheckoutFlowState(phase: CheckoutPhase.noOrder),
        ),
        isFalse,
      );
    });

    test('PA-11 · tras un pendiente, el reposo lo recuerda hasta pagar', () {
      final idle = step(stateIn(CheckoutPhase.pending), const Reset());
      expect(idle.phase, CheckoutPhase.idle);
      expect(idle.priorPending, isTrue);
      expect(step(idle, const Reset()).priorPending, isTrue);
      expect(
        step(stateIn(CheckoutPhase.paid), const Reset()).priorPending,
        isFalse,
      );
      final paying = step(idle, PayRequested(attemptA));
      expect(paying.priorPending, isFalse);
    });

    test('isOutcome e isBusy clasifican las fases', () {
      expect(CheckoutPhase.values.where((p) => p.isOutcome).toSet(), {
        CheckoutPhase.paid,
        CheckoutPhase.pending,
        CheckoutPhase.failed,
        CheckoutPhase.cancelled,
        CheckoutPhase.noOrder,
      });
      expect(CheckoutPhase.values.where((p) => p.isBusy).toSet(), {
        CheckoutPhase.revalidating,
        CheckoutPhase.requestingTicket,
        CheckoutPhase.ticketExpired,
        CheckoutPhase.openingBrowser,
        CheckoutPhase.awaitingResult,
        CheckoutPhase.verifying,
      });
    });
  });

  group('SC-023 · el estado no contiene ni imprime la URL ni el ticket', () {
    test('toString de estado, ticket e intento no filtran datos', () {
      final ticket = makeTicket();
      final rendered = [
        ticket.toString(),
        stateIn(CheckoutPhase.openingBrowser).toString(),
        stateIn(CheckoutPhase.awaitingResult).toString(),
        attemptA.toString(),
        step(
          stateIn(CheckoutPhase.requestingTicket),
          const TicketReceived(checkoutRef: refA, urlAllowed: true),
        ).toString(),
      ].join(' ');
      expect(rendered, isNot(contains(ticketSecret)));
      expect(rendered, isNot(contains('ipr_ticket')));
      expect(rendered, isNot(contains('https://')));
      expect(rendered, isNot(contains('key-a')));
      expect(rendered, contains('<oculta>'));
    });

    test('el estado no tiene un campo con la URL', () {
      // Un estado completo no depende del ticket: igualdad solo por datos
      // opacos (ref, intento, resultado).
      final a = step(
        stateIn(CheckoutPhase.requestingTicket),
        const TicketReceived(checkoutRef: refA, urlAllowed: true),
      );
      final b = step(
        stateIn(CheckoutPhase.requestingTicket),
        const TicketReceived(checkoutRef: refA, urlAllowed: true),
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });
  });

  group('M3 · igualdad de valores', () {
    test('entidades comparables por valor', () {
      expect(
        const CartReview(checkoutAllowed: true),
        equals(const CartReview(checkoutAllowed: true)),
      );
      expect(
        const CartReview(checkoutAllowed: true).hashCode,
        const CartReview(checkoutAllowed: true).hashCode,
      );
      expect(_clean.toString(), contains('allowed: true'));
      expect(attemptA.hashCode, isNot(attemptB.hashCode));
      expect(_order(PaymentState.paid), equals(_order(PaymentState.paid)));
      expect(
        _order(PaymentState.paid).hashCode,
        _order(PaymentState.paid).hashCode,
      );
      expect(_order(PaymentState.paid).toString(), contains('paid'));
      expect(awaitingStatus().awaitingOrder, isTrue);
      expect(orderStatus(PaymentState.paid).awaitingOrder, isFalse);
      expect(awaitingStatus(), equals(awaitingStatus()));
      expect(awaitingStatus().hashCode, awaitingStatus().hashCode);
      expect(awaitingStatus().toString(), contains(refA));
    });
  });
}
