/// Descripción de una petición al BFF `/mobile/v1`.
final class ApiRequest {
  const new({
    required this.method,
    required this.path,
    this.query,
    this.body,
    this.requiresAuth = false,
    this.idempotencyKey,
    this.requiresIdempotency = false,
    this.receiveTimeout,
    this.headers,
  });

  const new get(
    String path, {
    Map<String, Object?>? query,
    bool requiresAuth = false,
    Duration? receiveTimeout,
    Map<String, String>? headers,
  }) : this(
         method: 'GET',
         path: path,
         query: query,
         requiresAuth: requiresAuth,
         receiveTimeout: receiveTimeout,
         headers: headers,
       );

  /// POST. Si [requiresIdempotency] es verdadero, [idempotencyKey] es
  /// obligatoria (CR-005): `POST /checkout`, `/me/deletion` y `/pqrs`.
  const new post(
    String path, {
    Object? body,
    bool requiresAuth = false,
    String? idempotencyKey,
    bool requiresIdempotency = false,
    Duration? receiveTimeout,
    Map<String, String>? headers,
  }) : this(
         method: 'POST',
         path: path,
         body: body,
         requiresAuth: requiresAuth,
         idempotencyKey: idempotencyKey,
         requiresIdempotency: requiresIdempotency,
         receiveTimeout: receiveTimeout,
         headers: headers,
       );

  final String method;
  final String path;
  final Map<String, Object?>? query;
  final Object? body;

  /// Si es verdadero, `AuthInterceptor` adjunta `Authorization: Bearer`.
  final bool requiresAuth;
  final String? idempotencyKey;
  final bool requiresIdempotency;

  /// Sustituye el tiempo de recepción por defecto (checkout 20 s, PQRS 15 s).
  final Duration? receiveTimeout;
  final Map<String, String>? headers;
}

/// Respuesta ya validada (2xx o 304) del BFF.
final class ApiResponse {
  const new({
    required this.statusCode,
    required this.data,
    required this.headers,
  });

  final int statusCode;
  final Object? data;
  final Map<String, List<String>> headers;

  bool get notModified => statusCode == 304;

  String? header(String name) {
    final values = headers[name.toLowerCase()];
    return (values == null || values.isEmpty) ? null : values.first;
  }

  /// El servidor sirvió datos obsoletos (`X-IPR-Data-State: stale`).
  bool get isStale => header('x-ipr-data-state') == 'stale';

  String? get etag => header('etag');
}

/// Tiempos de espera acordados en CR-014.
abstract final class ApiTimeouts {
  static const connect = Duration(seconds: 10);
  static const receive = Duration(seconds: 15);
  static const checkout = Duration(seconds: 20);
  static const pqrs = Duration(seconds: 15);
}

/// Claves de `RequestOptions.extra` usadas entre interceptores.
abstract final class ApiExtra {
  static const requiresAuth = 'ipr.requiresAuth';
  static const authRetried = 'ipr.authRetried';
  static const retryCount = 'ipr.retryCount';
  static const startedAt = 'ipr.startedAt';
}
