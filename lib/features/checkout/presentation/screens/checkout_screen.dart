import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ipr_mobile/core/config/remote_config_controller.dart';
import 'package:ipr_mobile/features/checkout/checkout_providers.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/checkout_line.dart';
import 'package:ipr_mobile/features/checkout/domain/rules/checkout_failure.dart';
import 'package:ipr_mobile/features/checkout/domain/rules/checkout_flow.dart';
import 'package:ipr_mobile/features/checkout/presentation/controllers/checkout_controller.dart';
import 'package:ipr_mobile/features/checkout/presentation/widgets/checkout_texts.dart';
import 'package:ipr_mobile/features/checkout/presentation/widgets/checkout_widgets.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:ipr_mobile/shared/navigation/routes.dart';
import 'package:material_ui/material_ui.dart';

/// Orquestador del pago `/checkout` (RF-052..058; requiere sesión).
///
/// * Resumen de líneas de solo lectura; el precio final lo confirma la tienda.
/// * El pago se completa en el navegador seguro del sistema (jamás un
///   WebView); aquí no se capturan datos de tarjeta (RF-053).
/// * "Pagar" se deshabilita al tocarlo (una solicitud por intento) y, mientras
///   haya un intento esperando o verificándose, no crea otro ticket: ofrece
///   "Continuar verificando".
/// * Al haber un resultado verificado navega a `CheckoutResultScreen`.
class CheckoutScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Fuera de la construcción: `prepare` modifica el estado del controlador.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(checkoutControllerProvider.notifier).prepare();
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
    final lines = ref.watch(checkoutLinesProvider);
    final enabled = ref.watch(
      remoteConfigProvider.select((s) => s.config.checkoutEnabled),
    );
    final controller = ref.read(checkoutControllerProvider.notifier);

    ref.listen(checkoutControllerProvider, (previous, next) {
      if (next.phase.isOutcome && previous?.phase != next.phase) {
        context.pushReplacement(Routes.checkoutResult);
      }
    });

    final children = <Widget>[
      if (lines.isEmpty && !state.phase.isBusy)
        _EmptyCart(onCatalog: () => context.go(Routes.catalog))
      else ...[
        CheckoutSummary(lines: lines),
        const SizedBox(height: IprSpace.s4),
        CheckoutNotice(
          icon: Icons.info_outline,
          text: l10n.checkoutPriceNotice,
        ),
        CheckoutNotice(
          icon: Icons.lock_outline,
          text: l10n.checkoutSecureNotice,
        ),
        CheckoutNotice(icon: Icons.wifi, text: l10n.checkoutNeedsConnection),
        if (state.priorPending)
          CheckoutNotice(
            icon: Icons.hourglass_empty,
            text: l10n.checkoutPriorPendingNotice,
          ),
        const SizedBox(height: IprSpace.s3),
        ..._status(
          context,
          state: state,
          lines: lines,
          enabled: enabled,
          controller: controller,
        ),
      ],
    ];
    return CheckoutScaffold(title: l10n.checkoutTitle, children: children);
  }

  List<Widget> _status(
    BuildContext context, {
    required CheckoutFlowState state,
    required List<CheckoutLine> lines,
    required bool enabled,
    required CheckoutController controller,
  }) {
    final l10n = AppLocalizations.of(context);
    switch (state.phase) {
      case CheckoutPhase.idle:
        return [
          if (!enabled)
            CheckoutStatusPanel(
              message: l10n.checkoutFailureDisabled,
              isError: true,
            ),
          CheckoutButton(
            label: l10n.checkoutPayButton,
            onPressed: enabled ? controller.pay : null,
          ),
        ];
      case CheckoutPhase.revalidating ||
          CheckoutPhase.requestingTicket ||
          CheckoutPhase.ticketExpired ||
          CheckoutPhase.openingBrowser:
        return [
          CheckoutStatusPanel(
            message: checkoutPhaseText(l10n, state.phase),
            busy: true,
          ),
          CheckoutButton(label: l10n.checkoutPayBusy, onPressed: null),
        ];
      case CheckoutPhase.awaitingResult:
        return [
          CheckoutStatusPanel(message: checkoutPhaseText(l10n, state.phase)),
          CheckoutButton(
            label: l10n.checkoutContinueVerifying,
            onPressed: controller.verifyNow,
          ),
        ];
      case CheckoutPhase.verifying:
        return [
          CheckoutStatusPanel(
            message: checkoutPhaseText(l10n, state.phase),
            busy: true,
          ),
          CheckoutButton(label: l10n.checkoutVerifyingButton, onPressed: null),
        ];
      case CheckoutPhase.needsReview:
        return _review(context, state, controller);
      case CheckoutPhase.failure:
        return _failure(context, state, controller);
      case CheckoutPhase.paid ||
          CheckoutPhase.pending ||
          CheckoutPhase.failed ||
          CheckoutPhase.cancelled ||
          CheckoutPhase.noOrder:
        // Un instante antes de pasar a la pantalla de resultado.
        return [
          CheckoutStatusPanel(
            message: checkoutPhaseText(l10n, CheckoutPhase.verifying),
            busy: true,
          ),
        ];
    }
  }

  List<Widget> _review(
    BuildContext context,
    CheckoutFlowState state,
    CheckoutController controller,
  ) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final review = state.review;
    return [
      Semantics(
        liveRegion: true,
        container: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.checkoutReviewTitle,
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: IprSpace.s2),
            if (review?.hasChanges ?? false)
              CheckoutNotice(
                icon: Icons.sync_alt,
                text: l10n.checkoutReviewChanges,
              ),
            if (review?.hasUnavailable ?? false)
              CheckoutNotice(
                icon: Icons.remove_shopping_cart_outlined,
                text: l10n.checkoutReviewUnavailable,
              ),
            if (!(review?.checkoutAllowed ?? false))
              CheckoutNotice(
                icon: Icons.block,
                text: l10n.checkoutReviewBlocked,
              ),
          ],
        ),
      ),
      if (state.canContinueAfterReview)
        CheckoutButton(
          label: l10n.checkoutReviewContinue,
          onPressed: controller.acceptReview,
        ),
      CheckoutButton(
        label: l10n.checkoutReviewEdit,
        primary: !state.canContinueAfterReview,
        onPressed: () => context.go(Routes.cart),
      ),
    ];
  }

  List<Widget> _failure(
    BuildContext context,
    CheckoutFlowState state,
    CheckoutController controller,
  ) {
    final l10n = AppLocalizations.of(context);
    final kind = state.failureKind ?? CheckoutFailureKind.unknown;
    final retryLabel = state.pendingVerification
        ? l10n.checkoutVerifyAgain
        : l10n.actionRetry;
    return [
      CheckoutStatusPanel(
        message: checkoutFailureText(l10n, kind),
        isError: true,
      ),
      switch (kind) {
        CheckoutFailureKind.unauthorized => CheckoutButton(
          label: l10n.checkoutSignIn,
          onPressed: () => context.go(
            Uri(
              path: Routes.login,
              queryParameters: {'from': Routes.checkout},
            ).toString(),
          ),
        ),
        CheckoutFailureKind.disabled ||
        CheckoutFailureKind.forbidden => const SizedBox.shrink(),
        _ => CheckoutRetryButton(
          // Nueva clave de widget por fallo: reinicia la cuenta regresiva.
          key: ValueKey('${kind.name}-${state.retryAfterSeconds}'),
          label: retryLabel,
          waitSeconds: state.retryAfterSeconds,
          onPressed: controller.retry,
        ),
      },
      CheckoutButton(
        // Ante un 400/409 el carrito pudo cambiar: se invita a revisarlo.
        label: kind == CheckoutFailureKind.cartInvalid
            ? l10n.checkoutReviewEdit
            : l10n.checkoutBackToCart,
        primary: false,
        onPressed: () => context.go(Routes.cart),
      ),
    ];
  }
}

class _EmptyCart extends StatelessWidget {
  const new({required this.onCatalog});

  final VoidCallback onCatalog;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: IprSpace.s5),
        ExcludeSemantics(
          child: Icon(
            Icons.shopping_cart_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: IprSpace.s3),
        Semantics(
          header: true,
          child: Text(
            l10n.checkoutEmptyTitle,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: IprSpace.s2),
        Text(
          l10n.checkoutEmptyBody,
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        CheckoutButton(label: l10n.checkoutEmptyAction, onPressed: onCatalog),
      ],
    );
  }
}
