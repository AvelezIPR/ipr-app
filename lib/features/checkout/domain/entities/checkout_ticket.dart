import 'package:meta/meta.dart';

/// Respuesta de `POST /checkout` (`CheckoutSession`).
///
/// [checkoutUrl] lleva el ticket de un solo uso en su consulta: **no se
/// guarda, no se registra y no sale en ningún `toString`** (SC-023). Solo vive
/// en una variable local entre recibirla y abrirla.
@immutable
final class CheckoutTicket {
  const new({
    required this.checkoutRef,
    required this.checkoutUrl,
    required this.allowedHosts,
    this.expiresAt,
  });

  /// UUID v4 que correlaciona el intento con el pedido.
  final String checkoutRef;
  final Uri checkoutUrl;

  /// Hosts que el servidor declara válidos (en minúsculas). La app los
  /// intersecta con su propia lista; nunca los amplía.
  final Set<String> allowedHosts;
  final DateTime? expiresAt;

  @override
  String toString() =>
      'CheckoutTicket(ref: $checkoutRef, checkoutUrl: <oculta>)';
}
