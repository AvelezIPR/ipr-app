import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Genera la respuesta (o lanza una [DioException]) para una petición.
typedef Responder = FutureOr<ResponseBody> Function(RequestOptions options);

/// Adaptador HTTP de prueba: cola de respuestas guionadas, sin red real.
final class FakeHttpAdapter implements HttpClientAdapter {
  new([Iterable<Responder> responders = const []]) {
    _queue.addAll(responders);
  }

  final List<RequestOptions> requests = [];
  final List<Responder> _queue = [];

  /// Respuesta cuando la cola está vacía (si es nula, falla la prueba).
  Responder? fallback;

  void enqueue(Responder responder) => _queue.add(responder);

  int get pending => _queue.length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    // Copia: Dio reutiliza el mismo RequestOptions al reintentar y mutaría
    // las cabeceras ya registradas.
    requests.add(options.copyWith(headers: {...options.headers}));
    final responder = _queue.isNotEmpty ? _queue.removeAt(0) : fallback;
    if (responder == null) {
      throw StateError(
        'Sin respuesta guionada para ${options.method} '
        '${options.path}',
      );
    }
    return await responder(options);
  }

  @override
  void close({bool force = false}) {}

  // ── Constructores de respuestas ────────────────────────────────────────

  static ResponseBody json(
    Object? body, {
    int status = 200,
    Map<String, List<String>> headers = const {},
  }) => ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
      ...headers,
    },
  );

  static ResponseBody problem(
    int status,
    String code, {
    Map<String, List<String>> headers = const {},
    List<Map<String, String>>? errors,
    int? retryAfter,
  }) => ResponseBody.fromString(
    jsonEncode({
      'type': 'https://iprpartesyrepuestos.com/problems/$code',
      'title': code,
      'status': status,
      'code': code,
      'requestId': '11111111-1111-4111-8111-111111111111',
      'retryAfter': ?retryAfter,
      'errors': ?errors,
    }),
    status,
    headers: {
      Headers.contentTypeHeader: ['application/problem+json'],
      ...headers,
    },
  );

  static ResponseBody html(int status, {Map<String, List<String>>? headers}) =>
      ResponseBody.fromString(
        '<html><body>Cloudflare</body></html>',
        status,
        headers: {
          Headers.contentTypeHeader: ['text/html'],
          ...?headers,
        },
      );

  static ResponseBody connectionError(RequestOptions options) =>
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'sin red (prueba)',
      );

  static ResponseBody timeout(RequestOptions options) => throw DioException(
    requestOptions: options,
    type: DioExceptionType.receiveTimeout,
  );
}
