import 'package:ipr_mobile/features/authentication/data/dtos/auth_dtos.dart';
import 'package:ipr_mobile/features/authentication/domain/entities/authenticated_session.dart';
import 'package:ipr_mobile/features/authentication/domain/entities/login_credentials.dart';
import 'package:ipr_mobile/features/authentication/domain/entities/registration.dart';

AuthenticatedSession mapAuthSession(AuthSessionDto dto) =>
    AuthenticatedSession(tokens: dto.tokens, userId: dto.userId);

LoginRequestDto loginRequestOf(LoginCredentials credentials) => LoginRequestDto(
  // El usuario o correo se recorta; la contraseña se envía tal cual.
  login: credentials.login.trim(),
  password: credentials.password,
);

RegisterRequestDto registerRequestOf(RegistrationRequest request) =>
    RegisterRequestDto(
      email: request.email.trim(),
      firstName: request.firstName.trim(),
      lastName: request.lastName.trim(),
      password: request.password,
      termsVersion: request.acceptance.termsVersion,
      privacyPolicyVersion: request.acceptance.privacyPolicyVersion,
    );
