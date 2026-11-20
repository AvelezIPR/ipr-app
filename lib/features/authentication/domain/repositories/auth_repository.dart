import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/authentication/domain/entities/authenticated_session.dart';
import 'package:ipr_mobile/features/authentication/domain/entities/login_credentials.dart';
import 'package:ipr_mobile/features/authentication/domain/entities/registration.dart';

/// Autenticación contra `/mobile/v1/auth/*`. Devuelve `Result`: ningún error
/// de red llega a la interfaz como excepción.
///
/// Ninguna operación guarda datos: la sesión la guarda el controlador con
/// `SessionController.setSession`.
abstract interface class AuthRepository {
  /// `POST /auth/login`. `401 invalid_credentials` es uniforme (cuenta
  /// inexistente, rol administrativo, cuenta en eliminación).
  Future<Result<AuthenticatedSession>> login(
    LoginCredentials credentials, {
    RequestCancellation? cancellation,
  });

  /// `POST /auth/register` con la aceptación de términos y política.
  Future<Result<AuthenticatedSession>> register(
    RegistrationRequest request, {
    RequestCancellation? cancellation,
  });

  /// `POST /auth/password/forgot`: el servidor responde `202` exista o no la
  /// cuenta; el restablecimiento se completa en WordPress.
  Future<Result<void>> requestPasswordReset(
    String email, {
    RequestCancellation? cancellation,
  });
}
