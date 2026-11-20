import 'package:meta/meta.dart';

/// Un intento de pago del usuario (`flutter_app_architecture.md` §11).
///
/// [idempotencyKey] es un UUID v4 generado **una sola vez** por intento: se
/// reutiliza si se reintenta ESE intento (la petición es idempotente en el
/// BFF) y un intento nuevo del usuario genera otra (CR-005, SC-027).
@immutable
final class CheckoutAttempt {
  const new({
    required this.id,
    required this.idempotencyKey,
    required this.createdAt,
  });

  final String id;
  final String idempotencyKey;
  final DateTime createdAt;

  @override
  bool operator ==(Object other) =>
      other is CheckoutAttempt &&
      other.id == id &&
      other.idempotencyKey == idempotencyKey &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, idempotencyKey, createdAt);

  /// La clave de idempotencia no se imprime (no es secreta, pero no hay por
  /// qué volcarla a los registros).
  @override
  String toString() => 'CheckoutAttempt($id)';
}
