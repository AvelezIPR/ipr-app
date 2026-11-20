import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ipr_mobile/core/config/remote_config_controller.dart';
import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/core/providers.dart';
import 'package:ipr_mobile/core/session/session_controller.dart';
import 'package:ipr_mobile/core/session/session_state.dart';
import 'package:ipr_mobile/features/checkout/checkout_providers.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/cart_review.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/checkout_attempt.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/checkout_line.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/checkout_status.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/checkout_ticket.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/pending_checkout.dart';
import 'package:ipr_mobile/features/checkout/domain/rules/checkout_failure.dart';
import 'package:ipr_mobile/features/checkout/domain/rules/checkout_flow.dart';
import 'package:ipr_mobile/features/checkout/domain/rules/poll_schedule.dart';

/// Estado del flujo de pago. Vive mientras la app: el resultado debe
/// sobrevivir al cambio entre `CheckoutScreen` y `CheckoutResultScreen`.
final checkoutControllerProvider =
    NotifierProvider<CheckoutController, CheckoutFlowState>(
      CheckoutController.new,
    );

/// Orquesta el pago (RF-052..058, ADR-008). Las transiciones las decide
/// `CheckoutMachine` (función pura); aquí solo están los efectos: red,
/// navegador seguro, disco y carrito.
///
/// Reglas que NO se negocian:
/// * La app envía solo `{id, quantity}`; la `Idempotency-Key` es un UUID v4
///   por intento y se reutiliza únicamente al reintentar ESE intento.
/// * La `checkoutUrl` solo se abre si pasa `CheckoutUrlPolicy` (intersección
///   flavor ∩ `/config` ∩ respuesta) y se abre de inmediato con
///   `SecureBrowser`. Vive solo en una variable local: no se guarda, no se
///   registra, no entra en el estado.
/// * El resultado sale únicamente de `GET /checkout/{ref}`; solo `paid`
///   vacía el carrito.
class CheckoutController extends Notifier<CheckoutFlowState> {
  /// Se incrementa al empezar o cancelar un tramo: las continuaciones de
  /// tramos anteriores se descartan.
  int _generation = 0;
  RequestCancellation? _cancellation;

  /// Líneas de la última petición del ticket (para decidir si reintentar el
  /// mismo intento sigue siendo equivalente).
  List<CheckoutLine>? _sentLines;

  @override
  CheckoutFlowState build() {
    ref
      ..listen(sessionControllerProvider, (previous, next) {
        // Cierre de sesión: se descarta todo, incluido el registro del
        // intento. Sesión vencida: se descarta el estado pero se conserva el
        // registro para reanudar la verificación tras iniciar sesión.
        if (next is SessionAnonymous) {
          unawaited(_hardReset(clearPending: true));
        } else if (next is SessionExpired) {
          unawaited(_hardReset(clearPending: false));
        }
      })
      ..onDispose(() {
        _generation++;
        _cancellation?.cancel();
      });
    return const CheckoutFlowState.idle();
  }

  // ── Entradas de la interfaz ─────────────────────────────────────────────

  /// Al abrir `CheckoutScreen`: descarta resultados y errores viejos (no los
  /// intentos en curso) y reanuda un intento pendiente si existe.
  void prepare() {
    if (!state.phase.isBusy &&
        !(state.phase == CheckoutPhase.failure && state.pendingVerification)) {
      _apply(const Reset());
    }
    unawaited(restorePending());
  }

  /// Al abrir `CheckoutResultScreen` (enlace de retorno incluido): si hay un
  /// intento esperando, consulta al servidor; si no hay estado pero sí un
  /// registro vigente (la app fue cerrada), lo reanuda. Sin ninguno de los
  /// dos NO hay nada que mostrar como pagado, diga lo que diga el enlace.
  Future<void> resumeFromReturn() async {
    if (state.phase == CheckoutPhase.awaitingResult) {
      await verifyNow();
    } else if (state.phase == CheckoutPhase.idle) {
      await restorePending();
    }
  }

  /// "Pagar": un toque = un intento nuevo con su propia clave.
  Future<void> pay() async {
    if (!CheckoutMachine.canStartPayment(state)) return;
    if (!_passesPreflight()) return;
    if (ref.read(checkoutCartProvider).lines.isEmpty) return;
    final gen = ++_generation;
    _apply(PayRequested(_newAttempt()));
    if (state.phase != CheckoutPhase.revalidating) return;
    await _revalidate(gen);
  }

  /// "Reintentar" desde un fallo o un resultado sin éxito. Nunca crea un
  /// segundo ticket si hay un intento sin verificar.
  Future<void> retry() async {
    if (CheckoutMachine.canResumeVerification(state)) {
      await continueVerifying();
      return;
    }
    if (CheckoutMachine.canRetrySameAttempt(state) &&
        sameCheckoutLines(
          _sentLines ?? const [],
          ref.read(checkoutCartProvider).lines,
        )) {
      if (!_passesPreflight()) return;
      final gen = ++_generation;
      _apply(const RetryRequested());
      if (state.phase == CheckoutPhase.requestingTicket) {
        await _requestTicket(gen);
      }
      return;
    }
    await pay();
  }

  /// "Continuar" tras revisar los cambios del carrito (RF-050).
  Future<void> acceptReview() async {
    if (!state.canContinueAfterReview || !_passesPreflight()) return;
    final gen = ++_generation;
    _apply(ReviewAccepted(_newAttempt()));
    if (state.phase == CheckoutPhase.requestingTicket) {
      await _requestTicket(gen);
    }
  }

  /// Regreso del navegador: enlace de retorno, primer plano o toque en
  /// "Ya pagué". Los parámetros del enlace no se leen: consulta al servidor.
  Future<void> verifyNow() async {
    if (state.phase != CheckoutPhase.awaitingResult) return;
    final gen = ++_generation;
    _apply(const ReturnDetected());
    await _verify(gen);
  }

  /// La app volvió a primer plano.
  void onAppResumed() {
    if (state.phase == CheckoutPhase.awaitingResult) unawaited(verifyNow());
  }

  /// "Continuar verificando" el mismo `checkoutRef` (sin otro ticket).
  Future<void> continueVerifying() async {
    if (!CheckoutMachine.canResumeVerification(state)) return;
    final gen = ++_generation;
    _apply(const ResumeVerification());
    await _verify(gen);
  }

  /// Reanuda en `verifying` si el sistema mató la app mientras se pagaba
  /// (registro sin PII vigente).
  Future<void> restorePending() async {
    if (state.phase != CheckoutPhase.idle) return;
    final pending = await ref.read(pendingCheckoutStoreProvider).load();
    if (pending == null || !ref.mounted) return;
    if (state.phase != CheckoutPhase.idle) return;
    if (ref.read(sessionControllerProvider) is! SessionAuthenticated) return;
    final gen = ++_generation;
    _apply(Restored(pending.checkoutRef));
    await _verify(gen);
  }

  /// Sale del resultado (acciones de `CheckoutResultScreen`). No interrumpe
  /// un intento en curso.
  void reset() {
    if (state.phase.isBusy) return;
    _generation++;
    _apply(const Reset());
  }

  // ── Efectos ─────────────────────────────────────────────────────────────

  CheckoutAttempt _newAttempt() {
    final uuid = ref.read(checkoutUuidProvider);
    return CheckoutAttempt(
      id: uuid(),
      idempotencyKey: uuid(),
      createdAt: ref.read(checkoutNowProvider)(),
    );
  }

  /// Sesión iniciada y checkout encendido; si no, falla cerrado.
  bool _passesPreflight() {
    final CheckoutFailureKind? blocked;
    if (ref.read(sessionControllerProvider) is! SessionAuthenticated) {
      blocked = CheckoutFailureKind.unauthorized;
    } else if (!ref.read(remoteConfigProvider).config.checkoutEnabled) {
      blocked = CheckoutFailureKind.disabled;
    } else {
      blocked = null;
    }
    if (blocked == null) return true;
    _apply(PayBlocked(blocked));
    return false;
  }

  Future<void> _revalidate(int gen) async {
    final result = await ref.read(checkoutCartProvider).revalidate();
    if (!_alive(gen)) return;
    switch (result) {
      case Ok<CartReview>(:final value):
        _apply(ReviewCompleted(value));
      case Err<CartReview>(:final failure):
        _apply(
          ReviewFailed(
            CheckoutFailureKind.from(failure),
            retryAfterSeconds: failure.retryAfterSeconds,
          ),
        );
    }
    if (state.phase == CheckoutPhase.requestingTicket) {
      await _requestTicket(gen);
    }
  }

  Future<void> _requestTicket(int gen) async {
    final attempt = state.attempt;
    final lines = ref.read(checkoutCartProvider).lines;
    if (attempt == null || lines.isEmpty) {
      _apply(const RequestFailed(CheckoutFailureKind.unknown));
      return;
    }
    _sentLines = List.unmodifiable(lines);
    final cancellation = _cancellation = RequestCancellation();
    final result = await ref
        .read(checkoutRepositoryProvider)
        .createCheckout(
          lines: lines,
          idempotencyKey: attempt.idempotencyKey,
          cancellation: cancellation,
        );
    if (!_alive(gen)) return;
    switch (result) {
      case Err<CheckoutTicket>(:final failure):
        _apply(
          RequestFailed(
            CheckoutFailureKind.from(failure),
            retryAfterSeconds: failure.retryAfterSeconds,
          ),
        );
        switch (state.phase) {
          case CheckoutPhase.ticketExpired:
            // Único reintento automático (RNF-026): mismo intento, misma
            // clave; el BFF reemite un ticket para el mismo `checkoutRef`.
            _apply(const RetryTicket());
            await _requestTicket(gen);
          case CheckoutPhase.revalidating:
            // 400/409: el carrito cambió; se vuelve a revalidar.
            await _revalidate(gen);
          case _:
            break;
        }
      case Ok<CheckoutTicket>(:final value):
        await _openCheckout(gen, value);
    }
  }

  Future<void> _openCheckout(int gen, CheckoutTicket ticket) async {
    final config = ref.read(remoteConfigProvider).config;
    // Intersección de tres listas: la del flavor (dentro de la política), la
    // de `/config` y la de la respuesta. Un servidor no puede ampliarla.
    final remoteHosts = {
      for (final host in config.checkoutAllowedHosts) host.toLowerCase(),
    }.intersection(ticket.allowedHosts);
    final allowed =
        config.checkoutEnabled &&
        ref
            .read(checkoutUrlPolicyProvider)
            .isAllowed(ticket.checkoutUrl, remoteHosts: remoteHosts);
    _apply(
      TicketReceived(checkoutRef: ticket.checkoutRef, urlAllowed: allowed),
    );
    final attempt = state.attempt;
    if (state.phase != CheckoutPhase.openingBrowser || attempt == null) return;

    // Se abre INMEDIATAMENTE; el registro sin PII se guarda en paralelo para
    // sobrevivir a un cierre forzado mientras el usuario paga.
    final store = ref.read(pendingCheckoutStoreProvider);
    final saved = _safe(
      store.save(
        PendingCheckout(
          checkoutRef: ticket.checkoutRef,
          attemptId: attempt.id,
          startedAt: ref.read(checkoutNowProvider)(),
        ),
      ),
    );
    var opened = false;
    try {
      opened = await ref.read(secureBrowserProvider).open(ticket.checkoutUrl);
    } on Object {
      opened = false;
    }
    await saved;
    if (!_alive(gen)) return;
    if (opened) {
      _apply(const BrowserOpened());
    } else {
      _apply(const BrowserFailed());
      await _safe(store.clear());
    }
  }

  /// Consulta y sondea `GET /checkout/{ref}` (2, 4, 8, 16 s y luego cada
  /// 15 s hasta 120 s).
  Future<void> _verify(int gen) async {
    final checkoutRef = state.checkoutRef;
    if (checkoutRef == null) return;
    final now = ref.read(checkoutNowProvider);
    final sleep = ref.read(checkoutSleepProvider);
    final started = now();
    var polls = 0;
    var lastFailed = false;
    while (_alive(gen) && state.phase == CheckoutPhase.verifying) {
      final cancellation = _cancellation = RequestCancellation();
      final result = await ref
          .read(checkoutRepositoryProvider)
          .status(checkoutRef, cancellation: cancellation);
      if (!_alive(gen)) return;
      polls++;
      switch (result) {
        case Ok<CheckoutStatus>(:final value):
          lastFailed = false;
          if (value.checkoutRef != checkoutRef) {
            // Respuesta de otro intento: no es la verdad de este.
            _apply(const StatusFailed(CheckoutFailureKind.contract));
            return;
          }
          _apply(StatusReceived(value));
          if (state.phase != CheckoutPhase.verifying) {
            await _finish();
            return;
          }
        case Err<CheckoutStatus>(:final failure):
          final kind = CheckoutFailureKind.from(failure);
          if (kind.stopsPolling) {
            _apply(StatusFailed(kind));
            return;
          }
          lastFailed = true;
      }
      final delay = PollSchedule.nextDelay(
        polls: polls,
        elapsed: now().difference(started),
      );
      if (delay == null) {
        _apply(PollTimedOut(lastPollFailed: lastFailed));
        await _finish();
        return;
      }
      await sleep(delay);
    }
  }

  /// Efectos de un resultado final: SOLO `paid` vacía el carrito.
  Future<void> _finish() async {
    final store = ref.read(pendingCheckoutStoreProvider);
    switch (state.phase) {
      case CheckoutPhase.paid:
        try {
          await ref.read(checkoutCartProvider).clear();
        } on Object {
          // El pedido sigue pagado; el registro se conserva para volver a
          // intentar vaciar el carrito al reanudar.
          return;
        }
        await _safe(store.clear());
      case CheckoutPhase.pending ||
          CheckoutPhase.failed ||
          CheckoutPhase.cancelled ||
          CheckoutPhase.noOrder:
        await _safe(store.clear());
      case _:
        break;
    }
  }

  Future<void> _hardReset({required bool clearPending}) async {
    _generation++;
    _cancellation?.cancel();
    _apply(const Reset());
    if (clearPending) {
      await _safe(ref.read(pendingCheckoutStoreProvider).clear());
    }
  }

  // ── Utilidades ──────────────────────────────────────────────────────────

  bool _alive(int gen) => ref.mounted && gen == _generation;

  void _apply(CheckoutEvent event) {
    if (!ref.mounted) return;
    final next = CheckoutMachine.transition(state, event);
    if (next != state) state = next;
  }

  /// Un fallo del disco nunca debe frenar el pago ni la verificación.
  Future<void> _safe(Future<void> future) async {
    try {
      await future;
    } on Object {
      // Sin efecto: el registro sin PII es solo una ayuda de reanudación.
    }
  }
}
