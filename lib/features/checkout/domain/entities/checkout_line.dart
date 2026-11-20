import 'package:meta/meta.dart';

/// Línea del carrito tal como la ve el checkout (solo lectura).
///
/// Al BFF solo viajan [productId] y [quantity] (`{id, quantity}`, SC-020);
/// [name] es únicamente para mostrar el resumen y **nunca** se envía.
@immutable
final class CheckoutLine {
  const new({required this.productId, required this.quantity, this.name});

  final int productId;
  final int quantity;

  /// Nombre para el resumen; puede faltar si el carrito aún no se validó.
  final String? name;

  /// Dos líneas son la misma petición si coinciden producto y cantidad (el
  /// nombre es solo de presentación).
  @override
  bool operator ==(Object other) =>
      other is CheckoutLine &&
      other.productId == productId &&
      other.quantity == quantity;

  @override
  int get hashCode => Object.hash(productId, quantity);

  @override
  String toString() => 'CheckoutLine($productId x$quantity)';
}

/// ¿Las dos listas describen exactamente la misma petición (orden incluido)?
bool sameCheckoutLines(List<CheckoutLine> a, List<CheckoutLine> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
