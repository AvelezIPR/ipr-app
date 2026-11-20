import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/config/remote_config.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/core/session/session_state.dart';
import 'package:ipr_mobile/core/storage/cache_store.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/cart_review.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/checkout_line.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/checkout_ticket.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/payment_state.dart';
import 'package:ipr_mobile/features/checkout/domain/rules/checkout_flow.dart';
import 'package:ipr_mobile/shared/navigation/routes.dart';
import 'package:material_ui/material_ui.dart';

import '../../../unit/features/checkout/support/checkout_fakes.dart';
import 'support/checkout_widget_support.dart';

const _secureNotice =
    'El pago se completa de forma segura en tu navegador; no guardamos datos de tarjeta.';

void main() {
  group('TC-061 · RF-052 · RF-053 · pantalla de pago en reposo', () {
    testWidgets('resumen de solo lectura, avisos y botón Pagar', (
      tester,
    ) async {
      await pumpCheckout(tester);

      expect(find.text('Pagar'), findsWidgets);
      expect(find.text('Resumen de tu pedido'), findsOneWidget);
      expect(find.text('Filtro de aire'), findsOneWidget);
      expect(find.text('Compresor 12.000 BTU'), findsOneWidget);
      expect(find.text('Cantidad: 2'), findsOneWidget);
      expect(find.text('Cantidad: 1'), findsOneWidget);
      // RF-053: aviso de seguridad y de conexión.
      expect(find.text(_secureNotice), findsOneWidget);
      expect(
        find.text('Necesitas conexión a internet para pagar.'),
        findsOneWidget,
      );
      expect(
        find.text('El precio final lo confirma la tienda al pagar.'),
        findsOneWidget,
      );
      expect(isButtonEnabled(tester, buttonLabeled('Pagar')), isTrue);
    });

    testWidgets('nunca muestra precios ni medios de pago (D-02, PA-12)', (
      tester,
    ) async {
      await pumpCheckout(tester);
      expect(find.textContaining(r'$'), findsNothing);
      for (final method in ['Visa', 'Mastercard', 'PSE', 'Nequi', 'tarjeta']) {
        expect(
          find.textContaining(RegExp(method, caseSensitive: false)),
          // «tarjeta» solo aparece en el aviso de que NO se guardan datos.
          method == 'tarjeta' ? findsOneWidget : findsNothing,
          reason: method,
        );
      }
    });

    testWidgets('línea sin nombre se muestra por referencia', (tester) async {
      await pumpCheckout(
        tester,
        cart: FakeCheckoutCart(
          lines: const [CheckoutLine(productId: 77, quantity: 3)],
        ),
      );
      expect(find.text('Producto 77'), findsOneWidget);
    });

    testWidgets('captura bloqueada mientras está visible (SC-035)', (
      tester,
    ) async {
      final h = await pumpCheckout(tester);
      expect(h.protection.enabled, 1);
      expect(h.protection.disabled, 0);
      h.router.go(Routes.home);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(h.protection.disabled, 1);
    });

    testWidgets('carrito vacío: estado vacío con salida al catálogo', (
      tester,
    ) async {
      final h = await pumpCheckout(
        tester,
        cart: FakeCheckoutCart(lines: const []),
      );
      expect(find.text('Tu carrito está vacío'), findsOneWidget);
      expect(find.text('Pagar'), findsOneWidget); // solo el título
      await tapButton(tester, buttonLabeled('Ver catálogo'));
      expect(find.text('PANTALLA CATALOGO'), findsOneWidget);
      expect(h.repo.createCalls, isEmpty);
    });

    testWidgets('AC-052-7 · checkout apagado: mensaje y botón deshabilitado', (
      tester,
    ) async {
      final h = await pumpCheckout(tester, config: const RemoteConfig());
      expect(
        find.text(
          'El pago desde la app no está disponible por ahora. Tu carrito se conserva.',
        ),
        findsOneWidget,
      );
      expect(isButtonEnabled(tester, buttonLabeled('Pagar')), isFalse);
      await tester.tap(buttonLabeled('Pagar'), warnIfMissed: false);
      await settle(tester);
      expect(h.repo.createCalls, isEmpty);
      expect(h.cart.revalidateCalls, 0);
    });

    testWidgets('el cambio remoto enciende el botón sin reiniciar', (
      tester,
    ) async {
      final h = await pumpCheckout(tester, config: const RemoteConfig());
      expect(isButtonEnabled(tester, buttonLabeled('Pagar')), isFalse);
      h.remoteConfig.update(checkoutOn);
      await settle(tester);
      expect(isButtonEnabled(tester, buttonLabeled('Pagar')), isTrue);
    });
  });

  group('TC-062 · AC-052-6 · AC-057-7 · una solicitud por intención', () {
    testWidgets(
      'doble toque: una solicitud, botón deshabilitado con progreso',
      (tester) async {
        final repo = FakeCheckoutRepository()
          ..createResults.add(Ok(makeTicket()))
          ..createGate = Completer<void>();
        final h = await pumpCheckout(tester, repo: repo);

        await tester.tap(buttonLabeled('Pagar'));
        await tester.pump();
        await tester.tap(find.byType(FilledButton).first, warnIfMissed: false);
        await tester.pump();
        await settle(tester);

        expect(repo.createCalls, hasLength(1));
        expect(h.cart.revalidateCalls, 1);
        expect(isButtonEnabled(tester, buttonLabeled('Procesando…')), isFalse);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        expect(find.text('Preparando el pago seguro…'), findsOneWidget);

        repo.createGate!.complete();
        await settle(tester);
        expect(repo.createCalls, hasLength(1));
      },
    );
  });

  group('TC-066 · TC-067 · RF-052 · RF-055 · del pago al resultado', () {
    testWidgets('abre el navegador seguro y espera; luego verifica y navega', (
      tester,
    ) async {
      final repo = FakeCheckoutRepository()
        ..createResults.add(Ok(makeTicket()))
        ..statusResults.add(Ok(orderStatus(PaymentState.paid)));
      final h = await pumpCheckout(tester, repo: repo);

      await tapButton(tester, buttonLabeled('Pagar'));

      expect(h.browser.opened, [ticketUrl()]);
      expect(
        find.text(
          'Completa el pago en el navegador. Cuando termines, vuelve a la app y toca «Continuar verificando».',
        ),
        findsOneWidget,
      );
      // Con un intento esperando NO hay botón "Pagar": solo continuar.
      expect(buttonLabeled('Pagar'), findsNothing);
      expect(h.cart.clearCalls, 0);

      await tapButton(tester, buttonLabeled('Continuar verificando'));

      expect(h.location, Routes.checkoutResult);
      expect(find.text('Pago confirmado'), findsOneWidget);
      expect(find.text('Pedido número 1001'), findsOneWidget);
      expect(h.cart.clearCalls, 1);
    });

    testWidgets('volver a primer plano verifica sin tocar nada (AC-055-3)', (
      tester,
    ) async {
      final repo = FakeCheckoutRepository()
        ..createResults.add(Ok(makeTicket()))
        ..statusResults.add(Ok(orderStatus(PaymentState.pending)));
      final h = await pumpCheckout(tester, repo: repo);
      await tapButton(tester, buttonLabeled('Pagar'));
      expect(h.location, Routes.checkout);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(tester);

      expect(repo.statusCalls, [refA]);
      expect(h.location, Routes.checkoutResult);
      expect(find.text('Pago en verificación'), findsOneWidget);
      expect(h.cart.clearCalls, 0);
    });

    testWidgets('semilla verifying: texto, progreso y botón deshabilitado', (
      tester,
    ) async {
      await pumpCheckout(
        tester,
        seed: const CheckoutFlowState(
          phase: CheckoutPhase.verifying,
          checkoutRef: refA,
        ),
      );
      expect(find.text('Verificando tu pago con la tienda…'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsWidgets);
      expect(isButtonEnabled(tester, buttonLabeled('Verificando…')), isFalse);
    });

    testWidgets(
      'PA-11 · tras un pedido pendiente se advierte antes de pagar de nuevo',
      (tester) async {
        await pumpCheckout(
          tester,
          seed: const CheckoutFlowState.idle(priorPending: true),
        );
        expect(
          find.textContaining('Tienes un pedido con pago en verificación'),
          findsOneWidget,
        );
        // Se advierte, no se bloquea.
        expect(isButtonEnabled(tester, buttonLabeled('Pagar')), isTrue);
      },
    );
  });

  group('TC-064 · AC-058-1..9 · errores legibles con "Reintentar"', () {
    Future<CheckoutWidgetHarness> payWith(
      WidgetTester tester,
      Result<CheckoutTicket> result, {
      FakeCheckoutCart? cart,
    }) async {
      final repo = FakeCheckoutRepository()..createResults.add(result);
      final h = await pumpCheckout(tester, repo: repo, cart: cart);
      await tapButton(tester, buttonLabeled('Pagar'));
      return h;
    }

    testWidgets('503: "No se pudo conectar con la tienda" y reintenta', (
      tester,
    ) async {
      final repo = FakeCheckoutRepository()
        ..createResults.addAll([
          const Err(ServiceUnavailable()),
          Ok(makeTicket()),
        ]);
      final h = await pumpCheckout(tester, repo: repo);
      await tapButton(tester, buttonLabeled('Pagar'));

      expect(
        find.text(
          'No se pudo conectar con la tienda, inténtalo de nuevo. Tu carrito sigue intacto.',
        ),
        findsOneWidget,
      );
      expect(h.browser.opened, isEmpty);
      expect(h.cart.clearCalls, 0);

      await tapButton(tester, buttonLabeled('Reintentar'));
      expect(h.browser.opened, hasLength(1));
      expect(
        repo.createCalls[0].idempotencyKey,
        repo.createCalls[1].idempotencyKey,
      );
    });

    testWidgets('sin red: mensaje de conexión, no abre nada (AC-052-8)', (
      tester,
    ) async {
      final repo = FakeCheckoutRepository();
      final cart = FakeCheckoutCart(reviews: [const Err(NoConnection())]);
      final h = await pumpCheckout(tester, repo: repo, cart: cart);
      await tapButton(tester, buttonLabeled('Pagar'));

      expect(
        find.text(
          'No tienes conexión. Conéctate a internet para pagar; tu carrito sigue intacto.',
        ),
        findsOneWidget,
      );
      expect(repo.createCalls, isEmpty);
      expect(h.browser.opened, isEmpty);
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets('429: cuenta regresiva y el botón se habilita al terminar', (
      tester,
    ) async {
      final repo = FakeCheckoutRepository()
        ..createResults.addAll([
          const Err(RateLimited(retryAfter: 3)),
          Ok(makeTicket()),
        ]);
      final h = await pumpCheckout(tester, repo: repo);
      await tapButton(tester, buttonLabeled('Pagar'));

      expect(
        find.text(
          'Hiciste demasiados intentos. Espera un momento y vuelve a intentar.',
        ),
        findsOneWidget,
      );
      expect(find.text('Podrás reintentar en 3 s'), findsOneWidget);
      expect(isButtonEnabled(tester, buttonLabeled('Reintentar')), isFalse);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Podrás reintentar en 2 s'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(find.textContaining('Podrás reintentar'), findsNothing);
      expect(isButtonEnabled(tester, buttonLabeled('Reintentar')), isTrue);

      await tapButton(tester, buttonLabeled('Reintentar'));
      expect(h.browser.opened, hasLength(1));
    });

    testWidgets('429 sin Retry-After: el botón sigue habilitado', (
      tester,
    ) async {
      await payWith(tester, const Err(RateLimited()));
      expect(isButtonEnabled(tester, buttonLabeled('Reintentar')), isTrue);
      expect(find.textContaining('Podrás reintentar'), findsNothing);
    });

    testWidgets('400: pide revisar el carrito y no muestra códigos', (
      tester,
    ) async {
      final h = await payWith(tester, const Err(Validation()));
      expect(
        find.text(
          'Tu carrito cambió o la tienda no lo aceptó. Revísalo e inténtalo de nuevo.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('validation'), findsNothing);
      expect(find.textContaining('400'), findsNothing);
      expect(h.cart.revalidateCalls, 2);
      expect(find.text('Reintentar'), findsOneWidget);
      await tapButton(tester, anyButtonLabeled('Revisar carrito'));
      expect(h.location, Routes.cart);
    });

    testWidgets('409: mismo tratamiento que 400', (tester) async {
      await payWith(tester, const Err(Conflict(code: 'idempotency_conflict')));
      expect(find.text('Revisar carrito'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.textContaining('idempotency'), findsNothing);
    });

    testWidgets('401: invita a iniciar sesión conservando el carrito', (
      tester,
    ) async {
      final h = await payWith(tester, const Err(Unauthorized()));
      expect(
        find.text(
          'Tu sesión terminó. Inicia sesión para continuar; tu carrito se conserva.',
        ),
        findsOneWidget,
      );
      expect(find.text('Reintentar'), findsNothing);
      await tapButton(tester, buttonLabeled('Iniciar sesión'));
      expect(find.text('PANTALLA LOGIN'), findsOneWidget);
      expect(h.cart.clearCalls, 0);
    });

    testWidgets('403: sin reintento, sin nombres internos (AC-058-5)', (
      tester,
    ) async {
      await payWith(tester, const Err(Forbidden()));
      expect(
        find.text(
          'No pudimos iniciar el pago desde esta cuenta. Intenta más tarde o contáctanos.',
        ),
        findsOneWidget,
      );
      expect(find.text('Reintentar'), findsNothing);
      expect(find.textContaining('configuración'), findsNothing);
      expect(find.textContaining('secret'), findsNothing);
    });

    testWidgets('URL no permitida: mensaje claro, no se abre nada', (
      tester,
    ) async {
      final repo = FakeCheckoutRepository()
        ..createResults.add(
          Ok(makeTicket(url: ticketUrl(host: 'evil.invalid'))),
        );
      final h = await pumpCheckout(tester, repo: repo);
      await tapButton(tester, buttonLabeled('Pagar'));
      expect(
        find.text(
          'Por seguridad no abrimos el enlace de pago que recibimos. Inténtalo de nuevo.',
        ),
        findsOneWidget,
      );
      expect(h.browser.opened, isEmpty);
      expect(find.textContaining('evil.invalid'), findsNothing);
      expect(find.textContaining(ticketSecret), findsNothing);
    });

    testWidgets('navegador sin abrir: mensaje y reintento', (tester) async {
      final repo = FakeCheckoutRepository()
        ..createResults.add(Ok(makeTicket()));
      final browser = FakeSecureBrowser()..results.add(false);
      final h = await pumpCheckout(tester, repo: repo, browser: browser);
      await tapButton(tester, buttonLabeled('Pagar'));
      expect(
        find.text(
          'No pudimos abrir el navegador para el pago. Inténtalo de nuevo.',
        ),
        findsOneWidget,
      );
      await tapButton(tester, buttonLabeled('Reintentar'));
      expect(h.browser.opened, hasLength(2));
      expect(find.text('Continuar verificando'), findsOneWidget);
    });

    testWidgets('sin sesión al tocar: pide iniciar sesión', (tester) async {
      await pumpCheckout(tester, sessionState: const SessionExpired());
      await tapButton(tester, buttonLabeled('Pagar'));
      expect(find.text('Iniciar sesión'), findsOneWidget);
    });

    testWidgets('contrato inválido y tiempo agotado: mensajes distintos', (
      tester,
    ) async {
      await payWith(tester, const Err(ContractFailure()));
      expect(
        find.text('La tienda respondió algo inesperado. Inténtalo de nuevo.'),
        findsOneWidget,
      );
    });

    testWidgets('error desconocido: mensaje genérico', (tester) async {
      await payWith(tester, const Err(ServerFailure()));
      expect(find.text('Algo salió mal. Inténtalo de nuevo.'), findsOneWidget);
    });

    testWidgets('tiempo agotado y ticket inválido tienen su texto', (
      tester,
    ) async {
      await payWith(tester, const Err(RequestTimeout()));
      expect(
        find.text(
          'La tienda tardó demasiado en responder. Inténtalo de nuevo; tu carrito sigue intacto.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('ticket inválido tras el reintento automático', (tester) async {
      await payWith(
        tester,
        const Err(ServiceUnavailable(code: 'ticket_expired')),
      );
      expect(
        find.text(
          'No pudimos preparar el pago. Inténtalo de nuevo; tu carrito sigue intacto.',
        ),
        findsOneWidget,
      );
    });
  });

  group('TC-064 · RF-050 · revisión antes de pagar', () {
    testWidgets('cambios: pide confirmar y continúa', (tester) async {
      final cart = FakeCheckoutCart(
        reviews: [
          const Ok(CartReview(checkoutAllowed: true, hasChanges: true)),
        ],
      );
      final repo = FakeCheckoutRepository()
        ..createResults.add(Ok(makeTicket()));
      final h = await pumpCheckout(tester, repo: repo, cart: cart);
      await tapButton(tester, buttonLabeled('Pagar'));

      expect(find.text('Revisa tu carrito antes de pagar'), findsOneWidget);
      expect(
        find.text('Algunos precios o cantidades cambiaron.'),
        findsOneWidget,
      );
      expect(repo.createCalls, isEmpty);

      await tapButton(tester, buttonLabeled('Continuar con el pago'));
      expect(repo.createCalls, hasLength(1));
      expect(h.browser.opened, hasLength(1));
    });

    testWidgets('no disponibles: no se puede continuar, solo revisar', (
      tester,
    ) async {
      final cart = FakeCheckoutCart(
        reviews: [
          const Ok(CartReview(checkoutAllowed: false, hasUnavailable: true)),
        ],
      );
      final h = await pumpCheckout(tester, cart: cart);
      await tapButton(tester, buttonLabeled('Pagar'));

      expect(
        find.text('Algunos productos ya no están disponibles.'),
        findsOneWidget,
      );
      expect(
        find.text('No se puede pagar hasta que ajustes el carrito.'),
        findsOneWidget,
      );
      expect(find.text('Continuar con el pago'), findsNothing);
      await tapButton(tester, buttonLabeled('Revisar carrito'));
      expect(h.location, Routes.cart);
      expect(h.repo.createCalls, isEmpty);
    });
  });

  group('TC-071 · AC-057-8 · reanudar al abrir la pantalla', () {
    testWidgets('con un registro vigente verifica y muestra el resultado', (
      tester,
    ) async {
      final cache = MemoryCacheStore();
      final repo1 = FakeCheckoutRepository()
        ..createResults.add(Ok(makeTicket()));
      await pumpCheckout(tester, repo: repo1, cache: cache);
      await tapButton(tester, buttonLabeled('Pagar'));
      expect(cache.length, 1);

      // "Cierre forzado": se monta de nuevo todo con la misma caché.
      final repo2 = FakeCheckoutRepository()
        ..statusResults.add(Ok(orderStatus(PaymentState.paid)));
      final h = await pumpCheckout(tester, repo: repo2, cache: cache);

      expect(repo2.statusCalls, [refA]);
      expect(repo2.createCalls, isEmpty);
      expect(h.location, Routes.checkoutResult);
      expect(find.text('Pago confirmado'), findsOneWidget);
    });
  });

  group('M3 · RNF-068 · RNF-070..076 · accesibilidad', () {
    Future<void> guidelines(WidgetTester tester) async {
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    }

    testWidgets('reposo: las 4 guías', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpCheckout(tester);
      await guidelines(tester);
      handle.dispose();
    });

    testWidgets('error con reintento: las 4 guías', (tester) async {
      final handle = tester.ensureSemantics();
      final repo = FakeCheckoutRepository()
        ..createResults.add(const Err(ServiceUnavailable()));
      await pumpCheckout(tester, repo: repo);
      await tapButton(tester, buttonLabeled('Pagar'));
      expect(find.text('Reintentar'), findsOneWidget);
      await guidelines(tester);
      handle.dispose();
    });

    testWidgets('esperando el regreso: las 4 guías', (tester) async {
      final handle = tester.ensureSemantics();
      final repo = FakeCheckoutRepository()
        ..createResults.add(Ok(makeTicket()));
      await pumpCheckout(tester, repo: repo);
      await tapButton(tester, buttonLabeled('Pagar'));
      await guidelines(tester);
      handle.dispose();
    });

    testWidgets('revisión de carrito: las 4 guías', (tester) async {
      final handle = tester.ensureSemantics();
      final cart = FakeCheckoutCart(
        reviews: [
          const Ok(CartReview(checkoutAllowed: true, hasChanges: true)),
        ],
      );
      await pumpCheckout(tester, cart: cart);
      await tapButton(tester, buttonLabeled('Pagar'));
      await guidelines(tester);
      handle.dispose();
    });

    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'texto al ${(scale * 100).round()} % sin desbordar (reposo)',
        (tester) async {
          await pumpCheckout(tester, textScale: scale);
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(buttonLabeled('Pagar'));
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'texto al ${(scale * 100).round()} % sin desbordar (errores)',
        (tester) async {
          for (final failure in <AppFailure>[
            const NoConnection(),
            const RateLimited(retryAfter: 30),
            const Validation(),
            const Unauthorized(),
          ]) {
            final repo = FakeCheckoutRepository()
              ..createResults.add(Err(failure));
            await pumpCheckout(tester, repo: repo, textScale: scale);
            await tapButton(tester, buttonLabeled('Pagar'));
            expect(tester.takeException(), isNull, reason: '$failure');
            // Cada fallo deja su propia pantalla (se monta otra en cada vuelta).
            await tester.pumpWidget(const SizedBox());
          }
        },
      );
    }

    testWidgets('el estado se anuncia como región en vivo', (tester) async {
      final handle = tester.ensureSemantics();
      final repo = FakeCheckoutRepository()
        ..createResults.add(const Err(ServiceUnavailable()));
      await pumpCheckout(tester, repo: repo);
      await tapButton(tester, buttonLabeled('Pagar'));

      final live = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.liveRegion == true,
      );
      expect(live, findsWidgets);
      expect(
        tester.getSemantics(find.textContaining('No se pudo conectar')),
        isNotNull,
      );
      handle.dispose();
    });

    testWidgets('el progreso tiene etiqueta accesible', (tester) async {
      final handle = tester.ensureSemantics();
      final repo = FakeCheckoutRepository()
        ..createResults.add(Ok(makeTicket()))
        ..createGate = Completer<void>();
      await pumpCheckout(tester, repo: repo);
      await tester.tap(buttonLabeled('Pagar'));
      await settle(tester);
      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.semanticsLabel, 'Progreso del pago');
      handle.dispose();
    });

    testWidgets('con animaciones desactivadas no hay barra animada', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final repo = FakeCheckoutRepository()
        ..createResults.add(Ok(makeTicket()))
        ..createGate = Completer<void>();
      await pumpCheckout(tester, repo: repo);
      await tester.tap(buttonLabeled('Pagar'));
      await settle(tester);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.hourglass_empty), findsWidgets);
    });
  });
}
