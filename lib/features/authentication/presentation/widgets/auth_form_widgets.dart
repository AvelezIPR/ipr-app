import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ipr_mobile/core/providers.dart';
import 'package:ipr_mobile/features/authentication/presentation/controllers/auth_form_state.dart';
import 'package:ipr_mobile/features/authentication/presentation/widgets/auth_texts.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:ipr_mobile/shared/navigation/routes.dart';
import 'package:ipr_mobile/shared/widgets/sensitive_screen.dart';
import 'package:material_ui/material_ui.dart';

/// Estructura común de las pantallas de autenticación: barra superior, captura
/// bloqueada (`SensitiveScreen`, SC-035), contenido desplazable (el teclado y
/// el texto al 200 % no tapan el botón), ancho acotado y `AutofillGroup`.
class AuthFormScaffold extends ConsumerWidget {
  const new({required this.title, required this.children, super.key});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        // Si la pantalla se abrió por una guarda (no hay a dónde volver), el
        // botón lleva al inicio sin sesión (AC-037-3).
        leading: context.canPop()
            ? null
            : IconButton(
                tooltip: l10n.authenticationBackToHome,
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
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.all(IprSpace.s4),
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Campo de texto de los formularios de autenticación.
class AuthTextField extends StatelessWidget {
  const new({
    required this.controller,
    required this.label,
    required this.autofillHints,
    super.key,
    this.focusNode,
    this.errorText,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.onSubmitted,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final Iterable<String> autofillHints;
  final FocusNode? focusNode;
  final String? errorText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      autofillHints: autofillHints,
      autocorrect: false,
      enableSuggestions: false,
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        errorMaxLines: 4,
      ),
    );
  }
}

/// Campo de contraseña: enmascarado, con botón accesible para mostrar/ocultar
/// (RNF-073). Se vuelve a enmascarar al pasar a segundo plano (AC-040-8). El
/// pegado y los gestores de contraseñas están permitidos (SC-035).
class PasswordField extends StatefulWidget {
  const new({
    required this.controller,
    required this.label,
    required this.autofillHints,
    super.key,
    this.focusNode,
    this.errorText,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final Iterable<String> autofillHints;
  final FocusNode? focusNode;
  final String? errorText;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField>
    with WidgetsBindingObserver {
  bool _obscured = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Cualquier estado distinto de "activa" vuelve a enmascarar.
    if (state != AppLifecycleState.resumed && !_obscured) {
      setState(() => _obscured = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      obscureText: _obscured,
      autofillHints: widget.autofillHints,
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: widget.textInputAction,
      onSubmitted: widget.onSubmitted,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        labelText: widget.label,
        errorText: widget.errorText,
        errorMaxLines: 4,
        suffixIcon: IconButton(
          tooltip: _obscured
              ? l10n.authenticationPasswordShow
              : l10n.authenticationPasswordHide,
          icon: Icon(_obscured ? Icons.visibility : Icons.visibility_off),
          constraints: const BoxConstraints(
            minWidth: IprSpace.minTapTarget,
            minHeight: IprSpace.minTapTarget,
          ),
          onPressed: () => setState(() => _obscured = !_obscured),
        ),
      ),
    );
  }
}

/// Aviso de formulario (error, espera o conflicto): ícono + texto (nunca solo
/// color) anunciado a los lectores de pantalla (`liveRegion`).
class AuthBanner extends StatelessWidget {
  const new({
    required this.message,
    super.key,
    this.countdownText,
    this.actions = const [],
    this.isError = true,
  });

  final String message;

  /// Línea con la espera restante. No es `liveRegion`: se actualiza cada
  /// segundo y no debe anunciarse cada vez.
  final String? countdownText;
  final List<Widget> actions;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final background = isError
        ? scheme.errorContainer
        : scheme.surfaceContainer;
    return Padding(
      padding: const EdgeInsets.only(bottom: IprSpace.s4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(IprRadius.md),
          border: Border.all(color: isError ? scheme.error : scheme.outline),
        ),
        child: Padding(
          padding: const EdgeInsets.all(IprSpace.s3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      isError ? Icons.error_outline : Icons.info_outline,
                      color: isError ? scheme.error : scheme.primary,
                    ),
                  ),
                  const SizedBox(width: IprSpace.s2),
                  Expanded(
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        message,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (countdownText != null) ...[
                const SizedBox(height: IprSpace.s2),
                Text(countdownText!, style: theme.textTheme.bodyMedium),
              ],
              ...actions,
            ],
          ),
        ),
      ),
    );
  }
}

/// Aviso de formulario derivado del estado ([AuthFormState.problem]) con la
/// espera restante cuando hay cuenta regresiva.
class AuthProblemBanner extends StatelessWidget {
  const new({required this.state, super.key, this.actions = const []});

  final AuthFormState state;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final message = authProblemText(l10n, state);
    if (message == null) return const SizedBox.shrink();
    return AuthBanner(
      message: message,
      countdownText: state.coolingDown
          ? l10n.authenticationRateLimitedCountdown(
              formatWait(state.cooldownSeconds),
            )
          : null,
      actions: actions,
    );
  }
}

/// Botón principal: una sola solicitud a la vez, con indicador de progreso
/// accesible y, durante una espera, el tiempo restante.
class AuthSubmitButton extends StatelessWidget {
  const new({
    required this.label,
    required this.state,
    required this.onPressed,
    super.key,
    this.enabled = true,
  });

  final String label;
  final AuthFormState state;
  final VoidCallback onPressed;

  /// Condición adicional del formulario (p. ej. hay versiones legales).
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = state.coolingDown
        ? l10n.authenticationSubmitWait(formatWait(state.cooldownSeconds))
        : label;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: IprSpace.minTapTarget),
      child: FilledButton(
        onPressed: (state.canSubmit && enabled) ? onPressed : null,
        child: state.submitting
            ? Semantics(
                liveRegion: true,
                label: l10n.authenticationSubmitting,
                child: const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              )
            : Text(text, textAlign: TextAlign.center),
      ),
    );
  }
}

/// Enlace de texto con objetivo táctil de 48 dp.
class AuthLinkButton extends StatelessWidget {
  const new({required this.label, required this.onPressed, super.key});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      minimumSize: const Size(IprSpace.minTapTarget, IprSpace.minTapTarget),
      padding: const EdgeInsets.symmetric(
        horizontal: IprSpace.s3,
        vertical: IprSpace.s2,
      ),
    ),
    child: Text(label, textAlign: TextAlign.center),
  );
}

/// Pistas de autocompletado por campo (`autofillHints`).
abstract final class AuthAutofill {
  static const List<String> login = [
    AutofillHints.username,
    AutofillHints.email,
  ];
  static const List<String> password = [AutofillHints.password];
  static const List<String> newPassword = [AutofillHints.newPassword];
  static const List<String> email = [AutofillHints.email];
  static const List<String> givenName = [AutofillHints.givenName];
  static const List<String> familyName = [AutofillHints.familyName];
}
