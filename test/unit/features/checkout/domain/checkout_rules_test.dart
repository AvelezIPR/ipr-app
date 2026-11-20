import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/checkout_line.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/payment_state.dart';
import 'package:ipr_mobile/features/checkout/domain/rules/checkout_failure.dart';
import 'package:ipr_mobile/features/checkout/domain/rules/poll_schedule.dart';

void main() {
  group('TC-064 · AC-058-1 · AC-058-2 · clasificación de fallos', () {
    const cases = <(AppFailure, CheckoutFailureKind)>[
      (NoConnection(), CheckoutFailureKind.noConnection),
      (RequestTimeout(), CheckoutFailureKind.timeout),
      (ServiceUnavailable(), CheckoutFailureKind.storeUnavailable),
      (
        ServiceUnavailable(code: 'feature_disabled'),
        CheckoutFailureKind.storeUnavailable,
      ),
      (RateLimited(retryAfter: 30), CheckoutFailureKind.rateLimited),
      (Validation(), CheckoutFailureKind.cartInvalid),
      (Conflict(code: 'idempotency_conflict'), CheckoutFailureKind.cartInvalid),
      (Unauthorized(), CheckoutFailureKind.unauthorized),
      (Forbidden(), CheckoutFailureKind.forbidden),
      (BlockedByEdge(), CheckoutFailureKind.forbidden),
      (ContractFailure(), CheckoutFailureKind.contract),
      (NotFound(), CheckoutFailureKind.unknown),
      (UpgradeRequired(), CheckoutFailureKind.unknown),
      (ServerFailure(), CheckoutFailureKind.unknown),
      (UnknownFailure(), CheckoutFailureKind.unknown),
    ];

    for (final (failure, kind) in cases) {
      test('${failure.runtimeType} → ${kind.name}', () {
        expect(CheckoutFailureKind.from(failure), kind);
      });
    }

    test('ticket vencido/usado/inválido (códigos DESCONOCIDOS aislados)', () {
      for (final code in [
        'ticket_expired',
        'ticket_invalid',
        'ticket_used',
        'ticket_consumed',
        'upstream_bad_response',
      ]) {
        expect(
          CheckoutFailureKind.from(ServiceUnavailable(code: code)),
          CheckoutFailureKind.ticketInvalid,
          reason: code,
        );
        expect(
          CheckoutFailureKind.from(Conflict(code: code)),
          CheckoutFailureKind.ticketInvalid,
          reason: code,
        );
      }
      expect(TicketFailureCodes.isTicketProblem(null), isFalse);
      expect(TicketFailureCodes.isTicketProblem('otro'), isFalse);
    });

    test('solo se reintenta con la misma clave lo transitorio', () {
      expect(
        CheckoutFailureKind.values.where((k) => k.retrySameAttempt).toSet(),
        {
          CheckoutFailureKind.noConnection,
          CheckoutFailureKind.timeout,
          CheckoutFailureKind.storeUnavailable,
          CheckoutFailureKind.rateLimited,
          CheckoutFailureKind.ticketInvalid,
          CheckoutFailureKind.contract,
          CheckoutFailureKind.browserUnavailable,
          CheckoutFailureKind.unknown,
        },
      );
    });

    test('el sondeo se detiene solo ante sesión, permiso o contrato', () {
      expect(CheckoutFailureKind.values.where((k) => k.stopsPolling).toSet(), {
        CheckoutFailureKind.unauthorized,
        CheckoutFailureKind.forbidden,
        CheckoutFailureKind.contract,
      });
    });
  });

  group('RNF-025 · calendario del sondeo 2, 4, 8, 16 s y luego cada 15 s', () {
    test('esperas sucesivas', () {
      var elapsed = Duration.zero;
      final delays = <int>[];
      for (var polls = 1; ; polls++) {
        final delay = PollSchedule.nextDelay(polls: polls, elapsed: elapsed);
        if (delay == null) break;
        delays.add(delay.inSeconds);
        elapsed += delay;
      }
      expect(delays, [2, 4, 8, 16, 15, 15, 15, 15, 15, 15]);
      expect(elapsed, const Duration(seconds: 120));
    });

    test('no cabe otra consulta pasados los 120 s', () {
      expect(
        PollSchedule.nextDelay(polls: 1, elapsed: const Duration(seconds: 119)),
        isNull,
      );
      expect(
        PollSchedule.nextDelay(
          polls: 11,
          elapsed: const Duration(seconds: 105),
        ),
        const Duration(seconds: 15),
      );
      expect(
        PollSchedule.nextDelay(
          polls: 12,
          elapsed: const Duration(seconds: 120),
        ),
        isNull,
      );
    });

    test('un contador inválido se trata como la primera espera', () {
      expect(
        PollSchedule.nextDelay(polls: 0, elapsed: Duration.zero),
        const Duration(seconds: 2),
      );
    });
  });

  group('M3 · RF-056 · PaymentState tolerante', () {
    test('valores del contrato y cualquier otro como unknown', () {
      expect(PaymentState.fromContract('paid'), PaymentState.paid);
      expect(PaymentState.fromContract('pending'), PaymentState.pending);
      expect(PaymentState.fromContract('failed'), PaymentState.failed);
      expect(PaymentState.fromContract('cancelled'), PaymentState.cancelled);
      expect(PaymentState.fromContract('refunded'), PaymentState.refunded);
      expect(PaymentState.fromContract('PAID'), PaymentState.unknown);
      expect(PaymentState.fromContract('on-hold'), PaymentState.unknown);
      expect(PaymentState.fromContract(null), PaymentState.unknown);
      expect(PaymentState.fromContract(1), PaymentState.unknown);
    });
  });

  group('M3 · RF-052 · CheckoutLine', () {
    test('igualdad por producto y cantidad (el nombre no cuenta)', () {
      const a = CheckoutLine(productId: 1, quantity: 2, name: 'A');
      const b = CheckoutLine(productId: 1, quantity: 2, name: 'B');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const CheckoutLine(productId: 1, quantity: 3)));
      expect(a.toString(), 'CheckoutLine(1 x2)');
    });

    test('sameCheckoutLines compara orden y contenido', () {
      const a = CheckoutLine(productId: 1, quantity: 1);
      const b = CheckoutLine(productId: 2, quantity: 1);
      expect(sameCheckoutLines([a, b], [a, b]), isTrue);
      expect(sameCheckoutLines([a, b], [b, a]), isFalse);
      expect(sameCheckoutLines([a], [a, b]), isFalse);
      expect(sameCheckoutLines(const [], const []), isTrue);
    });
  });
}
