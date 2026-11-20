import 'package:ipr_mobile/features/checkout/domain/entities/payment_state.dart';
import 'package:ipr_mobile/features/checkout/domain/rules/checkout_failure.dart';
import 'package:ipr_mobile/features/checkout/domain/rules/checkout_flow.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';

/// Mensaje legible de un fallo del pago (RF-058). Nunca texto del servidor,
/// códigos, HTML ni nombres internos (AC-058-5, AC-058-6).
String checkoutFailureText(AppLocalizations l10n, CheckoutFailureKind kind) =>
    switch (kind) {
      CheckoutFailureKind.noConnection => l10n.checkoutFailureNoConnection,
      CheckoutFailureKind.timeout => l10n.checkoutFailureTimeout,
      CheckoutFailureKind.storeUnavailable =>
        l10n.checkoutFailureStoreUnavailable,
      CheckoutFailureKind.rateLimited => l10n.checkoutFailureRateLimited,
      CheckoutFailureKind.cartInvalid => l10n.checkoutFailureCartInvalid,
      CheckoutFailureKind.ticketInvalid => l10n.checkoutFailureTicketInvalid,
      CheckoutFailureKind.unauthorized => l10n.checkoutFailureUnauthorized,
      CheckoutFailureKind.forbidden => l10n.checkoutFailureForbidden,
      CheckoutFailureKind.contract => l10n.checkoutFailureContract,
      CheckoutFailureKind.urlNotAllowed => l10n.checkoutFailureUrlNotAllowed,
      CheckoutFailureKind.browserUnavailable =>
        l10n.checkoutFailureBrowserUnavailable,
      CheckoutFailureKind.disabled => l10n.checkoutFailureDisabled,
      CheckoutFailureKind.statusUnavailable =>
        l10n.checkoutFailureStatusUnavailable,
      CheckoutFailureKind.unknown => l10n.checkoutFailureUnknown,
    };

/// Texto de estado de un paso en curso (región en vivo).
String checkoutPhaseText(AppLocalizations l10n, CheckoutPhase phase) =>
    switch (phase) {
      CheckoutPhase.revalidating => l10n.checkoutPhaseRevalidating,
      CheckoutPhase.requestingTicket => l10n.checkoutPhaseRequestingTicket,
      CheckoutPhase.ticketExpired => l10n.checkoutPhaseTicketExpired,
      CheckoutPhase.openingBrowser => l10n.checkoutPhaseOpeningBrowser,
      CheckoutPhase.awaitingResult => l10n.checkoutPhaseAwaitingResult,
      CheckoutPhase.verifying => l10n.checkoutPhaseVerifying,
      CheckoutPhase.idle ||
      CheckoutPhase.needsReview ||
      CheckoutPhase.paid ||
      CheckoutPhase.pending ||
      CheckoutPhase.failed ||
      CheckoutPhase.cancelled ||
      CheckoutPhase.noOrder ||
      CheckoutPhase.failure => l10n.checkoutPhaseIdle,
    };

/// Título y cuerpo de un resultado verificado. El estado de pago del servidor
/// (`paymentState`) afina el texto de `pending` y `failed`.
({String title, String body}) checkoutOutcomeText(
  AppLocalizations l10n,
  CheckoutPhase phase,
  PaymentState? paymentState,
) => switch (phase) {
  CheckoutPhase.paid => (
    title: l10n.checkoutResultPaidTitle,
    body: l10n.checkoutResultPaidBody,
  ),
  CheckoutPhase.pending when paymentState == PaymentState.unknown => (
    title: l10n.checkoutResultUnknownTitle,
    body: l10n.checkoutResultUnknownBody,
  ),
  CheckoutPhase.pending => (
    title: l10n.checkoutResultPendingTitle,
    body: l10n.checkoutResultPendingBody,
  ),
  CheckoutPhase.failed when paymentState == PaymentState.refunded => (
    title: l10n.checkoutResultRefundedTitle,
    body: l10n.checkoutResultRefundedBody,
  ),
  CheckoutPhase.failed => (
    title: l10n.checkoutResultFailedTitle,
    body: l10n.checkoutResultFailedBody,
  ),
  CheckoutPhase.cancelled => (
    title: l10n.checkoutResultCancelledTitle,
    body: l10n.checkoutResultCancelledBody,
  ),
  CheckoutPhase.noOrder => (
    title: l10n.checkoutResultNoOrderTitle,
    body: l10n.checkoutResultNoOrderBody,
  ),
  _ => (title: l10n.checkoutResultNoneTitle, body: l10n.checkoutResultNoneBody),
};
