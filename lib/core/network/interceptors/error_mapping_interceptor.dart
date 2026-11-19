import 'package:dio/dio.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/failure_mapper.dart';

/// Interceptor 4: convierte cualquier [DioException] en `AppFailure` y la
/// deja en `DioException.error`; `ApiClient` la desenvuelve (RNF-027).
final class ErrorMappingInterceptor extends Interceptor {
  new({this.onFailure});

  /// Observa cada fallo ya mapeado (p. ej. 426 → `/update-required`).
  final void Function(AppFailure failure)? onFailure;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final failure = mapDioException(err);
    onFailure?.call(failure);
    handler.next(err.copyWith(error: failure));
  }
}
