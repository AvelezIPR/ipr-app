import 'package:dio/dio.dart';
import 'package:ipr_mobile/core/network/api_request.dart';
import 'package:ipr_mobile/core/session/session_gateway.dart';

/// Interceptor 2: adjunta `Authorization: Bearer` **solo** a rutas privadas y
/// resuelve los 401 con un único refresh en vuelo (ADR-006, CR-020, CR-024).
///
/// * Tras un refresh exitoso reintenta la petición original una vez.
/// * Si el refresh falla por red o 5xx, el llamador recibe un fallo de
///   conexión (no "sesión vencida") y la sesión **no** se borra.
/// * Ante `401` definitivo (`unauthorized`, `refresh_token_reused`) la sesión
///   se limpia de inmediato y el carrito se conserva.
final class AuthInterceptor extends Interceptor {
  new({required this.gateway, required this.dio});

  final SessionGateway gateway;
  final Dio dio;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[ApiExtra.requiresAuth] != true) {
      handler.next(options);
      return;
    }
    var token = gateway.accessToken;
    if (token == null && await gateway.hasRefreshToken()) {
      // Reinicio de la app: hay refresh pero no access en memoria.
      if (await gateway.refresh() == RefreshOutcome.refreshed) {
        token = gateway.accessToken;
      }
    }
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final is401 = err.response?.statusCode == 401;
    if (!is401 || options.extra[ApiExtra.requiresAuth] != true) {
      handler.next(err);
      return;
    }
    if (options.extra[ApiExtra.authRetried] == true) {
      // Segundo 401 con un access recién renovado: la sesión no es válida.
      await gateway.expire();
      handler.next(err);
      return;
    }

    final outcome = await gateway.refresh();
    switch (outcome) {
      case RefreshOutcome.refreshed:
        options.extra[ApiExtra.authRetried] = true;
        options.headers['Authorization'] = 'Bearer ${gateway.accessToken}';
        try {
          handler.resolve(await dio.fetch<Object?>(options));
        } on DioException catch (e) {
          handler.next(e);
        }
      case RefreshOutcome.expired:
        handler.next(err);
      case RefreshOutcome.transientFailure:
        handler.next(
          DioException.connectionError(
            requestOptions: options,
            reason: 'No se pudo renovar la sesión por un fallo transitorio',
          ),
        );
    }
  }
}
