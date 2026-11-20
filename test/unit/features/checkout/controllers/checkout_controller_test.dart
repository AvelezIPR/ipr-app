import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/config/remote_config.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/core/network/uuid_v4.dart';
import 'package:ipr_mobile/core/session/session_state.dart';
import 'package:ipr_mobile/core/storage/cache_store.dart';
import 'package:ipr_mobile/features/checkout/checkout_providers.dart';
import 'package:ipr_mobile/features/checkout/data/repositories/cache_pending_checkout_store.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/cart_review.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/checkout_line.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/checkout_status.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/checkout_ticket.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/payment_state.dart';
import 'package:ipr_mobile/features/checkout/domain/rules/checkout_failure.dart';
import 'package:ipr_mobile/features/checkout/domain/rules/checkout_flow.dart';
import 'package:ipr_mobile/features/checkout/presentation/controllers/checkout_controller.dart';

import '../support/checkout_fakes.dart';

CheckoutFlowState stateOf(CheckoutHarness h) =>
    h.container.read(checkoutControllerProvider);

CheckoutController controllerOf(CheckoutHarness h) =>
    h.container.read(checkoutControllerProvider.notifier);

/// Deja el flujo esperando el regreso del navegador.
Future<CheckoutHarness> opened({
  FakeCheckoutCart? cart,
  MemoryCacheStore? cache,
  List<Result<CheckoutStatus>>? statuses,
}) async {
  final h = CheckoutHarness(cart: cart, cache: cache);
  addTearDown(h.dispose);
  h.repo.createResults.add(Ok(makeTicket()));
  h.repo.statusResults.addAll(statuses ?? [Ok(orderStatus(PaymentState.paid))]);
  await controllerOf(h).pay();
  expect(stateOf(h).phase, CheckoutPhase.awaitingResult);
  return h;
}

void main() {
  group('TC-067 · AC-052-3 · AC-056-2 · AC-057-1 · compra aprobada', () {
    test('Pagar → ticket → navegador seguro → verificación → pagado', () async {
      final h = CheckoutHarness();
      addTearDown(h.dispose);
      h.repo
        ..createResults.add(Ok(makeTicket()))
        ..statusResults.addAll([
          Ok(awaitingStatus()),
          Ok(orderStatus(PaymentState.paid)),
        ]);

      await controllerOf(h).pay();

      // Se abrió exactamente la URL del ticket, una sola vez.
      expect(h.browser.opened, [ticketUrl()]);
      expect(stateOf(h).phase, CheckoutPhase.awaitingResult);
      expect(stateOf(h).checkoutRef, refA);
      // Antes de verificar el servidor NO se toca el carrito.
      expect(h.cart.clearCalls, 0);
      expect(h.cart.revalidateCalls, 1);

      await controllerOf(h).verifyNow();

      expect(stateOf(h).phase, CheckoutPhase.paid);
      expect(stateOf(h).order?.number, '1001');
      expect(h.repo.statusCalls, [refA, refA]);
      expect(h.clock.sleeps, [const Duration(seconds: 2)]);
      expect(h.cart.clearCalls, 1);
      // El registro de reanudación se borra al terminar.
      expect(h.cache.length, 0);
    });

    test(
      'solo viajan {id, quantity}: las líneas del carrito tal cual',
      () async {
        final h = await opened();
        expect(h.repo.createCalls.single.lines, twoLines);
      },
    );

    test(
      'el registro sin PII se guarda al abrir y solo guarda ref e intento',
      () async {
        final h = await opened();
        expect(h.cache.length, 1);
        final read = await h.cache.read(
          CachePendingCheckoutStore.key,
          CachePolicy.listing,
        );
        expect(read!.value, contains(refA));
        expect(read.value, contains(h.uuids.issued.first));
        expect(read.value, isNot(contains(ticketSecret)));
        expect(read.value, isNot(contains('ipr_ticket')));
      },
    );
  });

  group('TC-066 · SC-023 · AC-052-13 · política de URL (falla cerrado)', () {
    const staging = 'staging.invalid';

    final bad = <String, (Uri, Set<String>)>{
      'http': (
        Uri.parse('http://$staging/?ipr_ticket=$ticketSecret'),
        {staging},
      ),
      'con credenciales': (
        Uri.parse('https://user:pass@$staging/?ipr_ticket=$ticketSecret'),
        {staging},
      ),
      'puerto raro': (
        Uri.parse('https://$staging:8443/?ipr_ticket=$ticketSecret'),
        {staging},
      ),
      'host ajeno': (
        Uri.parse('https://evil.invalid/?ipr_ticket=$ticketSecret'),
        {'evil.invalid'},
      ),
      'host ajeno aunque el servidor lo declare': (
        Uri.parse('https://evil.invalid/?ipr_ticket=$ticketSecret'),
        {'evil.invalid', staging},
      ),
      'sufijo engañoso': (
        Uri.parse('https://$staging.evil.com/?ipr_ticket=$ticketSecret'),
        {staging, '$staging.evil.com'},
      ),
      'prefijo engañoso': (
        Uri.parse('https://evil$staging/?ipr_ticket=$ticketSecret'),
        {staging, 'evil$staging'},
      ),
      'el servidor no declara el host': (
        Uri.parse('https://$staging/?ipr_ticket=$ticketSecret'),
        <String>{},
      ),
      'el servidor declara otro host': (
        Uri.parse('https://$staging/?ipr_ticket=$ticketSecret'),
        {'otro.invalid'},
      ),
      'esquema javascript': (Uri.parse('javascript:alert(1)'), {staging}),
      'esquema intent': (
        Uri.parse('intent://$staging/#Intent;scheme=https;end'),
        {staging},
      ),
    };

    for (final entry in bad.entries) {
      test('${entry.key}: no se abre nada y se puede reintentar', () async {
        final h = CheckoutHarness();
        addTearDown(h.dispose);
        h.repo.createResults.add(
          Ok(
            CheckoutTicket(
              checkoutRef: refA,
              checkoutUrl: entry.value.$1,
              allowedHosts: entry.value.$2,
            ),
          ),
        );

        await controllerOf(h).pay();

        expect(h.browser.opened, isEmpty);
        final state = stateOf(h);
        expect(state.phase, CheckoutPhase.failure);
        expect(state.failureKind, CheckoutFailureKind.urlNotAllowed);
        expect(state.checkoutRef, isNull);
        expect(h.cache.length, 0, reason: 'nada se guarda');
        expect(h.cart.clearCalls, 0);
        // Se puede reintentar con un intento nuevo.
        expect(CheckoutMachine.canStartPayment(state), isTrue);
      });
    }

    test('el host de /config manda: si no lo lista, no se abre', () async {
      final h = CheckoutHarness(
        config: const RemoteConfig(
          checkoutEnabled: true,
          checkoutAllowedHosts: {'otro.invalid'},
        ),
      );
      addTearDown(h.dispose);
      h.repo.createResults.add(Ok(makeTicket()));
      await controllerOf(h).pay();
      expect(h.browser.opened, isEmpty);
      expect(stateOf(h).failureKind, CheckoutFailureKind.urlNotAllowed);
    });

    test('config apagada mientras llegaba el ticket: no se abre', () async {
      final h = CheckoutHarness();
      addTearDown(h.dispose);
      h.repo.createResults.add(Ok(makeTicket()));
      h.repo.createGate = Completer<void>();
      final pay = controllerOf(h).pay();
      await Future<void>.delayed(Duration.zero);
      h.remoteConfig.update(const RemoteConfig());
      h.repo.createGate!.complete();
      await pay;
      expect(h.browser.opened, isEmpty);
      expect(stateOf(h).failureKind, CheckoutFailureKind.urlNotAllowed);
    });

    test('host en mayúsculas del servidor: se normaliza y se abre', () async {
      final h = CheckoutHarness();
      addTearDown(h.dispose);
      h.repo.createResults.add(
        Ok(
          CheckoutTicket(
            checkoutRef: refA,
            checkoutUrl: Uri.parse('https://STAGING.INVALID/?ipr_ticket=x'),
            allowedHosts: const {'staging.invalid'},
          ),
        ),
      );
      await controllerOf(h).pay();
      expect(h.browser.opened, hasLength(1));
      expect(stateOf(h).phase, CheckoutPhase.awaitingResult);
    });

    test('puerto 443 explícito sí pasa', () async {
      final h = CheckoutHarness();
      addTearDown(h.dispose);
      h.repo.createResults.add(
        Ok(
          CheckoutTicket(
            checkoutRef: refA,
            checkoutUrl: Uri.parse('https://staging.invalid:443/?t=1'),
            allowedHosts: const {'staging.invalid'},
          ),
        ),
      );
      await controllerOf(h).pay();
      expect(h.browser.opened, hasLength(1));
    });
  });

  group(
    'TC-147 · AC-052-6 · AC-057-7 · AC-058-7 · una solicitud, una clave',
    () {
      test('la clave es un UUID v4 distinta del id del intento', () async {
        final h = await opened();
        final key = h.repo.createCalls.single.idempotencyKey;
        expect(isUuidV4(key), isTrue);
        expect(key, isNot(h.uuids.issued.first));
      });

      test('doble toque en "Pagar": una sola solicitud', () async {
        final h = CheckoutHarness();
        addTearDown(h.dispose);
        h.repo
          ..createResults.add(Ok(makeTicket()))
          ..createGate = Completer<void>();
        final c = controllerOf(h);

        final first = c.pay();
        final second = c.pay();
        final third = c.pay();
        await Future<void>.delayed(Duration.zero);
        expect(stateOf(h).phase, CheckoutPhase.requestingTicket);
        h.repo.createGate!.complete();
        await Future.wait([first, second, third]);

        expect(h.repo.createCalls, hasLength(1));
        expect(h.cart.revalidateCalls, 1);
        expect(h.browser.opened, hasLength(1));
      });

      test('toque durante la revalidación: se ignora', () async {
        final h = CheckoutHarness();
        addTearDown(h.dispose);
        h.cart.revalidateGate = Completer<void>();
        h.repo.createResults.add(Ok(makeTicket()));
        final c = controllerOf(h);
        final first = c.pay();
        await Future<void>.delayed(Duration.zero);
        expect(stateOf(h).phase, CheckoutPhase.revalidating);
        await c.pay();
        h.cart.revalidateGate!.complete();
        await first;
        expect(h.cart.revalidateCalls, 1);
        expect(h.repo.createCalls, hasLength(1));
      });

      test(
        '5 "Reintentar" rápidos tras un error: una solicitud a la vez',
        () async {
          final h = CheckoutHarness();
          addTearDown(h.dispose);
          h.repo.createResults.addAll([
            const Err(RequestTimeout()),
            Ok(makeTicket()),
          ]);
          final c = controllerOf(h);
          await c.pay();
          expect(stateOf(h).failureKind, CheckoutFailureKind.timeout);

          h.repo.createGate = Completer<void>();
          final retries = [for (var i = 0; i < 5; i++) c.retry()];
          await Future<void>.delayed(Duration.zero);
          h.repo.createGate!.complete();
          await Future.wait(retries);

          expect(h.repo.createCalls, hasLength(2));
        },
      );

      test('reintentar ESE intento reutiliza la misma clave', () async {
        final h = CheckoutHarness();
        addTearDown(h.dispose);
        h.repo.createResults.addAll([
          const Err(NoConnection()),
          const Err(ServiceUnavailable()),
          Ok(makeTicket()),
        ]);
        final c = controllerOf(h);
        await c.pay();
        await c.retry();
        await c.retry();

        expect(h.repo.createCalls, hasLength(3));
        expect(
          h.repo.createCalls.map((c) => c.idempotencyKey).toSet(),
          hasLength(1),
        );
        // Solo se revalidó una vez: es el mismo intento.
        expect(h.cart.revalidateCalls, 1);
        expect(stateOf(h).phase, CheckoutPhase.awaitingResult);
      });

      test('un intento NUEVO del usuario genera una clave nueva', () async {
        final h = CheckoutHarness();
        addTearDown(h.dispose);
        h.repo.createResults.add(Ok(makeTicket()));
        h.repo.statusResults.add(Ok(orderStatus(PaymentState.failed)));
        final c = controllerOf(h);
        await c.pay();
        await c.verifyNow();
        expect(stateOf(h).phase, CheckoutPhase.failed);

        await c.pay();

        expect(h.repo.createCalls, hasLength(2));
        expect(
          h.repo.createCalls[0].idempotencyKey,
          isNot(h.repo.createCalls[1].idempotencyKey),
        );
        expect(h.cart.revalidateCalls, 2);
      });

      test('si el carrito cambió, reintentar NO reutiliza la clave', () async {
        final h = CheckoutHarness();
        addTearDown(h.dispose);
        h.repo.createResults.addAll([
          const Err(RequestTimeout()),
          Ok(makeTicket()),
        ]);
        final c = controllerOf(h);
        await c.pay();
        h.cart.lines = const [CheckoutLine(productId: 1201, quantity: 5)];

        await c.retry();

        expect(h.repo.createCalls, hasLength(2));
        expect(
          h.repo.createCalls[0].idempotencyKey,
          isNot(h.repo.createCalls[1].idempotencyKey),
        );
        expect(h.repo.createCalls[1].lines.single.quantity, 5);
      });

      test('con un intento esperando no se crea otro ticket', () async {
        final h = await opened();
        await controllerOf(h).pay();
        await controllerOf(h).retry();
        expect(h.repo.createCalls, hasLength(1));
        expect(h.browser.opened, hasLength(1));
      });

      test(
        'tras 400/409 el reintento es un intento nuevo (clave nueva)',
        () async {
          final h = CheckoutHarness();
          addTearDown(h.dispose);
          h.repo.createResults.addAll([
            const Err(Conflict(code: 'idempotency_conflict')),
            Ok(makeTicket()),
          ]);
          final c = controllerOf(h);
          await c.pay();
          expect(stateOf(h).failureKind, CheckoutFailureKind.cartInvalid);
          await c.retry();
          expect(h.repo.createCalls, hasLength(2));
          expect(
            h.repo.createCalls[0].idempotencyKey,
            isNot(h.repo.createCalls[1].idempotencyKey),
          );
        },
      );
    },
  );

  group(
    'TC-074 · AC-058-4 · ticket vencido: un único reintento automático',
    () {
      test(
        'se pide otro ticket con la MISMA clave y se abre una vez',
        () async {
          final h = CheckoutHarness();
          addTearDown(h.dispose);
          h.repo.createResults.addAll([
            const Err(ServiceUnavailable(code: 'ticket_expired')),
            Ok(makeTicket()),
          ]);
          await controllerOf(h).pay();

          expect(h.repo.createCalls, hasLength(2));
          expect(
            h.repo.createCalls[0].idempotencyKey,
            h.repo.createCalls[1].idempotencyKey,
          );
          expect(h.browser.opened, hasLength(1));
          expect(stateOf(h).phase, CheckoutPhase.awaitingResult);
        },
      );

      test(
        'si falla otra vez: error, sin más reintentos automáticos',
        () async {
          final h = CheckoutHarness();
          addTearDown(h.dispose);
          h.repo.createResults.add(const Err(Conflict(code: 'ticket_used')));
          await controllerOf(h).pay();

          expect(h.repo.createCalls, hasLength(2));
          expect(stateOf(h).phase, CheckoutPhase.failure);
          expect(stateOf(h).failureKind, CheckoutFailureKind.ticketInvalid);
          expect(h.browser.opened, isEmpty);
          // El usuario puede reintentar manualmente (misma clave).
          await controllerOf(h).retry();
          expect(h.repo.createCalls, hasLength(3));
        },
      );
    },
  );

  group('TC-064 · AC-058-1..3 · AC-058-9 · errores del traspaso', () {
    final cases = <String, (Result<CheckoutTicket>, CheckoutFailureKind)>{
      '401': (const Err(Unauthorized()), CheckoutFailureKind.unauthorized),
      '403': (const Err(Forbidden()), CheckoutFailureKind.forbidden),
      'borde': (const Err(BlockedByEdge()), CheckoutFailureKind.forbidden),
      '429': (
        const Err(RateLimited(retryAfter: 30)),
        CheckoutFailureKind.rateLimited,
      ),
      '502': (
        const Err(ServiceUnavailable()),
        CheckoutFailureKind.storeUnavailable,
      ),
      '503': (
        const Err(ServiceUnavailable(code: 'feature_disabled')),
        CheckoutFailureKind.storeUnavailable,
      ),
      'tiempo agotado': (
        const Err(RequestTimeout()),
        CheckoutFailureKind.timeout,
      ),
      'sin red': (const Err(NoConnection()), CheckoutFailureKind.noConnection),
      'sin ticket válido (201 inválido)': (
        const Err(ContractFailure(detail: 'POST /checkout')),
        CheckoutFailureKind.contract,
      ),
      '500': (const Err(ServerFailure()), CheckoutFailureKind.unknown),
    };

    for (final entry in cases.entries) {
      test('${entry.key}: mensaje, sin navegador, carrito intacto', () async {
        final h = CheckoutHarness();
        addTearDown(h.dispose);
        h.repo.createResults.add(entry.value.$1);

        await controllerOf(h).pay();

        final state = stateOf(h);
        expect(state.phase, CheckoutPhase.failure);
        expect(state.failureKind, entry.value.$2);
        expect(h.browser.opened, isEmpty);
        expect(h.cart.clearCalls, 0);
        expect(h.cart.lines, twoLines);
        expect(h.cache.length, 0);
        expect(
          h.repo.createCalls,
          hasLength(1),
          reason: 'sin reintento de red',
        );
      });
    }

    test('429 conserva la espera sugerida', () async {
      final h = CheckoutHarness();
      addTearDown(h.dispose);
      h.repo.createResults.add(const Err(RateLimited(retryAfter: 30)));
      await controllerOf(h).pay();
      expect(stateOf(h).retryAfterSeconds, 30);
    });

    test('400 vuelve a revalidar; sin cambios: error y NO reenvía', () async {
      final h = CheckoutHarness();
      addTearDown(h.dispose);
      h.repo.createResults.add(const Err(Validation()));
      await controllerOf(h).pay();

      expect(h.cart.revalidateCalls, 2);
      expect(h.repo.createCalls, hasLength(1));
      expect(stateOf(h).phase, CheckoutPhase.failure);
      expect(stateOf(h).failureKind, CheckoutFailureKind.cartInvalid);
      expect(h.cart.clearCalls, 0);
    });

    test('409 con cambios en el carrito: pide revisar', () async {
      final h = CheckoutHarness();
      addTearDown(h.dispose);
      h.cart.reviews
        ..clear()
        ..addAll([
          const Ok(CartReview(checkoutAllowed: true)),
          const Ok(CartReview(checkoutAllowed: true, hasChanges: true)),
        ]);
      h.repo.createResults.add(const Err(Conflict(code: 'cart_changed')));
      await controllerOf(h).pay();

      expect(stateOf(h).phase, CheckoutPhase.needsReview);
      expect(stateOf(h).canContinueAfterReview, isTrue);
      expect(h.repo.createCalls, hasLength(1));

      // El usuario acepta: intento nuevo (clave nueva) y sigue.
      h.repo.createResults
        ..clear()
        ..add(Ok(makeTicket()));
      await controllerOf(h).acceptReview();
      expect(h.repo.createCalls, hasLength(2));
      expect(
        h.repo.createCalls[0].idempotencyKey,
        isNot(h.repo.createCalls[1].idempotencyKey),
      );
      expect(stateOf(h).phase, CheckoutPhase.awaitingResult);
    });

    test(
      'AC-052-8 · sin red al revalidar: mensaje, sin ticket ni navegador',
      () async {
        final h = CheckoutHarness();
        addTearDown(h.dispose);
        h.cart.reviews
          ..clear()
          ..add(const Err(NoConnection()));
        await controllerOf(h).pay();

        expect(stateOf(h).failureKind, CheckoutFailureKind.noConnection);
        expect(h.repo.createCalls, isEmpty);
        expect(h.browser.opened, isEmpty);
        expect(h.cart.clearCalls, 0);
      },
    );

    test('revalidación con 429 conserva la espera', () async {
      final h = CheckoutHarness();
      addTearDown(h.dispose);
      h.cart.reviews
        ..clear()
        ..add(const Err(RateLimited(retryAfter: 12)));
      await controllerOf(h).pay();
      expect(stateOf(h).failureKind, CheckoutFailureKind.rateLimited);
      expect(stateOf(h).retryAfterSeconds, 12);
    });

    test(
      'AC-052-7 · carrito con no disponibles: pide revisar y no hay POST',
      () async {
        final h = CheckoutHarness();
        addTearDown(h.dispose);
        h.cart.reviews
          ..clear()
          ..add(
            const Ok(CartReview(checkoutAllowed: false, hasUnavailable: true)),
          );
        await controllerOf(h).pay();

        expect(stateOf(h).phase, CheckoutPhase.needsReview);
        expect(stateOf(h).canContinueAfterReview, isFalse);
        await controllerOf(h).acceptReview();
        expect(h.repo.createCalls, isEmpty);
      },
    );

    test('un cambio de precio pide confirmación antes del POST', () async {
      final h = CheckoutHarness();
      addTearDown(h.dispose);
      h.cart.reviews
        ..clear()
        ..add(const Ok(CartReview(checkoutAllowed: true, hasChanges: true)));
      h.repo.createResults.add(Ok(makeTicket()));
      await controllerOf(h).pay();
      expect(stateOf(h).phase, CheckoutPhase.needsReview);
      expect(h.repo.createCalls, isEmpty);

      await controllerOf(h).acceptReview();
      expect(h.repo.createCalls, hasLength(1));
    });
  });

  group('TC-061 · RF-052 · AC-052-1 · falla cerrado antes de empezar', () {
    test('checkout apagado (config sin cargar): no se paga', () async {
      final h = CheckoutHarness(config: const RemoteConfig());
      addTearDown(h.dispose);
      await controllerOf(h).pay();

      expect(stateOf(h).phase, CheckoutPhase.failure);
      expect(stateOf(h).failureKind, CheckoutFailureKind.disabled);
      expect(h.cart.revalidateCalls, 0);
      expect(h.repo.createCalls, isEmpty);
      expect(h.browser.opened, isEmpty);
    });

    test('encender el checkout permite pagar después', () async {
      final h = CheckoutHarness(config: const RemoteConfig());
      addTearDown(h.dispose);
      await controllerOf(h).pay();
      h.remoteConfig.update(checkoutOn);
      h.repo.createResults.add(Ok(makeTicket()));
      await controllerOf(h).retry();
      expect(stateOf(h).phase, CheckoutPhase.awaitingResult);
    });

    for (final session in <SessionState>[
      const SessionAnonymous(),
      const SessionExpired(),
      const SessionUnknown(),
    ]) {
      test('sin sesión (${session.runtimeType}): no hay solicitud', () async {
        final h = CheckoutHarness(session: session);
        addTearDown(h.dispose);
        await controllerOf(h).pay();
        expect(stateOf(h).failureKind, CheckoutFailureKind.unauthorized);
        expect(h.repo.createCalls, isEmpty);
        expect(h.cart.revalidateCalls, 0);
      });
    }

    test('carrito vacío: no pasa nada', () async {
      final h = CheckoutHarness(cart: FakeCheckoutCart(lines: const []));
      addTearDown(h.dispose);
      await controllerOf(h).pay();
      expect(stateOf(h).phase, CheckoutPhase.idle);
      expect(h.cart.revalidateCalls, 0);
      expect(h.repo.createCalls, isEmpty);
    });

    test(
      'el reintento del mismo intento también exige sesión y checkout',
      () async {
        final h = CheckoutHarness();
        addTearDown(h.dispose);
        h.repo.createResults.add(const Err(RequestTimeout()));
        await controllerOf(h).pay();
        h.remoteConfig.update(const RemoteConfig());
        await controllerOf(h).retry();
        expect(stateOf(h).failureKind, CheckoutFailureKind.disabled);
        expect(h.repo.createCalls, hasLength(1));
      },
    );

    test('aceptar la revisión exige sesión y checkout', () async {
      final h = CheckoutHarness();
      addTearDown(h.dispose);
      h.cart.reviews
        ..clear()
        ..add(const Ok(CartReview(checkoutAllowed: true, hasChanges: true)));
      await controllerOf(h).pay();
      h.remoteConfig.update(const RemoteConfig());
      await controllerOf(h).acceptReview();
      expect(h.repo.createCalls, isEmpty);
      expect(stateOf(h).phase, CheckoutPhase.failure);
      expect(stateOf(h).failureKind, CheckoutFailureKind.disabled);
    });
  });

  group('TC-066 · RF-052 · el navegador no se pudo abrir', () {
    test(
      'open=false: error, sin registro y se puede reintentar igual',
      () async {
        final h = CheckoutHarness();
        addTearDown(h.dispose);
        h.browser.results.add(false);
        h.repo.createResults.add(Ok(makeTicket()));
        await controllerOf(h).pay();

        expect(stateOf(h).failureKind, CheckoutFailureKind.browserUnavailable);
        expect(h.cache.length, 0);
        expect(h.cart.clearCalls, 0);

        await controllerOf(h).retry();
        expect(stateOf(h).phase, CheckoutPhase.awaitingResult);
        expect(
          h.repo.createCalls[0].idempotencyKey,
          h.repo.createCalls[1].idempotencyKey,
        );
      },
    );

    test('open lanza: se trata como fallo, no revienta', () async {
      final h = CheckoutHarness();
      addTearDown(h.dispose);
      h.browser.throwsOnOpen = true;
      h.repo.createResults.add(Ok(makeTicket()));
      await controllerOf(h).pay();
      expect(stateOf(h).failureKind, CheckoutFailureKind.browserUnavailable);
    });
  });

  group(
    'TC-070 · TC-068 · TC-069 · TC-079 · AC-057-x · matriz de resultados',
    () {
      const matrix = <PaymentState, (CheckoutPhase, bool)>{
        PaymentState.paid: (CheckoutPhase.paid, true),
        PaymentState.pending: (CheckoutPhase.pending, false),
        PaymentState.failed: (CheckoutPhase.failed, false),
        PaymentState.cancelled: (CheckoutPhase.cancelled, false),
        PaymentState.refunded: (CheckoutPhase.failed, false),
        PaymentState.unknown: (CheckoutPhase.pending, false),
      };

      for (final entry in matrix.entries) {
        test('${entry.key.name}: fase ${entry.value.$1.name}, '
            '${entry.value.$2 ? "vacía" : "conserva"} el carrito', () async {
          final h = await opened(statuses: [Ok(orderStatus(entry.key))]);
          await controllerOf(h).verifyNow();

          expect(stateOf(h).phase, entry.value.$1);
          expect(h.cart.clearCalls, entry.value.$2 ? 1 : 0);
          expect(h.cart.lines.isEmpty, entry.value.$2);
          expect(stateOf(h).order?.paymentState, entry.key);
          expect(h.cache.length, 0, reason: 'el registro se borra al terminar');
        });
      }

      test('awaiting_order durante 120 s → noOrder, carrito intacto', () async {
        final h = await opened(statuses: [Ok(awaitingStatus())]);
        await controllerOf(h).verifyNow();

        expect(stateOf(h).phase, CheckoutPhase.noOrder);
        expect(h.clock.sleeps.map((d) => d.inSeconds), [
          2,
          4,
          8,
          16,
          15,
          15,
          15,
          15,
          15,
          15,
        ]);
        expect(h.repo.statusCalls, hasLength(11));
        expect(h.cart.clearCalls, 0);
        expect(stateOf(h).order, isNull);
        expect(h.cache.length, 0);
      });

      test(
        'noOrder: "Verificar de nuevo" no crea otro ticket y puede dar pagado',
        () async {
          final h = await opened(
            statuses: [
              for (var i = 0; i < 11; i++) Ok(awaitingStatus()),
              Ok(orderStatus(PaymentState.paid)),
            ],
          );
          final c = controllerOf(h);
          await c.verifyNow();
          expect(stateOf(h).phase, CheckoutPhase.noOrder);

          await c.continueVerifying();

          expect(stateOf(h).phase, CheckoutPhase.paid);
          expect(h.repo.createCalls, hasLength(1));
          expect(h.cart.clearCalls, 1);
        },
      );

      test(
        'un error transitorio no es el resultado: se sigue sondeando',
        () async {
          final h = await opened(
            statuses: [
              const Err(NoConnection()),
              const Err(ServiceUnavailable()),
              Ok(awaitingStatus()),
              Ok(orderStatus(PaymentState.paid)),
            ],
          );
          await controllerOf(h).verifyNow();
          expect(stateOf(h).phase, CheckoutPhase.paid);
          expect(h.repo.statusCalls, hasLength(4));
        },
      );

      test(
        'AC-056-7 · sin respuesta hasta el final: ni éxito ni fallo',
        () async {
          final h = await opened(statuses: [const Err(RequestTimeout())]);
          await controllerOf(h).verifyNow();

          final state = stateOf(h);
          expect(state.phase, CheckoutPhase.failure);
          expect(state.failureKind, CheckoutFailureKind.statusUnavailable);
          expect(state.pendingVerification, isTrue);
          expect(h.cart.clearCalls, 0);
          // El registro se conserva para poder reanudar.
          expect(h.cache.length, 1);
          // "Reintentar" = volver a verificar el MISMO ref (no otro ticket).
          h.repo.statusResults
            ..clear()
            ..add(Ok(orderStatus(PaymentState.paid)));
          await controllerOf(h).retry();
          expect(stateOf(h).phase, CheckoutPhase.paid);
          expect(h.repo.createCalls, hasLength(1));
          expect(h.cart.clearCalls, 1);
        },
      );

      test(
        'con una verificación sin terminar no se crea otro ticket',
        () async {
          final h = await opened(statuses: [const Err(RequestTimeout())]);
          await controllerOf(h).verifyNow();
          await controllerOf(h).pay();
          expect(h.repo.createCalls, hasLength(1));
        },
      );

      test('401 al verificar: se detiene y espera la sesión', () async {
        final h = await opened(statuses: [const Err(Unauthorized())]);
        await controllerOf(h).verifyNow();

        expect(stateOf(h).failureKind, CheckoutFailureKind.unauthorized);
        expect(stateOf(h).pendingVerification, isTrue);
        expect(h.repo.statusCalls, hasLength(1));
        expect(h.cart.clearCalls, 0);
        expect(h.cache.length, 1);
      });

      test(
        '403 y contrato inválido al verificar también detienen el sondeo',
        () async {
          for (final failure in <AppFailure>[
            const Forbidden(),
            const ContractFailure(),
          ]) {
            final h = await opened(statuses: [Err(failure)]);
            await controllerOf(h).verifyNow();
            expect(stateOf(h).phase, CheckoutPhase.failure);
            expect(h.repo.statusCalls, hasLength(1));
            expect(h.cart.clearCalls, 0);
          }
        },
      );

      test('la respuesta de otro intento no vacía el carrito', () async {
        final h = await opened(
          statuses: [Ok(orderStatus(PaymentState.paid, ref: refB))],
        );
        await controllerOf(h).verifyNow();
        expect(stateOf(h).phase, CheckoutPhase.failure);
        expect(stateOf(h).failureKind, CheckoutFailureKind.contract);
        expect(h.cart.clearCalls, 0);
      });

      test(
        'si no se puede vaciar el carrito, sigue pagado y el registro queda',
        () async {
          final cart = FakeCheckoutCart()..clearThrows = true;
          final h = await opened(cart: cart);
          await controllerOf(h).verifyNow();
          expect(stateOf(h).phase, CheckoutPhase.paid);
          expect(h.cache.length, 1);
        },
      );

      test(
        'AC-057-9 · cerrar el navegador sin verificar no vacía el carrito',
        () async {
          final h = await opened();
          expect(h.cart.clearCalls, 0);
          controllerOf(h).onAppResumed(); // dispara la verificación
          await Future<void>.delayed(Duration.zero);
          await Future<void>.delayed(Duration.zero);
          // Solo el servidor decide: ahora sí es paid.
          expect(stateOf(h).phase, CheckoutPhase.paid);
          expect(h.cart.clearCalls, 1);
        },
      );

      test(
        'regreso a primer plano fuera de awaitingResult no hace nada',
        () async {
          final h = CheckoutHarness();
          addTearDown(h.dispose);
          controllerOf(h).onAppResumed();
          await Future<void>.delayed(Duration.zero);
          expect(h.repo.statusCalls, isEmpty);
          expect(stateOf(h).phase, CheckoutPhase.idle);
        },
      );
    },
  );

  group(
    'TC-071 · TC-072 · AC-055-3 · AC-057-8 · reanudar tras un cierre forzado',
    () {
      test(
        'un registro vigente reanuda en verifying y vacía solo con paid',
        () async {
          final cache = MemoryCacheStore();
          final first = await opened(cache: cache);
          expect(cache.length, 1);
          first.dispose(); // el sistema mata la app

          final second = CheckoutHarness(cache: cache);
          addTearDown(second.dispose);
          second.repo.statusResults.add(Ok(orderStatus(PaymentState.paid)));
          await controllerOf(second).restorePending();

          expect(second.repo.statusCalls, [refA]);
          expect(second.repo.createCalls, isEmpty, reason: 'sin otro ticket');
          expect(stateOf(second).phase, CheckoutPhase.paid);
          expect(second.cart.clearCalls, 1);
          expect(cache.length, 0);
        },
      );

      test(
        'reanudado y pendiente: carrito intacto, registro borrado',
        () async {
          final cache = MemoryCacheStore();
          (await opened(cache: cache)).dispose();
          final second = CheckoutHarness(cache: cache);
          addTearDown(second.dispose);
          second.repo.statusResults.add(Ok(orderStatus(PaymentState.pending)));
          await controllerOf(second).restorePending();
          expect(stateOf(second).phase, CheckoutPhase.pending);
          expect(second.cart.clearCalls, 0);
          expect(cache.length, 0);
        },
      );

      test('sin registro no se reanuda nada', () async {
        final h = CheckoutHarness();
        addTearDown(h.dispose);
        await controllerOf(h).restorePending();
        expect(stateOf(h).phase, CheckoutPhase.idle);
        expect(h.repo.statusCalls, isEmpty);
      });

      test('sin sesión no se reanuda', () async {
        final cache = MemoryCacheStore();
        (await opened(cache: cache)).dispose();
        final second = CheckoutHarness(
          cache: cache,
          session: const SessionAnonymous(),
        );
        addTearDown(second.dispose);
        await controllerOf(second).restorePending();
        expect(stateOf(second).phase, CheckoutPhase.idle);
        expect(second.repo.statusCalls, isEmpty);
      });

      test(
        'resumeFromReturn: sin intento y con registro verifica; sin nada, no',
        () async {
          final cache = MemoryCacheStore();
          (await opened(cache: cache)).dispose();
          final second = CheckoutHarness(cache: cache);
          addTearDown(second.dispose);
          second.repo.statusResults.add(
            Ok(orderStatus(PaymentState.cancelled)),
          );
          await controllerOf(second).resumeFromReturn();
          expect(stateOf(second).phase, CheckoutPhase.cancelled);

          final empty = CheckoutHarness();
          addTearDown(empty.dispose);
          await controllerOf(empty).resumeFromReturn();
          expect(stateOf(empty).phase, CheckoutPhase.idle);
          expect(empty.repo.statusCalls, isEmpty);
        },
      );

      test(
        'resumeFromReturn con el intento esperando consulta al servidor',
        () async {
          final h = await opened();
          await controllerOf(h).resumeFromReturn();
          expect(stateOf(h).phase, CheckoutPhase.paid);
        },
      );

      test('un estado ocupado no se pisa al restaurar', () async {
        final h = await opened();
        await controllerOf(h).restorePending();
        expect(stateOf(h).phase, CheckoutPhase.awaitingResult);
        expect(h.repo.statusCalls, isEmpty);
      });

      test('mientras se verifica, "Pagar" no crea otro ticket', () async {
        final cache = MemoryCacheStore();
        (await opened(cache: cache)).dispose();
        // La espera del sondeo no termina: se queda en `verifying`.
        final never = Completer<void>();
        final second = CheckoutHarness(
          cache: cache,
          sleep: (_) => never.future,
        );
        addTearDown(second.dispose);
        second.repo.statusResults.add(Ok(awaitingStatus()));
        unawaited(controllerOf(second).restorePending());
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expect(stateOf(second).phase, CheckoutPhase.verifying);
        await controllerOf(second).pay();
        await controllerOf(second).retry();
        expect(second.repo.createCalls, isEmpty);
        expect(stateOf(second).phase, CheckoutPhase.verifying);
      });

      test('prepare reanuda un registro vigente', () async {
        final cache = MemoryCacheStore();
        (await opened(cache: cache)).dispose();
        final second = CheckoutHarness(cache: cache);
        addTearDown(second.dispose);
        second.repo.statusResults.add(Ok(orderStatus(PaymentState.failed)));
        controllerOf(second).prepare();
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expect(stateOf(second).phase, CheckoutPhase.failed);
      });
    },
  );

  group('M3 · RF-044 · RF-045 · sesión y salida', () {
    test('cerrar sesión: se descarta el estado y el registro', () async {
      final h = await opened();
      h.sessionController.set(const SessionAnonymous());
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(stateOf(h).phase, CheckoutPhase.idle);
      expect(h.cache.length, 0);
      expect(h.cart.clearCalls, 0);
    });

    test(
      'sesión vencida: se descarta el estado pero se conserva el registro',
      () async {
        final h = await opened();
        h.sessionController.set(const SessionExpired());
        await Future<void>.delayed(Duration.zero);
        expect(stateOf(h).phase, CheckoutPhase.idle);
        expect(h.cache.length, 1);
      },
    );

    test('una respuesta que llega tras cerrar sesión se descarta', () async {
      final h = CheckoutHarness();
      addTearDown(h.dispose);
      h.repo
        ..createResults.add(Ok(makeTicket()))
        ..createGate = Completer<void>();
      final pay = controllerOf(h).pay();
      await Future<void>.delayed(Duration.zero);
      h.sessionController.set(const SessionAnonymous());
      await Future<void>.delayed(Duration.zero);
      h.repo.createGate!.complete();
      await pay;
      expect(
        h.browser.opened,
        isEmpty,
        reason: 'no se abre tras cerrar sesión',
      );
      expect(stateOf(h).phase, CheckoutPhase.idle);
    });

    test('reset no interrumpe un intento en curso', () async {
      final h = await opened();
      controllerOf(h).reset();
      expect(stateOf(h).phase, CheckoutPhase.awaitingResult);
    });

    test(
      'reset desde un resultado vuelve a reposo (pendiente se recuerda)',
      () async {
        final h = await opened(
          statuses: [Ok(orderStatus(PaymentState.pending))],
        );
        await controllerOf(h).verifyNow();
        controllerOf(h).reset();
        expect(stateOf(h).phase, CheckoutPhase.idle);
        expect(stateOf(h).priorPending, isTrue);
      },
    );

    test(
      'prepare descarta resultados viejos pero no un intento en curso',
      () async {
        final h = await opened(
          statuses: [Ok(orderStatus(PaymentState.failed))],
        );
        controllerOf(h).prepare();
        await Future<void>.delayed(Duration.zero);
        expect(stateOf(h).phase, CheckoutPhase.awaitingResult);

        await controllerOf(h).verifyNow();
        expect(stateOf(h).phase, CheckoutPhase.failed);
        controllerOf(h).prepare();
        await Future<void>.delayed(Duration.zero);
        expect(stateOf(h).phase, CheckoutPhase.idle);
      },
    );

    test('prepare conserva una verificación sin terminar', () async {
      final h = await opened(statuses: [const Err(RequestTimeout())]);
      await controllerOf(h).verifyNow();
      controllerOf(h).prepare();
      await Future<void>.delayed(Duration.zero);
      expect(stateOf(h).phase, CheckoutPhase.failure);
      expect(stateOf(h).pendingVerification, isTrue);
    });

    test('el gancho de sesión borra el registro', () async {
      final h = await opened();
      expect(h.cache.length, 1);
      final hook = h.container.read(checkoutSessionHookProvider);
      await hook.onLogout();
      expect(h.cache.length, 0);

      final again = await opened();
      await again.container
          .read(checkoutSessionHookProvider)
          .onAccountDeleted();
      expect(again.cache.length, 0);
    });
  });

  group(
    'TC-053 · AC-053-3 · SC-023 · el ticket no aparece en ninguna parte',
    () {
      test(
        'ni en el estado, ni en toString, ni en la caché, ni en la salida',
        () async {
          final logs = <String>[];
          final seen = <String>[];
          await runZoned(
            () async {
              final h = CheckoutHarness();
              addTearDown(h.dispose);
              h.repo
                ..createResults.add(Ok(makeTicket()))
                ..statusResults.addAll([
                  Ok(awaitingStatus()),
                  Ok(orderStatus(PaymentState.paid)),
                ]);
              final c = controllerOf(h);
              h.container.listen(checkoutControllerProvider, (previous, next) {
                seen
                  ..add(next.toString())
                  ..add(next.attempt.toString())
                  ..add(next.review.toString())
                  ..add(next.order.toString());
              });
              await c.pay();
              seen.add(stateOf(h).toString());
              await c.verifyNow();
              seen.add(stateOf(h).toString());
              // Caché: solo el registro de reanudación (borrado al terminar).
              expect(h.cache.length, 0);
            },
            zoneSpecification: ZoneSpecification(
              print: (self, parent, zone, line) => logs.add(line),
            ),
          );
          final everything = [...logs, ...seen].join('\n');
          expect(everything, isNot(contains(ticketSecret)));
          expect(everything, isNot(contains('ipr_ticket')));
          expect(everything, isNot(contains('staging.invalid')));
        },
      );

      test(
        'un fallo de URL no deja el ticket en el estado ni en errores',
        () async {
          final h = CheckoutHarness();
          addTearDown(h.dispose);
          h.repo.createResults.add(
            Ok(makeTicket(url: ticketUrl(host: 'evil.invalid'))),
          );
          await controllerOf(h).pay();
          expect(stateOf(h).toString(), isNot(contains(ticketSecret)));
          expect(stateOf(h).toString(), isNot(contains('evil.invalid')));
          expect(h.cache.length, 0);
        },
      );

      test(
        'el registro de reanudación no contiene la URL ni el ticket',
        () async {
          final h = await opened();
          final raw = (await h.cache.read(
            CachePendingCheckoutStore.key,
            CachePolicy.listing,
          ))!.value;
          expect(raw, isNot(contains(ticketSecret)));
          expect(raw, isNot(contains('https')));
        },
      );
    },
  );

  group('M3 · RF-050 · carrito sin cambios', () {
    test('las líneas del resumen vienen del carrito', () {
      final h = CheckoutHarness();
      addTearDown(h.dispose);
      expect(h.container.read(checkoutLinesProvider), twoLines);
    });
  });
}
