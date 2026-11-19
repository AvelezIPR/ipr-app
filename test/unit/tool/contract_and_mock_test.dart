import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/config/app_config.dart';
import 'package:ipr_mobile/core/config/remote_config_dto.dart';
import 'package:ipr_mobile/core/config/remote_config_repository.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/api_client.dart';
import 'package:ipr_mobile/core/network/api_request.dart';
import 'package:ipr_mobile/core/network/interceptors/app_headers_interceptor.dart';
import 'package:ipr_mobile/core/network/interceptors/error_mapping_interceptor.dart';
import 'package:ipr_mobile/core/network/interceptors/retry_interceptor.dart';
import 'package:ipr_mobile/core/network/problem.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/core/network/uuid_v4.dart';
import 'package:ipr_mobile/core/session/session_remote.dart';
import 'package:ipr_mobile/core/session/session_tokens.dart';
import 'package:ipr_mobile/core/storage/cache_store.dart';

import '../../../tool/contract/openapi_contract.dart';
import '../../../tool/mock_bff/mock_bff.dart';

Object? fixture(String name) =>
    jsonDecode(File('test/fixtures/contract/$name').readAsStringSync());

String bearer() => 'Bearer ipra_${'A' * 43}';

void main() {
  late OpenApiContract contract;
  setUpAll(() => contract = OpenApiContract.load('contract/openapi.yaml'));

  group('ST-016 · QG-M06 · validador de contrato', () {
    test('todos los fixtures cumplen o incumplen según su manifiesto', () {
      final manifest = fixture('manifest.json')! as Map<String, dynamic>;
      for (final item
          in (manifest['fixtures'] as List<dynamic>)
              .cast<Map<String, dynamic>>()) {
        var data = fixture(item['file'] as String);
        final inner = item['path'] as String?;
        if (inner != null) data = (data! as Map<String, dynamic>)[inner];
        final errors = contract.validate(
          data,
          contract.schema(item['schema'] as String),
        );
        expect(
          errors.isEmpty,
          item['valid'],
          reason: '${item['file']}: $errors',
        );
      }
    });

    test(
      'detecta tipos, requeridos, enum, patrón, formato y propiedades extra',
      () {
        Map<String, dynamic> s(Map<String, dynamic> m) => m;
        expect(contract.validate(1, s({'type': 'string'})), isNotEmpty);
        expect(
          contract.validate(
            'x',
            s({
              'type': ['string', 'null'],
            }),
          ),
          isEmpty,
        );
        expect(
          contract.validate(
            null,
            s({
              'type': ['string', 'null'],
            }),
          ),
          isEmpty,
        );
        expect(contract.validate(2.0, s({'type': 'integer'})), isEmpty);
        expect(contract.validate(2.5, s({'type': 'integer'})), isNotEmpty);
        expect(
          contract.validate(
            'c',
            s({
              'enum': ['a', 'b'],
            }),
          ),
          isNotEmpty,
        );
        expect(contract.validate('x', s({'const': 'y'})), isNotEmpty);
        expect(contract.validate('abc', s({'pattern': r'^\d+$'})), isNotEmpty);
        expect(contract.validate('ab', s({'minLength': 3})), isNotEmpty);
        expect(contract.validate('abcd', s({'maxLength': 3})), isNotEmpty);
        expect(contract.validate(5, s({'minimum': 6})), isNotEmpty);
        expect(contract.validate(5, s({'maximum': 4})), isNotEmpty);
        expect(
          contract.validate([1], s({'type': 'array', 'minItems': 2})),
          isNotEmpty,
        );
        expect(
          contract.validate([1, 2, 3], s({'type': 'array', 'maxItems': 2})),
          isNotEmpty,
        );
        expect(
          contract.validate(
            ['a', 1],
            s({
              'type': 'array',
              'items': {'type': 'string'},
            }),
          ),
          isNotEmpty,
        );
        expect(contract.validate('no-uuid', s({'format': 'uuid'})), isNotEmpty);
        expect(
          contract.validate('2026-11-19', s({'format': 'date-time'})),
          isNotEmpty,
        );
        expect(
          contract.validate('sin-esquema', s({'format': 'uri'})),
          isNotEmpty,
        );
        expect(contract.validate('a@b', s({'format': 'email'})), isNotEmpty);
        expect(
          contract.validate(
            {'a': 1},
            s({
              'type': 'object',
              'required': ['b'],
            }),
          ),
          isNotEmpty,
        );
        expect(
          contract.validate(
            {'a': 1, 'x': 2},
            s({
              'type': 'object',
              'properties': {
                'a': {'type': 'integer'},
              },
              'additionalProperties': false,
            }),
          ),
          isNotEmpty,
        );
      },
    );

    test('oneOf exige exactamente una; anyOf al menos una; allOf todas', () {
      final oneOf = {
        'oneOf': [
          {'type': 'string'},
          {'type': 'null'},
        ],
      };
      expect(contract.validate('x', oneOf), isEmpty);
      expect(contract.validate(1, oneOf), isNotEmpty);
      expect(
        contract.validate(1, {
          'anyOf': [
            {'type': 'string'},
            {'type': 'integer'},
          ],
        }),
        isEmpty,
      );
      expect(
        contract.validate(true, {
          'anyOf': [
            {'type': 'string'},
            {'type': 'integer'},
          ],
        }),
        isNotEmpty,
      );
      expect(
        contract.validate(
          {'a': 1},
          {
            'allOf': [
              {
                'required': ['a'],
              },
              {
                'required': ['b'],
              },
            ],
          },
        ),
        isNotEmpty,
      );
    });

    test(
      'un esquema inexistente o una referencia externa fallan con claridad',
      () {
        expect(() => contract.schema('NoExiste'), throwsArgumentError);
        expect(
          () => contract.resolve({r'$ref': 'https://x/y.json'}),
          throwsUnsupportedError,
        );
      },
    );

    test('QG-M06 · el sintetizador produce ejemplos válidos para TODOS los esquemas', () {
      for (final name in contract.schemas.keys) {
        final example = contract.example(contract.schema(name));
        expect(
          contract.validate(example, contract.schema(name)),
          isEmpty,
          reason: name,
        );
      }
    });
  });

  group('Los fixtures del contrato alimentan al código de la app', () {
    test('AppConfig.valid.json → RemoteConfigDto → RemoteConfig', () {
      final data =
          (fixture('AppConfig.valid.json')! as Map<String, dynamic>)['data']
              as Map<String, dynamic>;
      final entity = RemoteConfigDto.fromJson(data).toEntity(platform: 'ios');
      expect(entity.checkoutEnabled, isTrue);
      expect(entity.btuCalculatorEnabled, isFalse);
      expect(entity.checkoutAllowedHosts, {'example.invalid'});
      expect(entity.returnPathPrefix, '/app/pedido');
      expect(entity.minSupportedVersion, '1.0.0');
      expect(entity.shippingNotice, 'Envío a todo Colombia.');
      expect(entity.warrantyNotice, 'Garantía de fábrica.');
      expect(entity.priceOnRequestNotice, 'Escríbenos por WhatsApp.');
    });

    test('Session.valid.json → SessionTokens', () {
      final tokens = SessionTokens.fromSessionJson(
        fixture('Session.valid.json'),
      );
      expect(tokens.accessToken, startsWith('ipra_'));
      expect(tokens.refreshToken, startsWith('iprr_'));
      expect(tokens.sessionId, isNotNull);
    });

    test('Session con prefijo erróneo es rechazada por el código', () {
      expect(
        () => SessionTokens.fromSessionJson(fixture('Session.bad-prefix.json')),
        throwsFormatException,
      );
    });

    test('Problem.* → Problem y mapeo a AppFailure', () {
      final p = Problem.tryParse(fixture('Problem.503.json'));
      expect(p!.code, 'upstream_unavailable');
      expect(p.retryAfter, 5);
      final v = Problem.tryParse(fixture('Problem.validation.json'));
      expect(v!.errors.single.field, 'email');
      expect(Problem.tryParse(fixture('Problem.no-code.json')), isNull);
    });
  });

  group('BFF simulado (shelf) con el cliente real', () {
    late HttpServer server;
    late Uri base;
    late ApiClient client;

    ApiClient newClient({List<Duration>? sleeps}) => ApiClient.build(
      config: AppConfig.fromMap({
        'environment': 'dev',
        'apiBaseUrl': base.toString(),
        'deepLinkHost': 'dev.invalid',
        'checkoutAllowedHosts': 'dev.invalid',
        'mediaHosts': 'dev.invalid',
        'supportWhatsApp': '573000000000',
      }),
      interceptors: (dio) => [
        AppHeadersInterceptor(
          appVersion: '1.0.0',
          platform: 'android',
          deviceId: () async => uuidV4(),
        ),
        RetryInterceptor(dio: dio, sleep: (d) async => sleeps?.add(d)),
        ErrorMappingInterceptor(),
      ],
    );

    setUpAll(() async {
      server = await startMockBff();
      base = Uri.parse('http://127.0.0.1:${server.port}/mobile/v1');
      client = newClient();
    });
    tearDownAll(() => server.close(force: true));

    test(
      'GET /config lo lee RemoteConfigRepository, guarda el ETag y recibe 304',
      () async {
        final cache = MemoryCacheStore();
        final repo = RemoteConfigRepository(
          client: client,
          cache: cache,
          platform: 'android',
        );
        final first = await repo.fetch();
        expect(first.isOk, isTrue, reason: '${first.failureOrNull}');
        final second = await repo.fetch();
        expect(second.isOk, isTrue);
        expect(
          second.valueOrNull,
          first.valueOrNull,
          reason: 'el 304 devuelve la caché',
        );
      },
    );

    test('CR-005 · /pqrs exige Idempotency-Key y valida el cuerpo contra el contrato', () async {
      final body = fixture('PqrsRequest.valid.json');
      // Sin clave: el simulado rechaza (el YAML la declara opcional; CR-005 manda).
      final raw = HttpClient();
      final req = await raw.postUrl(Uri.parse('$base/pqrs'));
      req.headers
        ..contentType = ContentType.json
        ..set('X-App-Version', '1.0.0')
        ..set('X-App-Platform', 'android');
      req.add(utf8.encode(jsonEncode(body)));
      final res = await req.close();
      expect(res.statusCode, 400);
      final problem = jsonDecode(
        await utf8.decoder.bind(res).join(),
      ) as Map<String, dynamic>;
      expect(problem['code'], 'validation_failed');
      raw.close();

      final ok = await client.send(
        ApiRequest.post(
          '/pqrs',
          body: body,
          requiresIdempotency: true,
          idempotencyKey: uuidV4(),
        ),
      );
      expect(ok.isOk, isTrue, reason: '${ok.failureOrNull}');

      final bad = await client.send(
        ApiRequest.post(
          '/pqrs',
          body: fixture('PqrsRequest.no-consent.json'),
          requiresIdempotency: true,
          idempotencyKey: uuidV4(),
        ),
      );
      expect(bad.failureOrNull, isA<Validation>());
    });

    test(
      'las rutas privadas exigen Bearer con la forma del contrato',
      () async {
        final without = await client.send(const ApiRequest.get('/me'));
        expect(without.failureOrNull, isA<Unauthorized>());
        final withToken = await client.send(
          ApiRequest.get('/me', headers: {'Authorization': bearer()}),
        );
        expect(withToken.isOk, isTrue, reason: '${withToken.failureOrNull}');
      },
    );

    test(
      'ApiSessionRemote.refresh contra el contrato devuelve tokens válidos',
      () async {
        final remote = ApiSessionRemote(client);
        final result = await remote.refresh('iprr_${'A' * 43}');
        expect(result.isOk, isTrue, reason: '${result.failureOrNull}');
        expect(result.valueOrNull!.accessToken, startsWith('ipra_'));
      },
    );

    test(
      'un refresh con forma inválida es rechazado por el contrato',
      () async {
        final result = await ApiSessionRemote(client)
            .refresh('no-es-un-refresh');
        expect(result.failureOrNull, isA<Validation>());
      },
    );

    test(
      'X-Mock-Scenario fuerza 404, 426, 429, 503 y el HTML del borde',
      () async {
        Future<AppFailure?> scenario(String s) async {
          final sleeps = <Duration>[];
          final r = await newClient(
            sleeps: sleeps,
          ).send(ApiRequest.get('/products', headers: {'X-Mock-Scenario': s}));
          return r.failureOrNull;
        }

        expect(await scenario('error:404'), isA<NotFound>());
        expect(await scenario('error:426'), isA<UpgradeRequired>());
        expect(await scenario('error:429'), isA<RateLimited>());
        expect(await scenario('error:503'), isA<ServiceUnavailable>());
        expect(await scenario('error:502'), isA<ServiceUnavailable>());
        expect(await scenario('error:504'), isA<ServiceUnavailable>());
        expect(await scenario('error:500'), isA<ServerFailure>());
        expect(await scenario('html403'), isA<BlockedByEdge>());
      },
    );

    test('una ruta inexistente es 404 (no un 200 vacío)', () async {
      final r = await client.send(const ApiRequest.get('/no-existe'));
      expect(r.failureOrNull, isA<NotFound>());
    });

    test('faltan cabeceras obligatorias: 400 con detalle por campo', () async {
      final raw = HttpClient();
      final req = await raw.getUrl(Uri.parse('$base/auth/refresh'));
      final res = await req.close();
      // GET no existe en esa ruta → 404; probamos POST sin cabeceras.
      expect(res.statusCode, 404);
      final post = await (await raw.postUrl(Uri.parse('$base/auth/refresh')))
          .close();
      expect(post.statusCode, 400);
      final body = jsonDecode(
        await utf8.decoder.bind(post).join(),
      ) as Map<String, dynamic>;
      final fields = (body['errors'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((e) => e['field']);
      expect(
        fields,
        containsAll(['X-App-Version', 'X-App-Platform', 'X-Device-Id']),
      );
      raw.close(force: true);
    });

    test('contrato ↔ simulado: toda ruta GET sin parámetros responde con su esquema', () async {
      var checked = 0;
      for (final entry in contract.paths.entries) {
        if (entry.key.contains('{')) continue;
        final get = (entry.value as Map<String, dynamic>)['get'];
        if (get is! Map<String, dynamic>) continue;
        final private = OpenApiContract.requiresAuth(get);
        final result = await client.send(
          ApiRequest.get(
            entry.key,
            headers: {if (private) 'Authorization': bearer()},
          ),
        );
        expect(
          result.isOk,
          isTrue,
          reason: '${entry.key}: ${result.failureOrNull}',
        );
        final responses = get['responses'] as Map<String, dynamic>;
        final okKey = responses.keys.firstWhere((k) => k == '200');
        final schema =
            ((contract.resolve(
                          responses[okKey] as Map<String, dynamic>,
                        )['content']
                        as Map<String, dynamic>)['application/json']
                    as Map<String, dynamic>)['schema']
                as Map<String, dynamic>;
        final data = (result as Ok<ApiResponse>).value.data;
        expect(contract.validate(data, schema), isEmpty, reason: entry.key);
        checked++;
      }
      expect(checked, greaterThan(5));
    });
  });
}
