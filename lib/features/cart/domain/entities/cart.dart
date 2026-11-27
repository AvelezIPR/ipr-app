import 'package:ipr_mobile/features/cart/domain/entities/cart_line.dart';
import 'package:ipr_mobile/shared/domain/quantity_range.dart';
import 'package:meta/meta.dart';

/// Límites del carrito (IR-04, RF-049; `src/lib/checkout-schema.ts`).
abstract final class CartLimits {
  static const minQuantity = 1;
  static const maxQuantity = 99;
  static const maxLines = 100;
}

/// Motivo por el que no se pudo añadir un producto.
enum CartRejection {
  /// `productId` no es un entero mayor que cero (IR-04).
  invalidProduct,

  /// Cantidad menor que 1: no se crea ninguna línea inválida (AC-029-3).
  invalidQuantity,

  /// Ya hay 100 líneas y el producto es nuevo (AC-049-3).
  lineLimit,

  /// La instantánea indica que no es comprable (sin precio o no "en stock":
  /// IR-02, CR-017).
  notPurchasable,
}

/// Resultado de añadir un producto.
sealed class CartAddResult {
  const new();
}

/// El producto quedó en el carrito.
final class CartAdded extends CartAddResult {
  const new(
    this.cart, {
    required this.quantity,
    required this.merged,
    required this.clamped,
    this.maxQuantity = CartLimits.maxQuantity,
  });

  final Cart cart;

  /// Cantidad final de esa línea.
  final int quantity;

  /// Ya existía: la cantidad se **sumó** (AC-029-5; sin líneas duplicadas).
  final bool merged;

  /// La cantidad pedida o la suma superó el máximo de la línea y se acotó
  /// (se informa al usuario).
  final bool clamped;

  /// Máximo por línea que se aplicó (el del producto o 99, W1-06).
  final int maxQuantity;
}

final class CartAddRejected extends CartAddResult {
  const new(this.reason);

  final CartRejection reason;
}

/// Carrito local: agregado inmutable que concentra las reglas de negocio.
///
/// * `productId` entero > 0, sin duplicados (IR-04).
/// * Cantidad 1–99 por producto; bajar de 1 **no** elimina la línea (solo la
///   acción explícita de quitar, AC-049-2).
/// * Máximo 100 líneas.
/// * Agregar un producto existente **suma** y se acota a 99 (regla de fusión
///   propuesta: AC-029-5 [A VALIDAR]; un único punto, [add]).
///
/// Las listas devueltas no se modifican: cada operación crea un carrito nuevo.
@immutable
final class Cart {
  const new(this.lines);

  /// Reconstruye un carrito desde datos externos (el almacén local) sin
  /// confiar en ellos: descarta ids inválidos y repetidos, lleva las
  /// cantidades a 1–99 (≤ 0 descarta la línea) y corta en 100 líneas.
  factory sanitize(Iterable<CartLine> raw) {
    final seen = <int>{};
    final lines = <CartLine>[];
    for (final line in raw) {
      if (lines.length >= CartLimits.maxLines) break;
      if (line.productId <= 0 || !seen.add(line.productId)) continue;
      if (line.quantity < CartLimits.minQuantity) continue;
      final next = line.quantityRange.clamp(line.quantity);
      lines.add(next == line.quantity ? line : line.copyWith(quantity: next));
    }
    return Cart(List.unmodifiable(lines));
  }

  static const empty = Cart([]);

  final List<CartLine> lines;

  bool get isEmpty => lines.isEmpty;
  int get lineCount => lines.length;

  /// Unidades totales (para la insignia de la pestaña).
  int get unitCount => lines.fold(0, (sum, line) => sum + line.quantity);

  bool get isFull => lines.length >= CartLimits.maxLines;

  CartLine? lineOf(int productId) {
    for (final line in lines) {
      if (line.productId == productId) return line;
    }
    return null;
  }

  /// Añade [quantity] unidades de [productId].
  CartAddResult add({
    required int productId,
    required int quantity,
    CartLineSnapshot? snapshot,
  }) {
    if (productId <= 0) {
      return const CartAddRejected(CartRejection.invalidProduct);
    }
    if (quantity < CartLimits.minQuantity) {
      return const CartAddRejected(CartRejection.invalidQuantity);
    }
    if (snapshot != null && !snapshot.isPurchasable) {
      return const CartAddRejected(CartRejection.notPurchasable);
    }

    final existing = lineOf(productId);
    // Los límites vigentes son los del producto que se acaba de ver; si no
    // viene instantánea, los que ya tenía la línea (W1-06).
    final range =
        snapshot?.quantityRange ??
        existing?.quantityRange ??
        QuantityRange.standard;
    if (existing != null) {
      final sum = existing.quantity + quantity;
      final next = range.clamp(sum);
      return CartAdded(
        Cart(
          List.unmodifiable([
            for (final line in lines)
              if (line.productId == productId)
                line.copyWith(quantity: next, snapshot: snapshot)
              else
                line,
          ]),
        ),
        quantity: next,
        merged: true,
        clamped: sum > range.max,
        maxQuantity: range.max,
      );
    }

    if (isFull) return const CartAddRejected(CartRejection.lineLimit);
    final next = range.clamp(quantity);
    return CartAdded(
      Cart(
        List.unmodifiable([
          ...lines,
          CartLine(productId: productId, quantity: next, snapshot: snapshot),
        ]),
      ),
      quantity: next,
      merged: false,
      clamped: quantity > range.max,
      maxQuantity: range.max,
    );
  }

  /// Fija la cantidad de una línea existente, llevada al rango de esa línea
  /// (1–99 o el del producto, W1-06). Un producto que no está en el carrito
  /// no se crea aquí.
  Cart setQuantity(int productId, int quantity) {
    final existing = lineOf(productId);
    if (existing == null) return this;
    final next = existing.quantityRange.clamp(quantity);
    if (next == existing.quantity) return this;
    return Cart(
      List.unmodifiable([
        for (final line in lines)
          if (line.productId == productId)
            line.copyWith(quantity: next)
          else
            line,
      ]),
    );
  }

  /// Quita la línea (acción explícita).
  Cart remove(int productId) => removeAll({productId});

  /// Quita varias líneas a la vez.
  Cart removeAll(Set<int> productIds) {
    if (!lines.any((line) => productIds.contains(line.productId))) return this;
    return Cart(
      List.unmodifiable([
        for (final line in lines)
          if (!productIds.contains(line.productId)) line,
      ]),
    );
  }

  /// Devuelve [line] a su posición ([index]) tras "Deshacer". Respeta las
  /// reglas: no duplica, no pasa de 100 líneas y acota la cantidad.
  Cart restore(CartLine line, int index) {
    if (line.productId <= 0 ||
        line.quantity < CartLimits.minQuantity ||
        lineOf(line.productId) != null ||
        isFull) {
      return this;
    }
    final clamped = line.quantityRange.clamp(line.quantity);
    final restored = clamped == line.quantity
        ? line
        : line.copyWith(quantity: clamped);
    final at = index.clamp(0, lines.length);
    return Cart(
      List.unmodifiable([...lines.take(at), restored, ...lines.skip(at)]),
    );
  }

  /// Sustituye las instantáneas de las líneas indicadas (tras una
  /// revalidación correcta, N-05).
  Cart withSnapshots(Map<int, CartLineSnapshot> snapshots) {
    if (snapshots.isEmpty) return this;
    return Cart(
      List.unmodifiable([
        for (final line in lines)
          if (snapshots[line.productId] case final snapshot?)
            // El servidor puede haber cambiado los límites desde que se añadió
            // (el carrito vive días en el teléfono): se recorta al vigente.
            line.copyWith(
              snapshot: snapshot,
              quantity: snapshot.quantityRange.clamp(line.quantity),
            )
          else
            line,
      ]),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Cart &&
      other.lines.length == lines.length &&
      Iterable<int>.generate(lines.length)
          .every((i) => other.lines[i] == lines[i]);

  @override
  int get hashCode => Object.hashAll(lines);
}
