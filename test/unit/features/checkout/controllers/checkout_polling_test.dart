import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/core/session/session_state.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/payment_state.dart';
import 'package:ipr_mobile/features/checkout/domain/rules/checkout_flow.dart';
import 'package:ipr_mobile/features/checkout/presentation/controllers/checkout_controller.dart';

import '../support/checkout_fakes.dart';

void main() {
  /// Sondeo con temporizadores reales bajo el reloj simulado de `testWidgets`
  /// (equivale a `fakeAsync`): se avanza el tiempo con `tester.pump`.
  testWidgets(
    'RNF-025 · AC-056-5 · sondeo 2, 4, 8, 16 s y luego cada 15 s hasta 120 s',
    (tester) async {
      final clock = ManualClock();
      final h = CheckoutHarness(
        clock: clock,
        sleep: (duration) {
          clock.advance(duration);
          return Future<void>.delayed(duration);
        },
      );
      addTearDown(h.dispose);
      h.repo
        ..createResults.add(Ok(makeTicket()))
        ..statusResults.add(Ok(awaitingStatus()));
      final controller = h.container.read(checkoutControllerProvider.notifier);

      await controller.pay();
      expect(
        h.container.read(checkoutControllerProvider).phase,
        CheckoutPhase.awaitingResult,
      );

      unawaited(controller.verifyNow());
      await tester.pump();
      expect(h.repo.statusCalls, hasLength(1), reason: 'consulta inmediata');

      // Esperas acumuladas entre consultas: 2, 4, 8, 16, 15 × 6.
      const waits = [2, 4, 8, 16, 15, 15, 15, 15, 15, 15];
      var expectedCalls = 1;
      for (final wait in waits) {
        await tester.pump(Duration(seconds: wait) - const Duration(seconds: 1));
        expect(
          h.repo.statusCalls,
          hasLength(expectedCalls),
          reason: 'aún no pasan ${wait}s',
        );
        await tester.pump(const Duration(seconds: 1));
        expectedCalls++;
        expect(
          h.repo.statusCalls,
          hasLength(expectedCalls),
          reason: 'tras ${wait}s llega otra consulta',
        );
      }

      // A los 120 s sin pedido: noOrder y se acaba el sondeo.
      final state = h.container.read(checkoutControllerProvider);
      expect(state.phase, CheckoutPhase.noOrder);
      await tester.pump(const Duration(seconds: 60));
      expect(h.repo.statusCalls, hasLength(11));
      expect(h.cart.clearCalls, 0);
    },
  );

  testWidgets('el pedido aparece a mitad del sondeo: pagado y carrito vacío', (
    tester,
  ) async {
    final clock = ManualClock();
    final h = CheckoutHarness(
      clock: clock,
      sleep: (duration) {
        clock.advance(duration);
        return Future<void>.delayed(duration);
      },
    );
    addTearDown(h.dispose);
    h.repo
      ..createResults.add(Ok(makeTicket()))
      ..statusResults.addAll([
        Ok(awaitingStatus()),
        Ok(awaitingStatus()),
        Ok(orderStatus(PaymentState.paid)),
      ]);
    final controller = h.container.read(checkoutControllerProvider.notifier);
    await controller.pay();

    unawaited(controller.verifyNow());
    await tester.pump(); // t = 0
    await tester.pump(const Duration(seconds: 2)); // t = 2
    expect(h.cart.clearCalls, 0);
    await tester.pump(const Duration(seconds: 4)); // t = 6
    await tester.pump();

    expect(
      h.container.read(checkoutControllerProvider).phase,
      CheckoutPhase.paid,
    );
    expect(h.cart.clearCalls, 1);
    expect(h.repo.statusCalls, hasLength(3));
  });

  testWidgets('salir (cerrar sesión) cancela el sondeo pendiente', (
    tester,
  ) async {
    final clock = ManualClock();
    final h = CheckoutHarness(
      clock: clock,
      sleep: (duration) {
        clock.advance(duration);
        return Future<void>.delayed(duration);
      },
    );
    addTearDown(h.dispose);
    h.repo
      ..createResults.add(Ok(makeTicket()))
      ..statusResults.add(Ok(awaitingStatus()));
    final controller = h.container.read(checkoutControllerProvider.notifier);
    await controller.pay();
    unawaited(controller.verifyNow());
    await tester.pump();
    expect(h.repo.statusCalls, hasLength(1));

    h.sessionController.set(const SessionAnonymous());
    await tester.pump();
    await tester.pump(const Duration(seconds: 30));

    expect(h.repo.statusCalls, hasLength(1), reason: 'no sigue consultando');
    expect(
      h.container.read(checkoutControllerProvider).phase,
      CheckoutPhase.idle,
    );
  });
}
