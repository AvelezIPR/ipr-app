import 'package:ipr_mobile/app/router/routes.dart';

/// Resultado de evaluar un enlace entrante.
sealed class DeepLinkDecision {
  const new();
}

/// Enlace aceptado: navegar a [location].
final class DeepLinkAccepted extends DeepLinkDecision {
  const new(this.location);
  final String location;
}

/// Enlace rechazado: ir a Inicio. Nunca se muestra nada derivado del enlace.
final class DeepLinkRejected extends DeepLinkDecision {
  const new();
}

/// Política de entrada de enlaces profundos (SC-067, RNF-046).
///
/// * Solo `https` y **exclusivamente** el `deepLinkHost` del flavor.
/// * MVP: solo `/app/pedido` (CR-001). Nunca comodines.
/// * Los parámetros `order` y `status` son una **pista**: la verdad es la
///   consulta autenticada a `GET /checkout/{checkoutRef}` (CR-002); un pago
///   nunca se da por exitoso por lo que diga el enlace.
final class DeepLinkPolicy {
  const new({required this.allowedHost});

  /// Único host aceptado (en minúsculas).
  final String allowedHost;

  static const orderReturnPath = '/app/pedido';

  static final _orderNumber = RegExp(r'^\d{1,12}$');
  static const _knownStatuses = {
    'paid',
    'pending',
    'failed',
    'cancelled',
    'refunded',
    'processing',
    'completed',
    'on-hold',
    'unknown',
  };

  /// ¿Esta URI viene de fuera de la app (tiene host) o apunta al espacio de
  /// enlaces `/app/`?
  bool isDeepLink(Uri uri) =>
      uri.hasScheme || uri.host.isNotEmpty || uri.path.startsWith('/app');

  DeepLinkDecision decide(Uri uri) {
    if (uri.host.isNotEmpty || uri.hasScheme) {
      if (uri.scheme.toLowerCase() != 'https') return const DeepLinkRejected();
      if (uri.host.toLowerCase() != allowedHost) {
        return const DeepLinkRejected();
      }
      if (uri.userInfo.isNotEmpty || (uri.hasPort && uri.port != 443)) {
        return const DeepLinkRejected();
      }
    }
    final path = uri.path.length > 1 && uri.path.endsWith('/')
        ? uri.path.substring(0, uri.path.length - 1)
        : uri.path;
    if (path != orderReturnPath) return const DeepLinkRejected();

    final hints = <String, String>{};
    final order = uri.queryParameters['order'];
    if (order != null && _orderNumber.hasMatch(order)) hints['order'] = order;
    final status = uri.queryParameters['status'];
    if (status != null && _knownStatuses.contains(status)) {
      hints['status'] = status;
    }
    return DeepLinkAccepted(
      Uri(
        path: Routes.checkoutResult,
        queryParameters: hints.isEmpty ? null : hints,
      ).toString(),
    );
  }
}
