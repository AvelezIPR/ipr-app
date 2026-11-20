import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ipr_mobile/core/session/session_controller.dart';
import 'package:ipr_mobile/core/session/session_state.dart';
import 'package:ipr_mobile/features/authentication/domain/rules/auth_validation.dart';
import 'package:ipr_mobile/features/authentication/presentation/controllers/auth_form_state.dart';
import 'package:ipr_mobile/features/authentication/presentation/controllers/login_controller.dart';
import 'package:ipr_mobile/features/authentication/presentation/screens/auth_routes.dart';
import 'package:ipr_mobile/features/authentication/presentation/widgets/auth_form_widgets.dart';
import 'package:ipr_mobile/features/authentication/presentation/widgets/auth_texts.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:ipr_mobile/shared/navigation/routes.dart';
import 'package:material_ui/material_ui.dart';

/// Inicio de sesión `/login` (PT-14; RF-040, RF-042, RF-043, RF-045, RF-048).
///
/// * Correo o usuario + contraseña enmascarada (mostrar/ocultar accesible).
/// * Una sola solicitud a la vez; validación local previa con error junto al
///   campo; los `errors[]` del servidor también se muestran junto al campo.
/// * Credenciales incorrectas, rol bloqueado y cuenta en eliminación: UN solo
///   mensaje. Sin red NO es "credenciales incorrectas". `429`: cuenta
///   regresiva y botón deshabilitado, sin revelar si la cuenta existe.
/// * Al terminar, el router (que observa la sesión) vuelve a `from` o lleva a
///   Cuenta: esta pantalla no navega.
/// * Nada se guarda: la contraseña no sale del campo de texto, que se limpia
///   al salir.
class LoginScreen extends ConsumerStatefulWidget {
  /// [from] es la ruta interna de origen (parámetro `from` de `/login`); solo
  /// se reenvía a Registro para no perderla (el router valida la lista
  /// cerrada de rutas antes de usarla).
  const new({super.key, this.from});

  final String? from;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _login = TextEditingController();
  final _password = TextEditingController();
  final _loginFocus = FocusNode();
  final _passwordFocus = FocusNode();

  @override
  void dispose() {
    // Limpia lo escrito (la contraseña no debe sobrevivir a la pantalla).
    _login.clear();
    _password.clear();
    _login.dispose();
    _password.dispose();
    _loginFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final controller = ref.read(loginControllerProvider.notifier);
    final ok = await controller.submit(
      login: _login.text,
      password: _password.text,
    );
    if (!mounted || ok) return;
    final state = ref.read(loginControllerProvider);
    if (state.problem == AuthProblem.invalidCredentials) {
      // Tras un rechazo la contraseña se limpia y el foco vuelve a ella.
      _password.clear();
      _passwordFocus.requestFocus();
      return;
    }
    if (state.fieldIssues.containsKey(AuthField.login)) {
      _loginFocus.requestFocus();
    } else if (state.fieldIssues.containsKey(AuthField.password)) {
      _passwordFocus.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(loginControllerProvider);
    final expired = ref.watch(sessionControllerProvider) is SessionExpired;

    return AuthFormScaffold(
      title: l10n.authenticationLoginTitle,
      children: [
        if (expired)
          AuthBanner(
            message: l10n.authenticationSessionExpiredNotice,
            isError: false,
          ),
        AuthProblemBanner(state: state),
        AuthTextField(
          controller: _login,
          focusNode: _loginFocus,
          label: l10n.authenticationFieldLogin,
          autofillHints: AuthAutofill.login,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          errorText: authFieldError(l10n, state, AuthField.login),
          onSubmitted: (_) => _passwordFocus.requestFocus(),
        ),
        const SizedBox(height: IprSpace.s4),
        PasswordField(
          controller: _password,
          focusNode: _passwordFocus,
          label: l10n.authenticationFieldPassword,
          autofillHints: AuthAutofill.password,
          textInputAction: TextInputAction.done,
          errorText: authFieldError(l10n, state, AuthField.password),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: IprSpace.s5),
        AuthSubmitButton(
          label: l10n.authenticationLoginSubmit,
          state: state,
          onPressed: _submit,
        ),
        const SizedBox(height: IprSpace.s3),
        AuthLinkButton(
          label: l10n.authenticationLoginForgotLink,
          onPressed: () => context.push(Routes.passwordRecovery),
        ),
        AuthLinkButton(
          label: l10n.authenticationLoginRegisterLink,
          onPressed: () => context.pushReplacement(
            authLocation(Routes.register, widget.from),
          ),
        ),
        AuthLinkButton(
          label: l10n.authenticationLoginLegalLink,
          onPressed: () => context.push(Routes.legal),
        ),
      ],
    );
  }
}
