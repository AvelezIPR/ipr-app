import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/payment_state.dart';
import 'package:ipr_mobile/features/checkout/domain/rules/checkout_failure.dart';
import 'package:ipr_mobile/features/checkout/domain/rules/checkout_flow.dart';
import 'package:ipr_mobile/features/checkout/presentation/controllers/checkout_controller.dart';
import 'package:ipr_mobile/features/checkout/presentation/widgets/checkout_texts.dart';
import 'package:ipr_mobile/features/checkout/presentation/widgets/checkout_widgets.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:ipr_mobile/shared/navigation/routes.dart';
import 'package:material_ui/material_ui.dart';

/// Resultado verificado del pago `/checkout/result` (RF-055, RF-056, RF-057).
///
/// Destino del enlace de retorno `/app/pedido`. [order] y [status] son **solo
/// pistas** del enlace: no se muestran ni deciden nada. Lo que se ve sale
/// únicamente de `GET /checkout/{checkoutRef}` (SC-025): un enlace sin pago en
/// curso, o con un `status=paid` falsificado, jamás muestra "pago exitoso".
class CheckoutResultScreen extends ConsumerStatefulWidget {
  const new({super.key, this.order, this.status});

  /// Pista: número de pedido del enlace (no confiable).
  final String? order;

  /// Pista: estado del enlace (no confiable).
  final String? status;

  @override
  ConsumerState<CheckoutResultScreen> createState() =>
      _CheckoutResultScreenState();
}

class _CheckoutResultScreenState extends ConsumerState<CheckoutResultScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(
          ref.read(checkoutControllerProvider.notifier).resumeFromReturn(),
        );
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(checkoutControllerProvider.notifier).onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(checkoutControllerProvider);
    final controller = ref.read(checkoutControllerProvider.notifier);

    void leave(String location) {
      controller.reset();
      context.go(location);
    }

    final children = switch (state.phase) {
      CheckoutPhase.paid ||
      CheckoutPhase.pending ||
      CheckoutPhase.failed ||
      CheckoutPhase.cancelled ||
      CheckoutPhase.noOrder => _outcome(context, state, controller, leave),
      CheckoutPhase.awaitingResult ||
      CheckoutPhase.verifying ||
      CheckoutPhase.revalidating ||
      CheckoutPhase.requestingTicket ||
      CheckoutPhase.ticketExpired ||
      CheckoutPhase.openingBrowser => [
        CheckoutStatusPanel(
          message: checkoutPhaseText(l10n, CheckoutPhase.verifying),
          busy: true,
        ),
        if (state.phase == CheckoutPhase.awaitingResult)
          CheckoutButton(
            label: l10n.checkoutContinueVerifying,
            onPressed: controller.verifyNow,
          ),
      ],
      CheckoutPhase.failure => _failure(context, state, controller, leave),
      CheckoutPhase.idle || CheckoutPhase.needsReview => _none(context, leave),
    };
    return CheckoutScaffold(
      title: l10n.checkoutResultTitle,
      children: children,
    );
  }

  List<Widget> _outcome(
    BuildContext context,
    CheckoutFlowState state,
    CheckoutController controller,
    void Function(String location) leave,
  ) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final order = state.order;
    final text = checkoutOutcomeText(l10n, state.phase, order?.paymentState);
    final (icon, color) = switch (state.phase) {
      CheckoutPhase.paid => (
        Icons.check_circle_outline,
        theme.colorScheme.onSurface,
      ),
      CheckoutPhase.pending => (
        Icons.hourglass_top,
        theme.colorScheme.onSurface,
      ),
      CheckoutPhase.noOrder => (Icons.search_off, theme.colorScheme.onSurface),
      _ => (Icons.error_outline, theme.colorScheme.error),
    };
    final retryable =
        state.phase == CheckoutPhase.failed ||
        state.phase == CheckoutPhase.cancelled ||
        state.phase == CheckoutPhase.noOrder;
    return [
      Semantics(
        liveRegion: true,
        container: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: IprSpace.s4),
            ExcludeSemantics(child: Icon(icon, size: 56, color: color)),
            const SizedBox(height: IprSpace.s3),
            Semantics(
              header: true,
              child: Text(
                text.title,
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: IprSpace.s2),
            Text(
              text.body,
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            if (order != null) ...[
              const SizedBox(height: IprSpace.s4),
              Text(
                l10n.checkoutResultOrderNumber(order.number),
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              if (order.statusLabel.isNotEmpty &&
                  order.paymentState != PaymentState.paid)
                Padding(
                  padding: const EdgeInsets.only(top: IprSpace.s1),
                  child: Text(
                    l10n.checkoutResultOrderStatus(order.statusLabel),
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ],
        ),
      ),
      const SizedBox(height: IprSpace.s3),
      if (state.phase == CheckoutPhase.noOrder)
        CheckoutButton(
          label: l10n.checkoutVerifyAgain,
          onPressed: controller.continueVerifying,
        ),
      if (retryable) ...[
        CheckoutButton(
          label: l10n.checkoutRetryPayment,
          primary: state.phase != CheckoutPhase.noOrder,
          onPressed: () {
            controller.reset();
            context.pushReplacement(Routes.checkout);
          },
        ),
        CheckoutButton(
          label: l10n.checkoutBackToCart,
          primary: false,
          onPressed: () => leave(Routes.cart),
        ),
      ] else ...[
        CheckoutButton(
          label: l10n.checkoutViewOrders,
          onPressed: () => leave(Routes.orders),
        ),
        CheckoutButton(
          label: l10n.checkoutBackToHome,
          primary: false,
          onPressed: () => leave(Routes.home),
        ),
      ],
    ];
  }

  List<Widget> _failure(
    BuildContext context,
    CheckoutFlowState state,
    CheckoutController controller,
    void Function(String location) leave,
  ) {
    final l10n = AppLocalizations.of(context);
    final kind = state.failureKind ?? CheckoutFailureKind.unknown;
    return [
      CheckoutStatusPanel(
        message: checkoutFailureText(l10n, kind),
        isError: true,
      ),
      if (state.pendingVerification && kind != CheckoutFailureKind.unauthorized)
        CheckoutRetryButton(
          key: ValueKey('verify-${kind.name}'),
          label: l10n.checkoutVerifyAgain,
          onPressed: controller.continueVerifying,
        ),
      CheckoutButton(
        label: l10n.checkoutViewOrders,
        primary: false,
        onPressed: () => leave(Routes.orders),
      ),
      CheckoutButton(
        label: l10n.checkoutBackToCart,
        primary: false,
        onPressed: () => leave(Routes.cart),
      ),
    ];
  }

  List<Widget> _none(
    BuildContext context,
    void Function(String location) leave,
  ) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return [
      const SizedBox(height: IprSpace.s4),
      ExcludeSemantics(
        child: Icon(
          Icons.search_off,
          size: 56,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: IprSpace.s3),
      Semantics(
        liveRegion: true,
        container: true,
        header: true,
        child: Text(
          l10n.checkoutResultNoneTitle,
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
      ),
      const SizedBox(height: IprSpace.s2),
      Text(
        l10n.checkoutResultNoneBody,
        style: theme.textTheme.bodyLarge,
        textAlign: TextAlign.center,
      ),
      CheckoutButton(
        label: l10n.checkoutViewOrders,
        onPressed: () => leave(Routes.orders),
      ),
      CheckoutButton(
        label: l10n.checkoutBackToHome,
        primary: false,
        onPressed: () => leave(Routes.home),
      ),
    ];
  }
}
