import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/authentication/authentication_providers.dart';
import 'package:ipr_mobile/features/authentication/domain/entities/authenticated_session.dart';
import 'package:ipr_mobile/features/authentication/domain/entities/login_credentials.dart';
import 'package:ipr_mobile/features/authentication/domain/rules/auth_validation.dart';
import 'package:ipr_mobile/features/authentication/presentation/controllers/auth_form_controller.dart';
import 'package:ipr_mobile/features/authentication/presentation/controllers/auth_form_state.dart';

final NotifierProvider<LoginController, AuthFormState> loginControllerProvider =
    NotifierProvider.autoDispose<LoginController, AuthFormState>(
      LoginController.new,
    );

/// Inicio de sesión (RF-040, RF-045, RF-048).
///
/// Cuenta inexistente, contraseña errónea, rol administrativo y cuenta en
/// eliminación llegan como el MISMO `401 invalid_credentials` y se muestran con
/// el MISMO mensaje (AC-040-2, AC-048-1). Por la misma razón un `403` del BFF
/// se presenta igual: un mensaje distinto delataría la cuenta. Un error de red
/// NO es "credenciales incorrectas".
class LoginController extends AuthFormController {
  /// Valida y envía. Devuelve `true` solo si la sesión quedó guardada.
  Future<bool> submit({required String login, required String password}) async {
    if (busy) return false;
    final issues = AuthValidation.forLogin(login: login, password: password);
    if (issues.isNotEmpty) {
      rejectLocally(issues);
      return false;
    }
    final cancellation = startRequest();
    final result = await ref
        .read(authRepositoryProvider)
        .login(
          LoginCredentials(login: login, password: password),
          cancellation: cancellation,
        );
    if (!ref.mounted) return false;
    switch (result) {
      case Ok<AuthenticatedSession>(:final value):
        return await establishSession(value);
      case Err<AuthenticatedSession>(:final failure):
        failWith(
          failure,
          problem: switch (failure) {
            Unauthorized() || Forbidden() => AuthProblem.invalidCredentials,
            _ => null,
          },
        );
        return false;
    }
  }
}
