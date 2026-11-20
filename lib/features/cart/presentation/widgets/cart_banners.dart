import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Aviso del carrito con ícono, texto y acciones (nunca solo color,
/// RNF-076). Es una región viva: el lector de pantalla lo anuncia al aparecer.
class CartNotice extends StatelessWidget {
  const new({
    required this.icon,
    required this.title,
    super.key,
    this.body,
    this.actions = const [],
    this.isError = false,
  });

  final IconData icon;
  final String title;
  final String? body;
  final List<Widget> actions;

  /// Error (rojo suave) o información (tinte de marca).
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = isError
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.primaryContainer;
    final foreground = isError
        ? theme.colorScheme.onErrorContainer
        : theme.colorScheme.onPrimaryContainer;
    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(IprRadius.md),
        ),
        child: Padding(
          padding: const EdgeInsets.all(IprSpace.s3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(child: Icon(icon, color: foreground)),
                  const SizedBox(width: IprSpace.s2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: foreground,
                          ),
                        ),
                        if (body != null) ...[
                          const SizedBox(height: IprSpace.s1),
                          Text(
                            body!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: foreground,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: IprSpace.s2),
                Wrap(
                  spacing: IprSpace.s2,
                  runSpacing: IprSpace.s1,
                  children: actions,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Texto de por qué no se pudo verificar el carrito: sin red se dice que el
/// pago exige conexión (RNF-020); cualquier otro fallo, el mensaje general.
String cartVerifyFailureText(AppLocalizations l10n, AppFailure failure) =>
    failure is NoConnection
    ? l10n.cartVerifyFailedOffline
    : l10n.cartVerifyFailed;
