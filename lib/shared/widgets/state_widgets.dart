import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:ipr_mobile/shared/widgets/failure_messages.dart';
import 'package:ipr_mobile/shared/widgets/ui_state.dart';
import 'package:material_ui/material_ui.dart';

/// Cargando: indicador accesible; sin animación si el sistema pide
/// movimiento reducido (RNF-074).
class LoadingState extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final reduce = MediaQuery.of(context).disableAnimations;
    return Center(
      child: Semantics(
        liveRegion: true,
        label: l10n.stateLoading,
        child: reduce
            ? const Icon(Icons.hourglass_empty)
            : const CircularProgressIndicator(),
      ),
    );
  }
}

/// Vacío real (el servidor respondió 200 con lista vacía).
class EmptyState extends StatelessWidget {
  const new({super.key, this.title, this.body, this.action});

  final String? title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Center(
      // Desplazable: a texto de sistema al 200 % o con poca altura el contenido
      // no se corta ni desborda (RNF-068).
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(IprSpace.s5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.search_off,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: IprSpace.s3),
            Text(
              title ?? l10n.stateEmptyTitle,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: IprSpace.s2),
            Text(
              body ?? l10n.stateEmptyBody,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: IprSpace.s4),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Error con mensaje es-CO y acción "Reintentar" cuando es reintentable.
/// Distinto de [EmptyState]: un fallo de red nunca se presenta como "sin
/// resultados" (P4).
class ErrorState extends StatelessWidget {
  const new({required this.failure, super.key, this.onRetry});

  final AppFailure failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Center(
      // Desplazable: a texto de sistema al 200 % o con poca altura el contenido
      // no se corta ni desborda (RNF-068).
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(IprSpace.s5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.error_outline,
                size: 48,
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: IprSpace.s3),
            Semantics(
              liveRegion: true,
              child: Text(
                failureText(l10n, failure),
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
            ),
            if (failure.retryable && onRetry != null) ...[
              const SizedBox(height: IprSpace.s4),
              FilledButton(onPressed: onRetry, child: Text(l10n.actionRetry)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Aviso de datos guardados, no bloqueante (RNF-022). Texto + ícono: nunca
/// solo color (RNF-076).
class StaleBanner extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(color: theme.colorScheme.primaryContainer),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: IprSpace.s4,
            vertical: IprSpace.s2,
          ),
          child: Row(
            children: [
              ExcludeSemantics(
                child: Icon(
                  Icons.info_outline,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: IprSpace.s2),
              Expanded(
                child: Text(
                  l10n.staleBanner,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pinta un [UiState] con los componentes compartidos.
class AsyncView<T> extends StatelessWidget {
  const new({
    required this.state,
    required this.builder,
    super.key,
    this.onRetry,
    this.empty,
  });

  final UiState<T> state;
  final Widget Function(BuildContext context, T value) builder;
  final VoidCallback? onRetry;
  final Widget? empty;

  @override
  Widget build(BuildContext context) => switch (state) {
    UiLoading<T>() => const LoadingState(),
    UiEmpty<T>() => empty ?? const EmptyState(),
    UiFailure<T>(:final failure) => ErrorState(
      failure: failure,
      onRetry: onRetry,
    ),
    UiData<T>(:final value, :final stale) => Column(
      children: [
        if (stale) const StaleBanner(),
        Expanded(child: builder(context, value)),
      ],
    ),
  };
}
