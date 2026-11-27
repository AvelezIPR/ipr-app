import 'package:ipr_mobile/features/cart/domain/entities/cart.dart';
import 'package:ipr_mobile/features/cart/domain/entities/cart_line.dart';
import 'package:ipr_mobile/features/cart/domain/entities/cart_overview.dart';
import 'package:ipr_mobile/features/cart/domain/entities/cart_validation.dart';

/// Resultado de aplicar una revalidación exitosa al carrito.
final class CartReconciliation {
  const new({required this.cart, required this.changes});

  /// Carrito con las instantáneas reemplazadas por lo que dijo el servidor.
  final Cart cart;

  /// Cambios por informar al usuario (id → cambio), acumulados con los que ya
  /// estaban pendientes.
  final Map<int, CartLineChange> changes;
}

/// Aplica [validation] al [cart] (N-05, RF-050).
///
/// * La instantánea de cada línea se **reemplaza** por el producto vigente del
///   servidor; las líneas que el servidor no pudo resolver (`product == null`)
///   conservan la suya y no se borran.
/// * Se informa de un cambio si el precio o la disponibilidad difieren de lo
///   que el usuario vio. La referencia es el valor **previo al primer
///   aviso**: un cambio que sigue sin aceptarse no desaparece en la
///   siguiente revalidación (p. ej. la previa al pago), y uno que revierte al
///   valor original se descarta.
/// * Las líneas sin instantánea previa no generan aviso (no hay con qué
///   comparar).
/// * Cantidades: mandan las locales, pero [Cart.withSnapshots] las acota al
///   rango vigente del servidor (recorta al nuevo `maxQuantity` o eleva al
///   `minQuantity` si los límites del producto cambiaron).
CartReconciliation reconcileCart({
  required Cart cart,
  required CartValidation validation,
  Map<int, CartLineChange> pending = const {},
}) {
  final snapshots = <int, CartLineSnapshot>{};
  final changes = <int, CartLineChange>{};

  for (final line in cart.lines) {
    final product = validation.lineFor(line.productId)?.product;
    if (product == null) {
      // Sin datos nuevos: se conserva lo guardado y lo pendiente.
      final kept = pending[line.productId];
      if (kept != null) changes[line.productId] = kept;
      continue;
    }

    final fresh = CartLineSnapshot.fromProduct(product);
    snapshots[line.productId] = fresh;

    final before = pending[line.productId];
    final previousPrice = before?.previousPrice ?? line.snapshot?.price;
    final previousAvailability =
        before?.previousAvailability ?? line.snapshot?.availability;
    if (previousPrice == null && previousAvailability == null) continue;

    final change = CartLineChange(
      productId: line.productId,
      previousPrice: previousPrice,
      currentPrice: fresh.price,
      previousAvailability: previousAvailability,
      currentAvailability: fresh.availability,
    );
    if (change.hasChange) changes[line.productId] = change;
  }

  return CartReconciliation(
    cart: cart.withSnapshots(snapshots),
    changes: changes,
  );
}
