import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/failure_mapper.dart';
import 'package:ipr_mobile/core/network/problem.dart';

Map<String, dynamic> problemJson(
  String code, {
  int status = 400,
  Object? extra,
}) => {
  'type': 'https://x/$code',
  'title': code,
  'status': status,
  'code': code,
  'requestId': '11111111-1111-4111-8111-111111111111',
  if (extra is Map<String, dynamic>) ...extra,
};

void main() {
  group('TC-104 · RNF-022 · mapeo por Problem.code y estado HTTP', () {
    test('404 con Problem es NotFound (el recurso de verdad no existe)', () {
      final f = mapErrorResponse(
        status: 404,
        body: problemJson('not_found', status: 404),
      );
      expect(f, isA<NotFound>());
      expect(f.retryable, isFalse);
    });

    test(
      '503, 502 y 504 son ServiceUnavailable reintentable, nunca NotFound',
      () {
        for (final status in [502, 503, 504]) {
          final f = mapErrorResponse(
            status: status,
            body: problemJson('upstream_unavailable', status: status),
          );
          expect(f, isA<ServiceUnavailable>(), reason: '$status');
          expect(f.retryable, isTrue);
        }
      },
    );

    test('503 propaga retryAfter del Problem y de la cabecera', () {
      final fromProblem = mapErrorResponse(
        status: 503,
        body: problemJson(
          'catalog_index_warming',
          status: 503,
          extra: {'retryAfter': 7},
        ),
      );
      expect(fromProblem.retryAfterSeconds, 7);
      final fromHeader = mapErrorResponse(
        status: 503,
        body: problemJson('upstream_unavailable', status: 503),
        headers: {
          'retry-after': ['12'],
        },
      );
      expect(fromHeader.retryAfterSeconds, 12);
    });

    test('429 es RateLimited con retryAfter', () {
      final f = mapErrorResponse(
        status: 429,
        body: problemJson(
          'rate_limited',
          status: 429,
          extra: {'retryAfter': 30},
        ),
      );
      expect(f, isA<RateLimited>());
      expect(f.retryAfterSeconds, 30);
    });

    test('400 validation_failed lleva el detalle por campo (nunca 422)', () {
      final f = mapErrorResponse(
        status: 400,
        body: problemJson(
          'validation_failed',
          extra: {
            'errors': [
              {
                'field': 'email',
                'code': 'invalid',
                'message': 'Correo inválido',
              },
            ],
          },
        ),
      );
      expect(f, isA<Validation>());
      final fields = (f as Validation).fields;
      expect(fields.single.field, 'email');
      expect(fields.single.message, 'Correo inválido');
    });

    test(
      '403 current_password_invalid es validación del campo currentPassword',
      () {
        final f = mapErrorResponse(
          status: 403,
          body: problemJson('current_password_invalid', status: 403),
        );
        expect(f, isA<Validation>());
        expect((f as Validation).fields.single.field, 'currentPassword');
      },
    );

    test('403 account_locked es Forbidden con su código', () {
      final f = mapErrorResponse(
        status: 403,
        body: problemJson('account_locked', status: 403),
      );
      expect(f, isA<Forbidden>());
      expect((f as Forbidden).code, 'account_locked');
    });

    test('401 distingue invalid_credentials de refresh_token_reused', () {
      final bad = mapErrorResponse(
        status: 401,
        body: problemJson('invalid_credentials', status: 401),
      );
      expect((bad as Unauthorized).code, 'invalid_credentials');
      final reused = mapErrorResponse(
        status: 401,
        body: problemJson('refresh_token_reused', status: 401),
      );
      expect((reused as Unauthorized).code, 'refresh_token_reused');
    });

    test('409 conserva el código (email_in_use, refresh_in_progress...)', () {
      for (final code in [
        'email_in_use',
        'idempotency_conflict',
        'refresh_in_progress',
      ]) {
        final f = mapErrorResponse(
          status: 409,
          body: problemJson(code, status: 409),
        );
        expect((f as Conflict).code, code);
      }
    });

    test('426 es UpgradeRequired', () {
      final f = mapErrorResponse(
        status: 426,
        body: problemJson('app_version_unsupported', status: 426),
      );
      expect(f, isA<UpgradeRequired>());
    });

    test(
      'token_in_url_forbidden es un error de contrato (fallo del cliente)',
      () {
        final f = mapErrorResponse(
          status: 400,
          body: problemJson('token_in_url_forbidden'),
        );
        expect(f, isA<ContractFailure>());
      },
    );

    test('500 con Problem es ServerFailure', () {
      final f = mapErrorResponse(
        status: 500,
        body: problemJson('internal_error', status: 500),
      );
      expect(f, isA<ServerFailure>());
    });

    test('un 4xx sin mapeo propio es UnknownFailure', () {
      final f = mapErrorResponse(
        status: 418,
        body: problemJson('teapot', status: 418),
      );
      expect(f, isA<UnknownFailure>());
    });
  });

  group('Respuestas que no son Problem JSON (borde / proxy)', () {
    test('403 con HTML es BlockedByEdge', () {
      expect(
        mapErrorResponse(status: 403, body: '<html></html>'),
        isA<BlockedByEdge>(),
      );
    });

    test('502 con HTML es ServiceUnavailable, no un fallo de contrato', () {
      expect(
        mapErrorResponse(status: 502, body: '<html></html>'),
        isA<ServiceUnavailable>(),
      );
    });

    test('estados sin Problem', () {
      expect(mapErrorResponse(status: 401), isA<Unauthorized>());
      expect(mapErrorResponse(status: 404), isA<NotFound>());
      expect(
        mapErrorResponse(
          status: 429,
          headers: {
            'retry-after': ['5'],
          },
        ).retryAfterSeconds,
        5,
      );
      expect(mapErrorResponse(status: 500), isA<ServerFailure>());
      expect(mapErrorResponse(status: 418), isA<UnknownFailure>());
    });
  });

  group('mapDioException', () {
    final options = RequestOptions(path: '/x');

    test('tiempos agotados son RequestTimeout', () {
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.transformTimeout,
      ]) {
        expect(
          mapDioException(DioException(requestOptions: options, type: type)),
          isA<RequestTimeout>(),
          reason: type.name,
        );
      }
    });

    test('error de conexión y certificado inválido son NoConnection', () {
      expect(
        mapDioException(
          DioException.connectionError(requestOptions: options, reason: 'x'),
        ),
        isA<NoConnection>(),
      );
      expect(
        mapDioException(DioException.badCertificate(requestOptions: options)),
        isA<NoConnection>(),
      );
    });

    test('badResponse delega en el mapeo de respuestas', () {
      final response = Response<Object?>(
        requestOptions: options,
        statusCode: 404,
        data: problemJson('not_found', status: 404),
      );
      expect(
        mapDioException(
          DioException.badResponse(
            statusCode: 404,
            requestOptions: options,
            response: response,
          ),
        ),
        isA<NotFound>(),
      );
    });

    test('FormatException es ContractFailure; otro error desconocido, NoConnection', () {
      expect(
        mapDioException(
          DioException(
            requestOptions: options,
            error: const FormatException('x'),
          ),
        ),
        isA<ContractFailure>(),
      );
      expect(
        mapDioException(DioException(requestOptions: options)),
        isA<NoConnection>(),
      );
    });

    test('cancelar no es un fallo de red', () {
      expect(
        mapDioException(
          DioException.requestCancelled(requestOptions: options, reason: 'x'),
        ),
        isA<UnknownFailure>(),
      );
    });

    test('un AppFailure ya mapeado se conserva', () {
      const failure = NotFound();
      expect(
        mapDioException(DioException(requestOptions: options, error: failure)),
        same(failure),
      );
    });
  });

  group('parseRetryAfter y Problem', () {
    test('solo acepta segundos enteros no negativos', () {
      expect(
        parseRetryAfter({
          'retry-after': ['9'],
        }),
        9,
      );
      expect(
        parseRetryAfter({
          'retry-after': [' 9 '],
        }),
        9,
      );
      expect(
        parseRetryAfter({
          'retry-after': ['-1'],
        }),
        isNull,
      );
      expect(
        parseRetryAfter({
          'retry-after': ['Wed, 21 Oct'],
        }),
        isNull,
      );
      expect(parseRetryAfter({}), isNull);
      expect(parseRetryAfter(null), isNull);
      expect(parseRetryAfter({'retry-after': <String>[]}), isNull);
    });

    test('Problem.tryParse exige objeto con code', () {
      expect(Problem.tryParse('texto'), isNull);
      expect(Problem.tryParse({'status': 400}), isNull);
      expect(Problem.tryParse({'code': ''}), isNull);
      final p = Problem.tryParse({
        'code': 'x',
        'errors': [
          1,
          {'field': 'a'},
        ],
      }, fallbackStatus: 400);
      expect(p!.status, 400);
      expect(p.errors.single.field, 'a');
    });
  });

  test('FieldError y fallos tienen representación sin datos sensibles', () {
    expect(
      const FieldError(field: 'a', code: 'b', message: 'secreto').toString(),
      isNot(contains('secreto')),
    );
    for (final f in <AppFailure>[
      const NoConnection(),
      const RequestTimeout(),
      const NotFound(),
      const ServiceUnavailable(),
      const RateLimited(),
      const Unauthorized(),
      const Forbidden(),
      const BlockedByEdge(),
      const Validation(),
      const Conflict(code: 'x'),
      const UpgradeRequired(),
      const ServerFailure(),
      const ContractFailure(),
      const UnknownFailure(),
    ]) {
      expect(f.message, isA<FailureMessage>());
      expect(f.retryable, isA<bool>());
    }
  });
}
