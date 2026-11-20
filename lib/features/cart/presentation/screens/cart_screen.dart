import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/features/cart/domain/entities/cart_overview.dart';
import 'package:ipr_mobile/features/cart/presentation/controllers/cart_controller.dart';
import 'package:ipr_mobile/features/cart/presentation/widgets/cart_banners.dart';
import 'package:ipr_mobile/features/cart/presentation/widgets/cart_line_tile.dart';
import 'package:ipr_mobile/features/cart/presentation/widgets/cart_summary_panel.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:ipr_mobile/shared/navigation/routes.dart';
import 'package:ipr_mobile/shared/widgets/state_widgets.dart';
import 'package:material_ui/material_ui.dart';

/// Pestaña Carrito (`/cart`, RF-049..051). Sin barra superior propia: la
/// barra inferior la da el shell.
///
/// * Un invitado ve y arma el carrito; la sesión se pide al pagar (la ruta
///   `/checkout` está protegida por el router).
/// * Al abrir la pestaña (y antes de pagar) se revalida con el servidor; un
///   fallo conserva el carrito y lo dice.
/// * Funciona sin conexión: se ve y se edita; el pago exige conexión.
class CartScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  bool _wasActive = false;
  bool _paying = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Las pestañas viven en una pila indexada: la pantalla no se reconstruye
    // al volver a ella. Una pestaña inactiva tiene los `Ticker` apagados, así
    // que activarse es el momento de "abrir el carrito" (AC-050-1).
    final active = TickerMode.valuesOf(context).enabled;
    if (active && !_wasActive) {
      unawaited(ref.read(cartProvider.notifier).revalidate());
    }
    _wasActive = active;
  }

  Future<void> _pay() async {
    if (_paying) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final notifier = ref.read(cartProvider.notifier);
    setState(() => _paying = true);
    final attempt = await notifier.attemptCheckout();
    if (!mounted) return;
    setState(() => _paying = false);
    switch (attempt) {
      case CartCheckoutAttempt.proceed:
        unawaited(context.push(Routes.checkout));
      case CartCheckoutAttempt.blocked:
        _snack(messenger, l10n.cartPayBlockedSnack);
      case CartCheckoutAttempt.verificationFailed:
        final failure = ref.read(cartProvider).validationFailure;
        _snack(
          messenger,
          failure is NoConnection
              ? l10n.cartPayNeedsConnection
              : l10n.cartPayVerifyFailed,
        );
    }
  }

  void _snack(ScaffoldMessengerState? messenger, String text) => messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  void _remove(CartLineView view, int index) {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final notifier = ref.read(cartProvider.notifier);
    final name = view.name ?? l10n.cartLineUnnamed(view.productId);
    final line = view.line;
    unawaited(notifier.remove(view.productId));
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.cartLineRemoved(name)),
          action: SnackBarAction(
            label: l10n.cartUndo,
            onPressed: () => unawaited(notifier.restoreLine(line, index)),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(cartProvider);
    final theme = Theme.of(context);

    final Widget body;
    if (!state.loaded) {
      body = const LoadingState();
    } else if (state.isEmpty) {
      body = EmptyState(
        title: l10n.cartEmptyTitle,
        body: l10n.cartEmptyBody,
        action: FilledButton(
          onPressed: () => context.go(Routes.catalog),
          child: Text(l10n.cartEmptyAction),
        ),
      );
    } else {
      body = _CartContent(
        paying: _paying,
        onPay: () => unawaited(_pay()),
        onRemove: _remove,
      );
    }

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              IprSpace.s4,
              IprSpace.s4,
              IprSpace.s4,
              IprSpace.s2,
            ),
            child: Semantics(
              header: true,
              child: Text(
                l10n.cartTitle,
                style: theme.textTheme.headlineMedium,
              ),
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _CartContent extends ConsumerWidget {
  const new({
    required this.paying,
    required this.onPay,
    required this.onRemove,
  });

  final bool paying;
  final VoidCallback onPay;
  final void Function(CartLineView view, int index) onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(cartProvider);
    final overview = ref.watch(cartOverviewProvider);
    final readiness = ref.watch(cartReadinessProvider);
    final notifier = ref.read(cartProvider.notifier);
    final failure = state.validationFailure;

    final blocking = overview.blockingLines.length;
    final changes = overview.pendingAcknowledgements.length;

    final notices = <Widget>[
      if (failure != null) ...[
        const StaleBanner(),
        const SizedBox(height: IprSpace.s2),
        CartNotice(
          icon: Icons.cloud_off_outlined,
          title: cartVerifyFailureText(l10n, failure),
          isError: true,
          actions: [
            if (failure.retryable)
              OutlinedButton(
                onPressed: () => unawaited(notifier.revalidate()),
                child: Text(l10n.actionRetry),
              ),
          ],
        ),
        const SizedBox(height: IprSpace.s2),
      ],
      if (blocking > 0) ...[
        CartNotice(
          icon: Icons.error_outline,
          title: l10n.cartBlockedBannerTitle(blocking),
          body: l10n.cartBlockedBannerBody,
          isError: true,
          actions: [
            FilledButton(
              onPressed: () => unawaited(notifier.removeUnavailable()),
              child: Text(l10n.cartBlockedBannerAction),
            ),
          ],
        ),
        const SizedBox(height: IprSpace.s2),
      ],
      if (changes > 0) ...[
        CartNotice(
          icon: Icons.sell_outlined,
          title: l10n.cartChangedBannerTitle(changes),
          body: l10n.cartChangedBannerBody,
          actions: [
            FilledButton(
              onPressed: notifier.acceptChanges,
              child: Text(l10n.cartChangedBannerAction),
            ),
          ],
        ),
        const SizedBox(height: IprSpace.s2),
      ],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.revalidating)
          Semantics(
            liveRegion: true,
            label: l10n.cartVerifying,
            child: const LinearProgressIndicator(),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: IprSpace.s4),
            children: [
              ...notices,
              for (final (index, view) in overview.lines.indexed)
                CartLineTile(
                  key: ValueKey(view.productId),
                  view: view,
                  onQuantityChanged: (q) =>
                      unawaited(notifier.setQuantity(view.productId, q)),
                  onRemove: () => onRemove(view, index),
                ),
              const SizedBox(height: IprSpace.s3),
            ],
          ),
        ),
        CartSummaryPanel(
          subtotal: overview.subtotal,
          readiness: readiness,
          busy: paying || state.revalidating,
          onPay: onPay,
        ),
      ],
    );
  }
}
