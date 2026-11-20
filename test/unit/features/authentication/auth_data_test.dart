import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/features/authentication/data/datasources/auth_remote_datasource.dart';
import 'package:ipr_mobile/features/authentication/data/dtos/auth_dtos.dart';
import 'package:ipr_mobile/features/authentication/data/mappers/auth_mappers.dart';
import 'package:ipr_mobile/features/authentication/data/repositories/api_auth_repository.dart';
import 'package:ipr_mobile/features/authentication/domain/entities/login_credentials.dart';
import 'package:ipr_mobile/features/authentication/domain/entities/registration.dart';

import '../../../mocks/fake_http_adapter.dart';
import '../../../mocks/test_clients.dart';
import 'support/auth_fakes.dart';

({ApiAuthRepository repo, FakeHttpAdapter adapter}) build(
  Iterable<Responder> responders,
) {
  final adapter = FakeHttpAdapter(responders);
  final client = buildTestClient(adapter: adapter).client;
  return (
    repo: ApiAuthRepository(AuthRemoteDataSource(client)),
    adapter: adapter,
  );
}

Responder ok(String fixture, {int status = 200}) =>
    (_) => FakeHttpAdapter.json(authFixture(fixture), status: status);

Responder problem(String fixture, int status, {Map<String, List<String>>? h}) =>
    (_) => FakeHttpAdapter.json(
      authFixture(fixture),
      status: status,
      headers: h ?? const {},
    );

const credentials = LoginCredentials(
  login: '  ${AuthSamples.login} ',
  password: AuthSamples.password,
);

RegistrationRequest registration() => RegistrationRequest(
  email: ' ${AuthSamples.email} ',
  firstName: ' Cliente ',
  lastName: 'Prueba',
  password: AuthSamples.password,
  acceptance: LegalAcceptance.tryCreate(
    termsVersion: AuthSamples.termsVersion,
    privacyPolicyVersion: AuthSamples.privacyVersion,
  )!,
);

void main() {
  group('M2 · RF-040 · POST /auth/login', () {
    test('AC-040-7 · la contraseña viaja solo en el cuerpo; sin token ni Idempotency-Key', () async {
      final h = build([ok('AuthSessionResponse.valid.json')]);
      final result = await h.repo.login(credentials);

      expect(result.isOk, isTrue);
      final request = h.adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, '/auth/login');
      expect(request.queryParameters, isEmpty);
      expect(request.uri.toString(), isNot(contains(AuthSamples.password)));
      expect(request.uri.toString(), isNot(contains('token')));
      // Body exacto del contrato (additionalProperties: false); el usuario se
      // recorta y la contraseña se envía tal cual.
      expect(request.data, {
        'login': AuthSamples.login,
        'password': AuthSamples.password,
      });
      expect(
        request.headers.keys.map((k) => k.toLowerCase()),
        isNot(contains('authorization')),
      );
      expect(
        request.headers.keys.map((k) => k.toLowerCase()),
        isNot(contains('idempotency-key')),
      );
      expect(request.headers['X-Device-Id'], testDeviceId);
    });

    test('200 → tokens del contrato y userId; nada más del perfil', () async {
      final h = build([ok('AuthSessionResponse.valid.json')]);
      final session = (await h.repo.login(credentials)).valueOrNull!;
      expect(session.userId, 4821);
      expect(session.tokens.accessToken, startsWith('ipra_'));
      expect(session.tokens.refreshToken, startsWith('iprr_'));
      expect(session.tokens.accessTokenExpiresIn, 900);
      expect(session.toString(), isNot(contains('example.test')));
    });

    test(
      'TC-011 · 401 invalid_credentials → Unauthorized(invalid_credentials)',
      () async {
        final h = build([problem('Problem.401-invalid-credentials.json', 401)]);
        final failure = (await h.repo.login(credentials)).failureOrNull;
        expect(failure, isA<Unauthorized>());
        expect((failure! as Unauthorized).code, 'invalid_credentials');
      },
    );

    test('AC-045-1 · 429 con retryAfter del cuerpo', () async {
      final h = build([problem('Problem.429-rate-limited.json', 429)]);
      final failure = (await h.repo.login(credentials)).failureOrNull;
      expect(failure, isA<RateLimited>());
      expect(failure!.retryAfterSeconds, 60);
    });

    test('AC-045-1 · 429 con solo cabecera Retry-After', () async {
      final h = build([
        (_) => FakeHttpAdapter.problem(
          429,
          'rate_limited',
          headers: {
            'retry-after': ['45'],
          },
        ),
      ]);
      expect(
        (await h.repo.login(credentials)).failureOrNull!.retryAfterSeconds,
        45,
      );
    });

    test('POST nunca se reintenta: un 429 es una sola petición', () async {
      final h = build([problem('Problem.429-rate-limited.json', 429)]);
      await h.repo.login(credentials);
      expect(h.adapter.requests, hasLength(1));
    });

    test(
      'TC-012 · sin red → NoConnection (no credenciales incorrectas)',
      () async {
        final h = build([FakeHttpAdapter.connectionError]);
        expect(
          (await h.repo.login(credentials)).failureOrNull,
          isA<NoConnection>(),
        );
      },
    );

    test('tiempo agotado → RequestTimeout', () async {
      final h = build([FakeHttpAdapter.timeout]);
      expect(
        (await h.repo.login(credentials)).failureOrNull,
        isA<RequestTimeout>(),
      );
    });

    test(
      'respuesta sin usuario o con token de forma inválida → ContractFailure',
      () async {
        for (final fixture in [
          'AuthSessionResponse.no-user.json',
          'AuthSessionResponse.bad-access-token.json',
        ]) {
          final h = build([ok(fixture)]);
          expect(
            (await h.repo.login(credentials)).failureOrNull,
            isA<ContractFailure>(),
            reason: fixture,
          );
        }
      },
    );

    test('503 y HTML del borde se distinguen de credenciales', () async {
      final h = build([
        (_) => FakeHttpAdapter.problem(503, 'upstream_unavailable'),
        (_) => FakeHttpAdapter.html(403),
      ]);
      expect(
        (await h.repo.login(credentials)).failureOrNull,
        isA<ServiceUnavailable>(),
      );
      expect(
        (await h.repo.login(credentials)).failureOrNull,
        isA<BlockedByEdge>(),
      );
    });
  });

  group('M2 · RF-038 · POST /auth/register', () {
    test(
      'AC-039-3 · el cuerpo lleva acceptance y NO la confirmación',
      () async {
        final h = build([ok('AuthSessionResponse.valid.json', status: 201)]);
        final result = await h.repo.register(registration());

        expect(result.isOk, isTrue);
        final request = h.adapter.requests.single;
        expect(request.path, '/auth/register');
        expect(request.method, 'POST');
        expect(request.data, {
          'email': AuthSamples.email,
          'firstName': 'Cliente',
          'lastName': 'Prueba',
          'password': AuthSamples.password,
          'acceptance': {
            'termsVersion': AuthSamples.termsVersion,
            'privacyPolicyVersion': AuthSamples.privacyVersion,
            'accepted': true,
          },
        });
        expect(request.uri.toString(), isNot(contains(AuthSamples.password)));
        expect(
          request.headers.keys.map((k) => k.toLowerCase()),
          isNot(contains('idempotency-key')),
        );
        expect(
          request.headers.keys.map((k) => k.toLowerCase()),
          isNot(contains('authorization')),
        );
      },
    );

    test('el cuerpo cumple RegisterRequest del contrato', () {
      // Mismas claves que el fixture validado contra openapi.yaml.
      final fixture =
          authFixture('RegisterRequest.valid.json')! as Map<String, dynamic>;
      final dto = registerRequestOf(registration()).toJson();
      expect(dto.keys.toSet(), fixture.keys.toSet());
      expect(
        (dto['acceptance']! as Map).keys.toSet(),
        (fixture['acceptance']! as Map).keys.toSet(),
      );
    });

    test('TC-007 · 409 → Conflict con el code del servidor', () async {
      final h = build([problem('Problem.409-conflict.json', 409)]);
      final failure = (await h.repo.register(registration())).failureOrNull;
      expect(failure, isA<Conflict>());
      expect((failure! as Conflict).code, 'email_in_use');
    });

    test('400 validation_failed → Validation con errors[] por campo', () async {
      final h = build([problem('Problem.400-validation.json', 400)]);
      final failure = (await h.repo.register(registration())).failureOrNull;
      expect(failure, isA<Validation>());
      final fields = (failure! as Validation).fields;
      expect(fields.map((e) => e.field), ['email', 'password']);
    });

    test('TC-004 · sin red → NoConnection', () async {
      final h = build([FakeHttpAdapter.connectionError]);
      expect(
        (await h.repo.register(registration())).failureOrNull,
        isA<NoConnection>(),
      );
    });
  });

  group('M2 · RF-042 · POST /auth/password/forgot', () {
    test('202 → Ok; el cuerpo solo lleva el correo recortado', () async {
      final h = build([ok('AcceptedResponse.valid.json', status: 202)]);
      final result = await h.repo.requestPasswordReset(
        '  ${AuthSamples.login} ',
      );
      expect(result.isOk, isTrue);
      final request = h.adapter.requests.single;
      expect(request.path, '/auth/password/forgot');
      expect(request.data, {'email': AuthSamples.login});
      expect(
        request.headers.keys.map((k) => k.toLowerCase()),
        isNot(contains('authorization')),
      );
    });

    test(
      'TC-026 · AC-042-4 · dos respuestas 202 iguales dan el mismo resultado',
      () async {
        final h = build([
          ok('AcceptedResponse.valid.json', status: 202),
          ok('AcceptedResponse.valid.json', status: 202),
        ]);
        final a = await h.repo.requestPasswordReset(
          'qa.cliente.01@example.test',
        );
        final b = await h.repo.requestPasswordReset('qa.nadie@example.test');
        expect(a.isOk, isTrue);
        expect(b.isOk, isTrue);
      },
    );

    test('AC-042-8 · sin red → NoConnection; 429 → RateLimited', () async {
      final h = build([
        FakeHttpAdapter.connectionError,
        problem('Problem.429-rate-limited.json', 429),
      ]);
      expect(
        (await h.repo.requestPasswordReset(AuthSamples.login)).failureOrNull,
        isA<NoConnection>(),
      );
      expect(
        (await h.repo.requestPasswordReset(AuthSamples.login)).failureOrNull,
        isA<RateLimited>(),
      );
    });
  });

  group('M2 · DTO', () {
    test('AuthSessionDto.fromJson lee solo session y user.id', () {
      final dto = AuthSessionDto.fromJson(
        authFixture('AuthSessionResponse.valid.json'),
      );
      expect(dto.userId, 4821);
      expect(dto.toString(), 'AuthSessionDto(<redacted>)');
    });

    test('AuthSessionDto.fromJson rechaza formas inválidas', () {
      for (final json in <Object?>[
        null,
        'texto',
        <String, dynamic>{},
        {'data': 'x'},
        {'data': <String, dynamic>{}},
        jsonDecode(
          jsonEncode({
            'data': {
              'session': 1,
              'user': {'id': 1},
            },
          }),
        ),
      ]) {
        expect(
          () => AuthSessionDto.fromJson(json),
          throwsFormatException,
          reason: '$json',
        );
      }
      // user.id con tipo erróneo.
      final bad = jsonDecode(
        jsonEncode(authFixture('AuthSessionResponse.valid.json')),
      ) as Map<String, dynamic>;
      ((bad['data'] as Map<String, dynamic>)['user']!
              as Map<String, dynamic>)['id'] =
          'x';
      expect(() => AuthSessionDto.fromJson(bad), throwsFormatException);
    });

    test('los DTO de petición no imprimen valores', () {
      const login = LoginRequestDto(
        login: AuthSamples.login,
        password: AuthSamples.password,
      );
      const forgot = ForgotPasswordRequestDto(email: AuthSamples.login);
      for (final text in [
        login.toString(),
        forgot.toString(),
        registerRequestOf(registration()).toString(),
      ]) {
        expect(text, contains('<redacted>'));
        expect(text, isNot(contains(AuthSamples.password)));
        expect(text, isNot(contains('example.test')));
      }
    });

    test('mapAuthSession conserva solo tokens y userId', () {
      final dto = AuthSessionDto.fromJson(
        authFixture('AuthSessionResponse.valid.json'),
      );
      final entity = mapAuthSession(dto);
      expect(entity.userId, dto.userId);
      expect(entity.tokens, same(dto.tokens));
    });
  });
}
