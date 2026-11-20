import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/core/storage/cache_store.dart';
import 'package:ipr_mobile/features/checkout/data/repositories/cache_pending_checkout_store.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/checkout_status.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/payment_state.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/pending_checkout.dart';
import 'package:ipr_mobile/features/checkout/domain/rules/checkout_failure.dart';
import 'package:ipr_mobile/features/checkout/domain/rules/checkout_flow.dart';
import 'package:ipr_mobile/shared/navigation/routes.dart';
import 'package:material_ui/material_ui.dart';

import '../../../unit/features/checkout/support/checkout_fakes.dart';
import 'support/checkout_widget_support.dart';

CheckoutFlowState outcome(CheckoutPhase phase, PaymentState state) =>
    CheckoutFlowState(
      phase: phase,
      checkoutRef: refA,
      order: VerifiedOrder(
        id: 1001,
        number: '1001',
        statusLabel: 'Etiqueta del servidor',
        paymentState: state,
      ),
    );

const String _resultRoute = Routes.checkoutResult;

void main() {
  group(
    'TC-079 · AC-056-9 · AC-056-1 · cada estado, su texto, ícono y acciones',
    () {
      const retryButtons = ['Reintentar pago', 'Volver al carrito'];
      const doneButtons = ['Ver mis pedidos', 'Ir a Inicio'];

      final cases =
          <
            String,
            (
              CheckoutFlowState,
              String,
              IconData,
              List<String>,
              List<String>,
              List<String>,
            )
          >{
            'paid': (
              outcome(CheckoutPhase.paid, PaymentState.paid),
              'Pago confirmado',
              Icons.check_circle_outline,
              doneButtons,
              retryButtons,
              ['Pedido número 1001'],
            ),
            'pending': (
              outcome(CheckoutPhase.pending, PaymentState.pending),
              'Pago en verificación',
              Icons.hourglass_top,
              doneButtons,
              retryButtons,
              [
                'Pedido número 1001',
                'Estado del pedido: Etiqueta del servidor',
              ],
            ),
            'unknown (estado no mapeado)': (
              outcome(CheckoutPhase.pending, PaymentState.unknown),
              'Estado del pedido por confirmar',
              Icons.hourglass_top,
              doneButtons,
              retryButtons,
              [
                'Pedido número 1001',
                'Estado del pedido: Etiqueta del servidor',
              ],
            ),
            'failed': (
              outcome(CheckoutPhase.failed, PaymentState.failed),
              'El pago no se completó',
              Icons.error_outline,
              retryButtons,
              doneButtons,
              ['Pedido número 1001'],
            ),
            'refunded': (
              outcome(CheckoutPhase.failed, PaymentState.refunded),
              'Pedido reembolsado',
              Icons.error_outline,
              retryButtons,
              doneButtons,
              ['Pedido número 1001'],
            ),
            'cancelled': (
              outcome(CheckoutPhase.cancelled, PaymentState.cancelled),
              'Pago cancelado',
              Icons.error_outline,
              retryButtons,
              doneButtons,
              ['Pedido número 1001'],
            ),
            'noOrder': (
              const CheckoutFlowState(
                phase: CheckoutPhase.noOrder,
                checkoutRef: refA,
              ),
              'No encontramos un pedido',
              Icons.search_off,
              ['Verificar de nuevo', ...retryButtons],
              doneButtons,
              [],
            ),
          };

      for (final entry in cases.entries) {
        testWidgets('${entry.key}: texto, ícono y acciones propios', (
          tester,
        ) async {
          final (seed, title, icon, shown, hidden, details) = entry.value;
          await pumpCheckout(tester, start: _resultRoute, seed: seed);

          expect(find.text(title), findsOneWidget);
          expect(find.byIcon(icon), findsOneWidget);
          for (final label in shown) {
            expect(anyButtonLabeled(label), findsOneWidget, reason: label);
          }
          for (final label in hidden) {
            expect(anyButtonLabeled(label), findsNothing, reason: label);
          }
          for (final detail in details) {
            expect(find.text(detail), findsOneWidget, reason: detail);
          }
          if (details.isEmpty) {
            expect(find.textContaining('Pedido número'), findsNothing);
          }
          // Un resultado que no es pagado nunca dice "Pago confirmado".
          if (title != 'Pago confirmado') {
            expect(find.text('Pago confirmado'), findsNothing);
          }
        });
      }

      testWidgets('lo no pagado no promete éxito y conserva el carrito', (
        tester,
      ) async {
        for (final seed in [
          outcome(CheckoutPhase.pending, PaymentState.pending),
          outcome(CheckoutPhase.failed, PaymentState.failed),
          const CheckoutFlowState(
            phase: CheckoutPhase.noOrder,
            checkoutRef: refA,
          ),
        ]) {
          final h = await pumpCheckout(tester, start: _resultRoute, seed: seed);
          expect(find.textContaining('Tu carrito se conserva'), findsOneWidget);
          expect(h.cart.clearCalls, 0);
        }
      });
    },
  );

  group('TC-078 · AC-055-4 · AC-056-6 · el enlace es solo una pista', () {
    testWidgets('status=paid falsificado con el pedido pendiente: pendiente', (
      tester,
    ) async {
      final h = await pumpCheckout(
        tester,
        start: '$_resultRoute?order=1001&status=paid',
        seed: outcome(CheckoutPhase.pending, PaymentState.pending),
      );
      expect(find.text('Pago en verificación'), findsOneWidget);
      expect(find.text('Pago confirmado'), findsNothing);
      expect(h.cart.clearCalls, 0);
    });

    testWidgets('enlace sin pago en curso: nunca "pago exitoso"', (
      tester,
    ) async {
      final h = await pumpCheckout(
        tester,
        start: '$_resultRoute?order=1001&status=paid',
      );
      expect(find.text('No hay un pago en curso'), findsOneWidget);
      expect(find.text('Pago confirmado'), findsNothing);
      expect(find.textContaining('1001'), findsNothing);
      expect(h.repo.statusCalls, isEmpty);
      expect(h.cart.clearCalls, 0);
      expect(anyButtonLabeled('Ver mis pedidos'), findsOneWidget);
    });

    testWidgets('el número del enlace no se usa: manda el del servidor', (
      tester,
    ) async {
      await pumpCheckout(
        tester,
        start: '$_resultRoute?order=999&status=completed',
        seed: outcome(CheckoutPhase.paid, PaymentState.paid),
      );
      expect(find.text('Pedido número 1001'), findsOneWidget);
      expect(find.textContaining('999'), findsNothing);
    });

    testWidgets('pistas basura no rompen la pantalla', (tester) async {
      await pumpCheckout(
        tester,
        start: '$_resultRoute?order=<script>&status=%00',
      );
      expect(find.text('No hay un pago en curso'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('TC-076 · AC-055-1 · AC-055-7 · retorno por enlace', () {
    testWidgets('app esperando el regreso: el enlace consulta al servidor', (
      tester,
    ) async {
      final repo = FakeCheckoutRepository()
        ..statusResults.add(Ok(orderStatus(PaymentState.paid)));
      final h = await pumpCheckout(
        tester,
        start: '$_resultRoute?order=1001&status=paid',
        repo: repo,
        seed: const CheckoutFlowState(
          phase: CheckoutPhase.awaitingResult,
          checkoutRef: refA,
        ),
      );
      expect(repo.statusCalls, [refA]);
      expect(find.text('Pago confirmado'), findsOneWidget);
      expect(h.cart.clearCalls, 1);
    });

    testWidgets('arranque en frío con registro vigente: reanuda y verifica', (
      tester,
    ) async {
      final cache = MemoryCacheStore();
      await CachePendingCheckoutStore(cache).save(
        PendingCheckout(
          checkoutRef: refA,
          attemptId: '00000000-0000-4000-8000-000000000001',
          startedAt: DateTime.utc(2026, 11, 20, 15),
        ),
      );
      final repo = FakeCheckoutRepository()
        ..statusResults.add(Ok(orderStatus(PaymentState.paid)));
      final h = await pumpCheckout(
        tester,
        start: '$_resultRoute?order=1001&status=paid',
        repo: repo,
        cache: cache,
      );
      expect(repo.statusCalls, [refA]);
      expect(repo.createCalls, isEmpty);
      expect(find.text('Pago confirmado'), findsOneWidget);
      expect(h.cart.clearCalls, 1);
      expect(cache.length, 0);
    });

    testWidgets('regreso a primer plano durante la espera consulta el estado', (
      tester,
    ) async {
      final repo = FakeCheckoutRepository()
        ..statusResults.add(Ok(orderStatus(PaymentState.failed)));
      await pumpCheckout(
        tester,
        start: _resultRoute,
        repo: repo,
        seed: const CheckoutFlowState(
          phase: CheckoutPhase.verifying,
          checkoutRef: refA,
        ),
      );
      // Ya verifica por su cuenta; "resumed" no duplica nada en `verifying`.
      expect(find.text('Verificando tu pago con la tienda…'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(tester);
      expect(repo.statusCalls, isEmpty);
    });

    testWidgets('sin historial, atrás lleva a Inicio (AC-055-7)', (
      tester,
    ) async {
      final h = await pumpCheckout(
        tester,
        start: _resultRoute,
        seed: outcome(CheckoutPhase.paid, PaymentState.paid),
      );
      await tester.tap(find.byTooltip('Volver'));
      await settle(tester);
      expect(find.text('PANTALLA INICIO'), findsOneWidget);
      expect(h.location, Routes.home);
    });
  });

  group('M3 · RF-056 · RF-057 · acciones del resultado', () {
    testWidgets('"Ver mis pedidos" y "Ir a Inicio" salen y reinician', (
      tester,
    ) async {
      var h = await pumpCheckout(
        tester,
        start: _resultRoute,
        seed: outcome(CheckoutPhase.paid, PaymentState.paid),
      );
      await tapButton(tester, anyButtonLabeled('Ver mis pedidos'));
      expect(find.text('PANTALLA PEDIDOS'), findsOneWidget);
      expect(h.state(tester).phase, CheckoutPhase.idle);

      h = await pumpCheckout(
        tester,
        start: _resultRoute,
        seed: outcome(CheckoutPhase.pending, PaymentState.pending),
      );
      await tapButton(tester, anyButtonLabeled('Ir a Inicio'));
      expect(find.text('PANTALLA INICIO'), findsOneWidget);
      final state = h.state(tester);
      expect(state.phase, CheckoutPhase.idle);
      expect(state.priorPending, isTrue, reason: 'PA-11: se advertirá');
    });

    testWidgets('"Reintentar pago" vuelve al pago con un intento nuevo', (
      tester,
    ) async {
      final h = await pumpCheckout(
        tester,
        start: _resultRoute,
        seed: outcome(CheckoutPhase.failed, PaymentState.failed),
      );
      await tapButton(tester, anyButtonLabeled('Reintentar pago'));
      expect(h.location, Routes.checkout);
      expect(find.text('Resumen de tu pedido'), findsOneWidget);
      expect(isButtonEnabled(tester, buttonLabeled('Pagar')), isTrue);
      expect(h.state(tester).phase, CheckoutPhase.idle);
      expect(h.cart.clearCalls, 0);
    });

    testWidgets('"Volver al carrito" conserva el carrito', (tester) async {
      final h = await pumpCheckout(
        tester,
        start: _resultRoute,
        seed: outcome(CheckoutPhase.cancelled, PaymentState.cancelled),
      );
      await tapButton(tester, anyButtonLabeled('Volver al carrito'));
      expect(find.text('PANTALLA CARRITO'), findsOneWidget);
      expect(h.cart.lines, twoLines);
    });

    testWidgets('noOrder: "Verificar de nuevo" consulta el mismo ref', (
      tester,
    ) async {
      final repo = FakeCheckoutRepository()
        ..statusResults.add(Ok(orderStatus(PaymentState.paid)));
      final h = await pumpCheckout(
        tester,
        start: _resultRoute,
        repo: repo,
        seed: const CheckoutFlowState(
          phase: CheckoutPhase.noOrder,
          checkoutRef: refA,
        ),
      );
      await tapButton(tester, anyButtonLabeled('Verificar de nuevo'));
      expect(repo.statusCalls, [refA]);
      expect(repo.createCalls, isEmpty);
      expect(find.text('Pago confirmado'), findsOneWidget);
      expect(h.cart.clearCalls, 1);
    });
  });

  group('TC-072 · AC-056-7 · sin poder confirmar', () {
    const unavailable = CheckoutFlowState(
      phase: CheckoutPhase.failure,
      checkoutRef: refA,
      failureKind: CheckoutFailureKind.statusUnavailable,
      pendingVerification: true,
    );

    testWidgets('ni éxito ni fallo, con "Verificar de nuevo"', (tester) async {
      final repo = FakeCheckoutRepository()
        ..statusResults.add(Ok(orderStatus(PaymentState.paid)));
      final h = await pumpCheckout(
        tester,
        start: _resultRoute,
        repo: repo,
        seed: unavailable,
      );
      expect(
        find.text(
          'No pudimos confirmar el estado de tu pago. No lo damos por exitoso ni por fallido; vuelve a verificar.',
        ),
        findsOneWidget,
      );
      expect(find.text('Pago confirmado'), findsNothing);
      expect(find.text('El pago no se completó'), findsNothing);
      expect(h.cart.clearCalls, 0);

      await tapButton(tester, buttonLabeled('Verificar de nuevo'));
      expect(find.text('Pago confirmado'), findsOneWidget);
      expect(repo.createCalls, isEmpty);
      expect(h.cart.clearCalls, 1);
    });

    testWidgets('sesión vencida: sin botón de verificar, con salidas', (
      tester,
    ) async {
      await pumpCheckout(
        tester,
        start: _resultRoute,
        seed: const CheckoutFlowState(
          phase: CheckoutPhase.failure,
          checkoutRef: refA,
          failureKind: CheckoutFailureKind.unauthorized,
          pendingVerification: true,
        ),
      );
      expect(anyButtonLabeled('Verificar de nuevo'), findsNothing);
      expect(anyButtonLabeled('Ver mis pedidos'), findsOneWidget);
      expect(anyButtonLabeled('Volver al carrito'), findsOneWidget);
    });

    testWidgets('un fallo sin ref de verificación no ofrece verificar', (
      tester,
    ) async {
      await pumpCheckout(
        tester,
        start: _resultRoute,
        seed: const CheckoutFlowState(
          phase: CheckoutPhase.failure,
          failureKind: CheckoutFailureKind.noConnection,
        ),
      );
      expect(anyButtonLabeled('Verificar de nuevo'), findsNothing);
    });

    testWidgets('esperando el regreso: progreso y "Continuar verificando"', (
      tester,
    ) async {
      final repo = FakeCheckoutRepository()
        ..statusResults.add(Ok(awaitingStatus()));
      await pumpCheckout(
        tester,
        start: _resultRoute,
        repo: repo,
        seed: const CheckoutFlowState(
          phase: CheckoutPhase.verifying,
          checkoutRef: refA,
        ),
      );
      expect(find.text('Verificando tu pago con la tienda…'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });
  });

  group('M3 · RNF-068 · accesibilidad del resultado', () {
    final states = <String, CheckoutFlowState>{
      'pagado': outcome(CheckoutPhase.paid, PaymentState.paid),
      'pendiente': outcome(CheckoutPhase.pending, PaymentState.pending),
      'fallido': outcome(CheckoutPhase.failed, PaymentState.failed),
      'cancelado': outcome(CheckoutPhase.cancelled, PaymentState.cancelled),
      'reembolsado': outcome(CheckoutPhase.failed, PaymentState.refunded),
      'sin pedido': const CheckoutFlowState(
        phase: CheckoutPhase.noOrder,
        checkoutRef: refA,
      ),
      'sin confirmar': const CheckoutFlowState(
        phase: CheckoutPhase.failure,
        checkoutRef: refA,
        failureKind: CheckoutFailureKind.statusUnavailable,
        pendingVerification: true,
      ),
      'sin pago en curso': const CheckoutFlowState.idle(),
    };

    for (final entry in states.entries) {
      testWidgets('${entry.key}: las 4 guías', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpCheckout(tester, start: _resultRoute, seed: entry.value);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });

      testWidgets('${entry.key}: texto al 200 % sin desbordar', (tester) async {
        await pumpCheckout(
          tester,
          start: _resultRoute,
          seed: entry.value,
          textScale: 2,
        );
        expect(tester.takeException(), isNull);
        // El contenido se desplaza: se llega al último botón.
        final buttons = find.byWidgetPredicate(
          (w) => w is FilledButton || w is OutlinedButton,
        );
        await tester.ensureVisible(buttons.last);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('el resultado se anuncia como región en vivo con encabezado', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpCheckout(
        tester,
        start: _resultRoute,
        seed: outcome(CheckoutPhase.paid, PaymentState.paid),
      );
      final live = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.liveRegion == true,
      );
      expect(live, findsWidgets);
      final header = tester.getSemantics(find.text('Pago confirmado'));
      expect(header.getSemanticsData().flagsCollection.isHeader, isTrue);
      handle.dispose();
    });

    testWidgets('el ícono decorativo no lo lee el lector de pantalla', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpCheckout(
        tester,
        start: _resultRoute,
        seed: outcome(CheckoutPhase.failed, PaymentState.failed),
      );
      expect(
        find.ancestor(
          of: find.byIcon(Icons.error_outline),
          matching: find.byType(ExcludeSemantics),
        ),
        findsWidgets,
      );
      handle.dispose();
    });

    testWidgets('captura bloqueada en el resultado (SC-035)', (tester) async {
      final h = await pumpCheckout(
        tester,
        start: _resultRoute,
        seed: outcome(CheckoutPhase.paid, PaymentState.paid),
      );
      expect(h.protection.enabled, 1);
    });
  });
}
