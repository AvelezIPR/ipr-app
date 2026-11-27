import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import '../contract/openapi_contract.dart';
import 'demo_data.dart';

/// BFF simulado de `/mobile/v1` generado a partir de `contract/openapi.yaml`.
///
/// * Responde con ejemplos sintetizados del propio contrato.
/// * Aplica las reglas de **CR** (no las del YAML cuando difieren):
///   `Idempotency-Key` OBLIGATORIA en checkout, eliminación de cuenta y PQRS
///   (CR-005); `X-Device-Id` en rutas privadas (CR-021).
/// * Escenarios forzados con la cabecera `X-Mock-Scenario`:
///   `error:404|429|503|502|504|426|500`, `html403` (borde de Cloudflare).
///
/// * Con [demo] = `true`, categorías, marcas, productos, búsqueda, sedes y la
///   ficha de producto responden con datos de demostración parecidos a los
///   reales (`demo_data.dart`), validados contra el contrato. Por defecto
///   está apagado: las pruebas siguen usando los ejemplos del contrato.
///
/// No es el servidor real: sirve para desarrollo, pruebas de integración
/// ligeras y comprobar que el cliente cumple el contrato.
Future<HttpServer> startMockBff({
  int port = 0,
  String contractPath = 'contract/openapi.yaml',
  InternetAddress? address,
  bool demo = false,
}) async {
  final contract = OpenApiContract.load(contractPath);
  final routes = _buildRoutes(contract);
  Future<Response> handler(Request request) =>
      _handle(contract, routes, request, demo: demo);
  final server = await shelf_io.serve(
    const Pipeline().addMiddleware(_cors).addHandler(handler),
    address ?? InternetAddress.loopbackIPv4,
    port,
  );
  return server;
}

/// CORS abierto: el servidor solo escucha en loopback y existe para que la
/// previsualización en Chrome (`tool/preview/main.dart`) pueda llamarlo.
Handler _cors(Handler inner) {
  const headers = {
    'access-control-allow-origin': '*',
    'access-control-allow-methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
    'access-control-allow-headers': '*',
    'access-control-expose-headers': '*',
  };
  return (request) async {
    if (request.method == 'OPTIONS') {
      return Response(204, headers: headers);
    }
    final response = await inner(request);
    return response.change(headers: headers);
  };
}

const _etag = '"mock-config-v1"';

final class _Route {
  new(this.method, this.template, this.operation) {
    final pattern = template.splitMapJoin(
      RegExp(r'\{[^}]+\}'),
      onMatch: (_) => '[^/]+',
      onNonMatch: RegExp.escape,
    );
    regex = RegExp('^$pattern\$');
  }

  final String method;
  final String template;
  final Map<String, dynamic> operation;
  late final RegExp regex;
}

List<_Route> _buildRoutes(OpenApiContract contract) {
  final routes = <_Route>[];
  for (final entry in contract.paths.entries) {
    final item = entry.value as Map<String, dynamic>;
    for (final method in ['get', 'post', 'put', 'patch', 'delete']) {
      final op = item[method];
      if (op is Map<String, dynamic>) {
        routes.add(_Route(method.toUpperCase(), entry.key, op));
      }
    }
  }
  return routes;
}

Future<Response> _handle(
  OpenApiContract contract,
  List<_Route> routes,
  Request request, {
  required bool demo,
}) async {
  // El contrato lleva la ruta relativa a /mobile/v1.
  final path = '/${request.url.path}'.replaceFirst(RegExp('^/mobile/v1'), '');
  final requestId =
      request.headers['x-request-id'] ?? '11111111-1111-4111-8111-111111111111';
  Response problem(
    int status,
    String code, {
    int? retryAfter,
    List<Map<String, String>>? errors,
  }) =>
      _problem(status, code, requestId, retryAfter: retryAfter, errors: errors);

  final scenario = request.headers['x-mock-scenario'];
  if (scenario != null) {
    if (scenario == 'html403') {
      return Response(
        403,
        body: '<html><body>Cloudflare</body></html>',
        headers: {'content-type': 'text/html'},
      );
    }
    if (scenario.startsWith('error:')) {
      final status = int.tryParse(scenario.substring(6)) ?? 500;
      final code = switch (status) {
        404 => 'not_found',
        426 => 'app_version_unsupported',
        429 => 'rate_limited',
        502 => 'upstream_bad_response',
        503 => 'upstream_unavailable',
        504 => 'upstream_timeout',
        _ => 'internal_error',
      };
      return problem(
        status,
        code,
        retryAfter: (status == 429 || status == 503) ? 1 : null,
      );
    }
  }

  final route = routes
      .where((r) => r.method == request.method && r.regex.hasMatch(path))
      .firstOrNull;
  if (route == null) return problem(404, 'not_found');

  // Cabeceras obligatorias del contrato (X-App-Version, X-App-Platform, X-Device-Id...).
  final missing = <Map<String, String>>[];
  for (final raw
      in (route.operation['parameters'] as List<dynamic>? ?? const [])) {
    final param = contract.resolve(raw as Map<String, dynamic>);
    if (param['in'] == 'header' && param['required'] == true) {
      final name = param['name'] as String;
      if (request.headers[name.toLowerCase()] == null) {
        missing.add({
          'field': name,
          'code': 'required',
          'message': 'Falta la cabecera $name',
        });
      }
    }
  }
  // CR-005: Idempotency-Key OBLIGATORIA donde el contrato la declara.
  final declaresIdempotency =
      (route.operation['parameters'] as List<dynamic>? ?? const [])
          .map((p) => contract.resolve(p as Map<String, dynamic>))
          .any((p) => p['name'] == 'Idempotency-Key');
  if (declaresIdempotency && request.headers['idempotency-key'] == null) {
    missing.add({
      'field': 'Idempotency-Key',
      'code': 'required',
      'message': 'Idempotency-Key es obligatoria (CR-005)',
    });
  }
  if (missing.isNotEmpty) {
    return problem(400, 'validation_failed', errors: missing);
  }

  // Rutas privadas.
  if (OpenApiContract.requiresAuth(route.operation)) {
    final auth = request.headers['authorization'] ?? '';
    if (!RegExp(r'^Bearer ipra_[A-Za-z0-9_-]{43}$').hasMatch(auth)) {
      return problem(401, 'unauthorized');
    }
  }

  // Cuerpo: se valida contra el esquema del contrato.
  final body = route.operation['requestBody'];
  if (body is Map<String, dynamic> && body['required'] == true) {
    final text = await request.readAsString();
    Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      return problem(400, 'validation_failed');
    }
    final schema =
        ((body['content'] as Map<String, dynamic>)['application/json']
                as Map<String, dynamic>)['schema']
            as Map<String, dynamic>;
    final errors = contract.validate(json, schema);
    if (errors.isNotEmpty) {
      return problem(
        400,
        'validation_failed',
        errors: [
          for (final e in errors)
            {'field': 'body', 'code': 'invalid', 'message': e},
        ],
      );
    }
  }

  // ETag de /config (304 con If-None-Match).
  if (route.template == '/config' &&
      request.headers['if-none-match'] == _etag) {
    return Response(304, headers: {'etag': _etag});
  }

  final responses = route.operation['responses'] as Map<String, dynamic>;
  final successKey = responses.keys.firstWhere(
    (k) => k.startsWith('2'),
    orElse: () => '200',
  );
  final success = contract.resolve(
    responses[successKey] as Map<String, dynamic>,
  );
  final status = int.tryParse(successKey) ?? 200;
  final headers = <String, String>{'x-request-id': requestId};
  if (route.template == '/config') headers['etag'] = _etag;
  final content = success['content'] as Map<String, dynamic>?;
  if (content == null || status == 204) {
    return Response(status, headers: headers);
  }
  final schema =
      (content['application/json'] as Map<String, dynamic>)['schema']
          as Map<String, dynamic>;
  headers['content-type'] = 'application/json';
  var payload = contract.example(schema);
  if (demo) {
    final demoJson = demoBody(
      template: route.template,
      path: path,
      query: request.url.queryParameters,
      example: payload,
    );
    if (demoJson != null) {
      final errors = contract.validate(demoJson, schema);
      if (errors.isNotEmpty) {
        // Los datos de demostración deben cumplir el contrato: si no, se ve.
        stderr.writeln('demo inválido en ${route.template}: $errors');
        return problem(500, 'internal_error');
      }
      payload = demoJson;
    } else if (route.template == '/products/{slug}' ||
        route.template == '/brands/{slug}') {
      return problem(404, 'not_found');
    }
  }
  return Response(status, body: jsonEncode(payload), headers: headers);
}

Response _problem(
  int status,
  String code,
  String requestId, {
  int? retryAfter,
  List<Map<String, String>>? errors,
}) => Response(
  status,
  headers: {
    'content-type': 'application/problem+json',
    'retry-after': ?(retryAfter == null ? null : '$retryAfter'),
  },
  body: jsonEncode({
    'type': 'https://iprpartesyrepuestos.com/problems/$code',
    'title': code,
    'status': status,
    'code': code,
    'requestId': requestId,
    'retryAfter': ?retryAfter,
    'errors': ?errors,
  }),
);
