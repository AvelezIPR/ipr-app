import 'package:ipr_mobile/features/home/presentation/widgets/section_skeleton.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:ipr_mobile/shared/widgets/failure_messages.dart';
import 'package:ipr_mobile/shared/widgets/ui_state.dart';
import 'package:material_ui/material_ui.dart';

/// Marco de una sección del inicio con su propio estado: cargando (esqueleto),
/// datos, vacío y error con "Reintentar". Un bloque que falla NO afecta a los
/// demás (AC-003-4).
///
/// [emptyBuilder] nulo = una lista vacía oculta la sección entera (bloques
/// opcionales como marcas o más vendidos); si se entrega, pinta el mensaje
/// propio de la sección (categorías, AC-002-3).
class HomeSection<T> extends StatelessWidget {
  const new({
    required this.title,
    required this.state,
    required this.builder,
    required this.onRetry,
    super.key,
    this.emptyBuilder,
    this.skeletonHeight = 120,
  });

  final String title;
  final UiState<T> state;
  final Widget Function(BuildContext context, T value) builder;
  final VoidCallback onRetry;
  final WidgetBuilder? emptyBuilder;
  final double skeletonHeight;

  @override
  Widget build(BuildContext context) {
    final body = switch (state) {
      UiLoading<T>() => SectionSkeleton(title: title, height: skeletonHeight),
      UiEmpty<T>() => emptyBuilder?.call(context),
      UiFailure<T>(:final failure) => _SectionError(
        message: failureText(AppLocalizations.of(context), failure),
        retryable: failure.retryable,
        onRetry: onRetry,
      ),
      UiData<T>(:final value) => builder(context, value),
    };
    if (body == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: IprSpace.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: theme.textTheme.titleLarge),
          ),
          const SizedBox(height: IprSpace.s3),
          body,
        ],
      ),
    );
  }
}

/// Error compacto de una sección (no ocupa la pantalla: es un bloque dentro
/// de una lista desplazable).
class _SectionError extends StatelessWidget {
  const new({
    required this.message,
    required this.retryable,
    required this.onRetry,
  });

  final String message;
  final bool retryable;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(IprRadius.xl),
      ),
      child: Padding(
        padding: const EdgeInsets.all(IprSpace.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.error_outline,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
                const SizedBox(width: IprSpace.s2),
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (retryable) ...[
              const SizedBox(height: IprSpace.s3),
              OutlinedButton(onPressed: onRetry, child: Text(l10n.actionRetry)),
            ],
          ],
        ),
      ),
    );
  }
}
