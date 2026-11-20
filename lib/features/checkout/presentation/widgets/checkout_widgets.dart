import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ipr_mobile/core/providers.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/checkout_line.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:ipr_mobile/shared/navigation/routes.dart';
import 'package:ipr_mobile/shared/widgets/sensitive_screen.dart';
import 'package:material_ui/material_ui.dart';

/// Estructura común de las pantallas del pago: barra superior, captura
/// bloqueada (`SensitiveScreen`, SC-035), contenido desplazable (el texto al
/// 200 % no se corta) y ancho acotado.
class CheckoutScaffold extends ConsumerWidget {
  const new({required this.title, required this.children, super.key});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        // Si la pantalla se abrió sin historial (enlace de retorno en frío),
        // el botón lleva a Inicio (AC-055-7).
        leading: context.canPop()
            ? null
            : IconButton(
                tooltip: l10n.checkoutBack,
                icon: const Icon(Icons.arrow_back),
                constraints: const BoxConstraints(
                  minWidth: IprSpace.minTapTarget,
                  minHeight: IprSpace.minTapTarget,
                ),
                onPressed: () => context.go(Routes.home),
              ),
      ),
      body: SensitiveScreen(
        protection: ref.watch(screenProtectionProvider),
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(IprSpace.s4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Resumen de líneas, solo lectura. Muestra nombre y cantidad; nunca precios
/// (el servidor decide el monto, SC-020).
class CheckoutSummary extends StatelessWidget {
  const new({required this.lines, super.key});

  final List<CheckoutLine> lines;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.checkoutSummaryTitle,
            style: theme.textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: IprSpace.s2),
        for (final line in lines)
          _SummaryRow(
            name: line.name ?? l10n.checkoutLineUnnamed(line.productId),
            quantity: line.quantity,
          ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const new({required this.name, required this.quantity});

  final String name;
  final int quantity;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: l10n.checkoutLineSemantics(name, quantity),
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: IprSpace.s2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(name, style: theme.textTheme.bodyLarge)),
              const SizedBox(width: IprSpace.s3),
              Text(
                l10n.checkoutLineQuantity(quantity),
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Aviso con ícono y texto (nunca solo color, RNF-076).
class CheckoutNotice extends StatelessWidget {
  const new({required this.icon, required this.text, super.key});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: IprSpace.s1),
      child: Semantics(
        container: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Icon(
                icon,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: IprSpace.s2),
            Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
          ],
        ),
      ),
    );
  }
}

/// Estado actual con texto y progreso accesibles; se anuncia al cambiar.
class CheckoutStatusPanel extends StatelessWidget {
  const new({
    required this.message,
    this.busy = false,
    this.isError = false,
    super.key,
  });

  final String message;

  /// Muestra un indicador de progreso (con texto: nunca solo animación).
  final bool busy;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final reduce = MediaQuery.of(context).disableAnimations;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: IprSpace.s2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isError) ...[
                  ExcludeSemantics(
                    child: Icon(
                      Icons.error_outline,
                      color: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(width: IprSpace.s2),
                ],
                Expanded(
                  child: Text(message, style: theme.textTheme.bodyLarge),
                ),
              ],
            ),
            if (busy) ...[
              const SizedBox(height: IprSpace.s3),
              if (reduce)
                ExcludeSemantics(
                  child: Icon(
                    Icons.hourglass_empty,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else
                LinearProgressIndicator(
                  semanticsLabel: l10n.checkoutProgressLabel,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Botón de acción a todo el ancho con objetivo táctil ≥ 48 dp.
class CheckoutButton extends StatelessWidget {
  const new({
    required this.label,
    required this.onPressed,
    this.primary = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    const size = Size.fromHeight(IprSpace.minTapTarget);
    return Padding(
      padding: const EdgeInsets.only(top: IprSpace.s3),
      child: primary
          ? FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(minimumSize: size),
              child: Text(label, textAlign: TextAlign.center),
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(minimumSize: size),
              child: Text(label, textAlign: TextAlign.center),
            ),
    );
  }
}

/// "Reintentar" con cuenta regresiva cuando el servidor pide esperar (429).
/// Sin `Retry-After` queda habilitado (no se inventa una espera).
class CheckoutRetryButton extends StatefulWidget {
  const new({
    required this.label,
    required this.onPressed,
    this.waitSeconds,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final int? waitSeconds;

  @override
  State<CheckoutRetryButton> createState() => _CheckoutRetryButtonState();
}

class _CheckoutRetryButtonState extends State<CheckoutRetryButton> {
  Timer? _timer;
  late int _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = (widget.waitSeconds ?? 0).clamp(0, 600);
    if (_remaining > 0) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() => _remaining--);
        if (_remaining <= 0) timer.cancel();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final waiting = _remaining > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CheckoutButton(
          label: widget.label,
          onPressed: waiting ? null : widget.onPressed,
        ),
        if (waiting)
          Padding(
            padding: const EdgeInsets.only(top: IprSpace.s2),
            child: Text(
              l10n.checkoutRetryIn(_remaining),
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}
