import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override, ProviderListenable;
import 'package:ipr_mobile/core/config/remote_config.dart';
import 'package:ipr_mobile/core/config/remote_config_controller.dart';
import 'package:ipr_mobile/core/config/remote_config_repository.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/core/session/session_controller.dart';
import 'package:ipr_mobile/core/session/session_tokens.dart';
import 'package:ipr_mobile/core/session/token_store.dart';
import 'package:ipr_mobile/core/storage/secure_key_value.dart';
import 'package:ipr_mobile/features/authentication/authentication_providers.dart';
import 'package:ipr_mobile/features/authentication/domain/entities/authenticated_session.dart';
import 'package:ipr_mobile/features/authentication/domain/entities/login_credentials.dart';
import 'package:ipr_mobile/features/authentication/domain/entities/registration.dart';
import 'package:ipr_mobile/features/authentication/domain/repositories/auth_repository.dart';

import '../../../../mocks/fake_session_remote.dart';
import '../../../../mocks/memory_secure_key_value.dart';

/// Contraseñas y datos SINTÉTICOS (nunca reales) usados en las pruebas.
abstract final class AuthSamples {
  static const email = 'qa.cliente.nuevo@example.test';
  static const login = 'qa.cliente.01@example.test';
  static const password = 'Qa123456';
  static const wrongPassword = 'Incorrecta-999';
  static const termsVersion = '2026-01';
  static const privacyVersion = '2026-01';
}

/// Lee un fixture de `test/fixtures/authentication/`.
Object? authFixture(String name) =>
    jsonDecode(File('test/fixtures/authentication/$name').readAsStringSync());

/// Tokens del fixture `AuthSessionResponse.valid.json`.
SessionTokens fixtureTokens() => SessionTokens.fromSessionJson(
  ((authFixture('AuthSessionResponse.valid.json')!
          as Map<String, dynamic>)['data']!
      as Map<String, dynamic>)['session'],
);

AuthenticatedSession fixtureSession({int userId = 4821}) =>
    AuthenticatedSession(tokens: fixtureTokens(), userId: userId);

/// Llamada pendiente a un método del repositorio: la prueba decide cuándo y
/// cómo responde.
final class PendingCall<T> {
  new(this.cancellation, this.completer);

  final RequestCancellation? cancellation;
  final Completer<Result<T>> completer;

  void ok(T value) => completer.complete(Ok(value));
  void fail(AppFailure failure) => completer.complete(Err(failure));
}

/// Doble de [AuthRepository]. Cada llamada queda registrada y se queda
/// pendiente hasta que la prueba la resuelva (o responde sola con
/// [autoLogin] / [autoRegister] / [autoReset]).
final class FakeAuthRepository implements AuthRepository {
  new({this.autoLogin, this.autoRegister, this.autoReset});

  Result<AuthenticatedSession>? autoLogin;
  Result<AuthenticatedSession>? autoRegister;
  Result<void>? autoReset;

  final loginCalls = <(LoginCredentials, PendingCall<AuthenticatedSession>)>[];
  final registerCalls =
      <(RegistrationRequest, PendingCall<AuthenticatedSession>)>[];
  final resetCalls = <(String, PendingCall<void>)>[];

  @override
  Future<Result<AuthenticatedSession>> login(
    LoginCredentials credentials, {
    RequestCancellation? cancellation,
  }) {
    final call = PendingCall<AuthenticatedSession>(
      cancellation,
      Completer<Result<AuthenticatedSession>>(),
    );
    loginCalls.add((credentials, call));
    if (autoLogin != null) call.completer.complete(autoLogin);
    return call.completer.future;
  }

  @override
  Future<Result<AuthenticatedSession>> register(
    RegistrationRequest request, {
    RequestCancellation? cancellation,
  }) {
    final call = PendingCall<AuthenticatedSession>(
      cancellation,
      Completer<Result<AuthenticatedSession>>(),
    );
    registerCalls.add((request, call));
    if (autoRegister != null) call.completer.complete(autoRegister);
    return call.completer.future;
  }

  @override
  Future<Result<void>> requestPasswordReset(
    String email, {
    RequestCancellation? cancellation,
  }) {
    final call = PendingCall<void>(cancellation, Completer<Result<void>>());
    resetCalls.add((email, call));
    if (autoReset != null) call.completer.complete(autoReset);
    return call.completer.future;
  }

  int get totalCalls =>
      loginCalls.length + registerCalls.length + resetCalls.length;
}

/// `RemoteConfigController` con una configuración fija y un contador de
/// recargas (sin red).
final class FakeRemoteConfigController extends RemoteConfigController {
  new(this._config);

  RemoteConfig _config;
  int refreshes = 0;

  /// La siguiente recarga publica esta configuración (si no es nula).
  RemoteConfig? onRefresh;

  @override
  RemoteConfigState build() =>
      RemoteConfigState(config: _config, source: RemoteConfigSource.network);

  @override
  Future<void> refresh() async {
    refreshes++;
    final next = onRefresh;
    if (next != null) {
      _config = next;
      state = state.copyWith(config: next);
    }
  }
}

/// Configuración con las versiones legales vigentes.
const legalConfig = RemoteConfig(
  termsVersion: AuthSamples.termsVersion,
  termsUrl: 'https://example.invalid/terminos',
  privacyPolicyVersion: AuthSamples.privacyVersion,
  privacyPolicyUrl: 'https://example.invalid/privacidad',
);

/// Lo necesario para ejercitar los controladores con la sesión REAL
/// (`SessionController`) sobre un almacén seguro en memoria.
final class AuthHarness {
  new({
    FakeAuthRepository? repo,
    RemoteConfig config = legalConfig,
    SecureKeyValue? secureStore,
    List<Override> extra = const [],
  }) : repo = repo ?? FakeAuthRepository(),
       secure = InMemorySecureKeyValue(),
       sessionRemote = FakeSessionRemote() {
    remoteConfig = FakeRemoteConfigController(config);
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(this.repo),
        sessionDependenciesProvider.overrideWithValue(
          SessionDependencies(
            tokenStore: TokenStore(secureStore ?? secure),
            remote: sessionRemote,
          ),
        ),
        remoteConfigProvider.overrideWith(() => remoteConfig),
        ...extra,
      ],
    );
  }

  final FakeAuthRepository repo;
  final InMemorySecureKeyValue secure;
  final FakeSessionRemote sessionRemote;
  late final FakeRemoteConfigController remoteConfig;
  late final ProviderContainer container;

  /// Mantiene vivo un provider autoDispose durante la prueba.
  void keepAlive(ProviderListenable<Object?> provider) =>
      container.listen(provider, (_, _) {});

  void dispose() => container.dispose();
}

Future<void> flush() => Future<void>.delayed(Duration.zero);

/// Almacén seguro que falla al escribir (simula un Keystore/Keychain roto).
final class ThrowingSecureKeyValue implements SecureKeyValue {
  const new();

  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async =>
      throw StateError('almacén no disponible');

  @override
  Future<void> delete(String key) async {}

  @override
  Future<void> deleteAll() async {}
}
