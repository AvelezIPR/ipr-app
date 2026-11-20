import 'package:meta/meta.dart';

/// Resultado de revalidar el carrito contra el servidor (N-05, RF-050) justo
/// antes de pagar.
@immutable
final class CartReview {
  const new({
    required this.checkoutAllowed,
    this.hasChanges = false,
    this.hasUnavailable = false,
  });

  /// El servidor permite pagar este carrito (`checkoutAllowed`).
  final bool checkoutAllowed;

  /// Precio o cantidades distintos de lo que el usuario vio.
  final bool hasChanges;

  /// Hay productos agotados, sin precio o que ya no existen.
  final bool hasUnavailable;

  /// El usuario debe revisar el carrito antes de continuar.
  bool get needsAttention => hasChanges || hasUnavailable;

  @override
  bool operator ==(Object other) =>
      other is CartReview &&
      other.checkoutAllowed == checkoutAllowed &&
      other.hasChanges == hasChanges &&
      other.hasUnavailable == hasUnavailable;

  @override
  int get hashCode => Object.hash(checkoutAllowed, hasChanges, hasUnavailable);

  @override
  String toString() =>
      'CartReview(allowed: $checkoutAllowed, changes: $hasChanges, '
      'unavailable: $hasUnavailable)';
}
