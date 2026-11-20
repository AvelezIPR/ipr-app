import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/authentication/data/datasources/auth_remote_datasource.dart';
import 'package:ipr_mobile/features/authentication/data/dtos/auth_dtos.dart';
import 'package:ipr_mobile/features/authentication/data/mappers/auth_mappers.dart';
import 'package:ipr_mobile/features/authentication/domain/entities/authenticated_session.dart';
import 'package:ipr_mobile/features/authentication/domain/entities/login_credentials.dart';
import 'package:ipr_mobile/features/authentication/domain/entities/registration.dart';
import 'package:ipr_mobile/features/authentication/domain/repositories/auth_repository.dart';

/// Implementación sobre `/mobile/v1`. No persiste NADA: ni la contraseña, ni el
/// correo, ni la respuesta; la sesión la guarda quien llama con
/// `SessionController.setSession`.
final class ApiAuthRepository implements AuthRepository {
  const new(this._remote);

  final AuthRemoteDataSource _remote;

  @override
  Future<Result<AuthenticatedSession>> login(
    LoginCredentials credentials, {
    RequestCancellation? cancellation,
  }) async => (await _remote.login(
    loginRequestOf(credentials),
    cancellation: cancellation,
  )).map(mapAuthSession);

  @override
  Future<Result<AuthenticatedSession>> register(
    RegistrationRequest request, {
    RequestCancellation? cancellation,
  }) async => (await _remote.register(
    registerRequestOf(request),
    cancellation: cancellation,
  )).map(mapAuthSession);

  @override
  Future<Result<void>> requestPasswordReset(
    String email, {
    RequestCancellation? cancellation,
  }) => _remote.requestPasswordReset(
    ForgotPasswordRequestDto(email: email.trim()),
    cancellation: cancellation,
  );
}
