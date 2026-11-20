import 'package:meta/meta.dart';

/// Lo único que se guarda mientras el usuario paga: sirve para reanudar la
/// verificación si el sistema mata la app. **Sin PII** (ni ticket, ni URL, ni
/// importes, ni datos del usuario).
@immutable
final class PendingCheckout {
  const new({
    required this.checkoutRef,
    required this.attemptId,
    required this.startedAt,
  });

  final String checkoutRef;
  final String attemptId;
  final DateTime startedAt;

  @override
  bool operator ==(Object other) =>
      other is PendingCheckout &&
      other.checkoutRef == checkoutRef &&
      other.attemptId == attemptId &&
      other.startedAt == startedAt;

  @override
  int get hashCode => Object.hash(checkoutRef, attemptId, startedAt);

  @override
  String toString() => 'PendingCheckout($checkoutRef)';
}
