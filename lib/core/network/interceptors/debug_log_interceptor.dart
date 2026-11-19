import 'package:dio/dio.dart';
import 'package:ipr_mobile/core/network/api_request.dart';

/// Interceptor 5 (solo dev y staging; **no existe en prod**, SC-045).
///
/// Registra método, ruta (sin consulta: puede traer términos de búsqueda) y
/// estado. Jamás cabeceras de autenticación ni cuerpos.
final class DebugLogInterceptor extends Interceptor {
  new(this.sink);

  final void Function(String line) sink;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[ApiExtra.startedAt] = DateTime.now().millisecondsSinceEpoch;
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _log(response.requestOptions, response.statusCode);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _log(err.requestOptions, err.response?.statusCode, type: err.type.name);
    handler.next(err);
  }

  void _log(RequestOptions options, int? status, {String? type}) {
    final started = options.extra[ApiExtra.startedAt] as int?;
    final elapsed = started == null
        ? ''
        : ' ${DateTime.now().millisecondsSinceEpoch - started}ms';
    sink(
      '${options.method} ${options.uri.path} -> '
      '${status ?? type ?? '?'}$elapsed',
    );
  }
}
