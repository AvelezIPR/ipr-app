import 'package:dio/dio.dart';
import 'package:ipr_mobile/core/network/uuid_v4.dart';

/// Interceptor 1: cabeceras propias de la app. Nunca tokens ni PII, y nunca
/// nada en la URL (RNF-041).
final class AppHeadersInterceptor extends Interceptor {
  new({
    required this.appVersion,
    required this.platform,
    required this.deviceId,
    String Function()? requestId,
  }) : _requestId = requestId ?? uuidV4;

  final String appVersion;
  final String platform;
  final Future<String> Function() deviceId;
  final String Function() _requestId;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final id = await deviceId();
    options.headers
      ..['X-App-Version'] = appVersion
      ..['X-App-Platform'] = platform
      ..['X-Device-Id'] = id
      ..['Accept-Language'] = 'es-CO';
    // Se conserva el id de la petición original en los reintentos.
    options.headers.putIfAbsent('X-Request-Id', _requestId);
    handler.next(options);
  }
}
