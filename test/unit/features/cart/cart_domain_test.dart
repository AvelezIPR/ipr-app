import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/features/cart/domain/entities/cart.dart';
import 'package:ipr_mobile/features/cart/domain/entities/cart_line.dart';
import 'package:ipr_mobile/shared/domain/money.dart';
import 'package:ipr_mobile/shared/domain/price_status.dart';
import 'package:ipr_mobile/shared/domain/stock_status.dart';

import 'cart_test_support.dart';

Cart _cartOf(int lines, {int quantity = 1}) => Cart([
  for (var i = 1; i <= lines; i++) CartLine(productId: i, quantity: quantity),
]);

CartAdded _added(CartAddResult result) {
  expect(result, isA<CartAdded>());
  return result as CartAdded;
}

void main() {
  group('TC-037 · AC-029-2/AC-029-3/AC-049-2 · límites de cantidad 1–99', () {
    test('un producto nuevo entra con la cantidad pedida', () {
      final result = _added(Cart.empty.add(productId: 7, quantity: 3));
      expect(result.cart.lines.single.quantity, 3);
      expect(result.merged, isFalse);
      expect(result.clamped, isFalse);
      expect(result.quantity, 3);
    });

    test('cantidades válidas de borde (1 y 99) se aceptan tal cual', () {
      expect(
        _added(Cart.empty.add(productId: 1, quantity: 1))
            .cart
            .lines
            .single
            .quantity,
        1,
      );
      final top = _added(Cart.empty.add(productId: 1, quantity: 99));
      expect(top.cart.lines.single.quantity, 99);
      expect(top.clamped, isFalse);
    });

    for (final quantity in [0, -1, -99]) {
      test('añadir $quantity se rechaza y no crea ninguna línea', () {
        final result = Cart.empty.add(productId: 1, quantity: quantity);
        expect(result, isA<CartAddRejected>());
        expect(
          (result as CartAddRejected).reason,
          CartRejection.invalidQuantity,
        );
      });
    }

    for (final quantity in [100, 150, 100000]) {
      test('añadir $quantity se acota a 99 y lo informa', () {
        final result = _added(Cart.empty.add(productId: 1, quantity: quantity));
        expect(result.cart.lines.single.quantity, 99);
        expect(result.clamped, isTrue);
      });
    }

    test('cambiar la cantidad: nunca baja de 1 ni sube de 99', () {
      const cart = Cart([CartLine(productId: 1, quantity: 1)]);
      expect(cart.setQuantity(1, 0).lines.single.quantity, 1);
      expect(cart.setQuantity(1, -5).lines.single.quantity, 1);
      expect(cart.setQuantity(1, 100).lines.single.quantity, 99);
      expect(cart.setQuantity(1, 99).lines.single.quantity, 99);
      expect(cart.setQuantity(1, 50).lines.single.quantity, 50);
    });

    test(
      'AC-049-2 · bajar a 0 no elimina la línea; solo quitar la elimina',
      () {
        const cart = Cart([CartLine(productId: 1, quantity: 1)]);
        expect(cart.setQuantity(1, 0).lines, hasLength(1));
        expect(cart.remove(1).isEmpty, isTrue);
      },
    );

    test('cambiar la cantidad de un producto ausente no crea la línea', () {
      const cart = Cart([CartLine(productId: 1, quantity: 2)]);
      expect(identical(cart.setQuantity(9, 4), cart), isTrue);
    });

    test('mismo valor: devuelve el mismo carrito', () {
      const cart = Cart([CartLine(productId: 1, quantity: 2)]);
      expect(identical(cart.setQuantity(1, 2), cart), isTrue);
    });

    for (final id in [0, -1, -42]) {
      test('IR-04 · productId $id no es un id válido', () {
        final result = Cart.empty.add(productId: id, quantity: 1);
        expect(result, isA<CartAddRejected>());
        expect(
          (result as CartAddRejected).reason,
          CartRejection.invalidProduct,
        );
      });
    }
  });

  group('TC-038 · AC-029-5 · añadir un producto que ya está', () {
    test('suma y no duplica la línea', () {
      final first = _added(Cart.empty.add(productId: 5, quantity: 2));
      final second = _added(first.cart.add(productId: 5, quantity: 3));
      expect(second.cart.lines, hasLength(1));
      expect(second.cart.lines.single.quantity, 5);
      expect(second.merged, isTrue);
      expect(second.clamped, isFalse);
    });

    test('98 + 1 = 99 sin acotar', () {
      const cart = Cart([CartLine(productId: 5, quantity: 98)]);
      final result = _added(cart.add(productId: 5, quantity: 1));
      expect(result.cart.lines.single.quantity, 99);
      expect(result.clamped, isFalse);
    });

    test('99 + 5 se acota a 99 y lo informa', () {
      const cart = Cart([CartLine(productId: 5, quantity: 99)]);
      final result = _added(cart.add(productId: 5, quantity: 5));
      expect(result.cart.lines.single.quantity, 99);
      expect(result.clamped, isTrue);
      expect(result.merged, isTrue);
    });

    test('mantiene la posición de la línea', () {
      const cart = Cart([
        CartLine(productId: 1, quantity: 1),
        CartLine(productId: 2, quantity: 1),
        CartLine(productId: 3, quantity: 1),
      ]);
      final result = _added(cart.add(productId: 2, quantity: 1));
      expect([for (final l in result.cart.lines) l.productId], [1, 2, 3]);
    });

    test('al fusionar, la instantánea nueva reemplaza a la anterior', () {
      final old = lineOf(5, 1);
      final fresh = CartLineSnapshot.fromProduct(
        productOf(id: 5, name: 'Nuevo', price: const Priced(Money(120000))),
      );
      final result = _added(
        Cart([old]).add(productId: 5, quantity: 1, snapshot: fresh),
      );
      expect(result.cart.lines.single.snapshot, fresh);
    });

    test('sin instantánea nueva conserva la anterior', () {
      final old = lineOf(5, 1);
      final result = _added(Cart([old]).add(productId: 5, quantity: 1));
      expect(result.cart.lines.single.snapshot, old.snapshot);
    });
  });

  group('TC-039 · AC-029-6/AC-049-3 · tope de 100 líneas', () {
    test('con 99 líneas todavía entra la 100', () {
      final result = _added(_cartOf(99).add(productId: 500, quantity: 1));
      expect(result.cart.lineCount, 100);
      expect(result.cart.isFull, isTrue);
    });

    test('con 100 líneas la 101 se rechaza y el carrito sigue igual', () {
      final cart = _cartOf(100);
      final result = cart.add(productId: 500, quantity: 1);
      expect(result, isA<CartAddRejected>());
      expect((result as CartAddRejected).reason, CartRejection.lineLimit);
      expect(cart.lineCount, 100);
    });

    test('con 100 líneas se puede sumar a una existente', () {
      final result = _added(_cartOf(100).add(productId: 50, quantity: 2));
      expect(result.cart.lineCount, 100);
      expect(result.cart.lineOf(50)!.quantity, 3);
    });

    test('quitar una línea libera un cupo', () {
      final cart = _cartOf(100).remove(1);
      expect(cart.lineCount, 99);
      expect(cart.add(productId: 500, quantity: 1), isA<CartAdded>());
    });
  });

  group('IR-02 · CR-017 · solo se añade lo comprable', () {
    CartLineSnapshot snapshot({
      PriceStatus price = const Priced(Money(1000)),
      StockStatus stock = StockStatus.inStock,
    }) => CartLineSnapshot.fromProduct(productOf(price: price, stock: stock));

    test('precio con valor y en stock se añade', () {
      expect(
        Cart.empty.add(productId: 1, quantity: 1, snapshot: snapshot()),
        isA<CartAdded>(),
      );
    });

    for (final (label, stock) in [
      ('bajo pedido', StockStatus.onBackorder),
      ('agotado', StockStatus.outOfStock),
      ('disponibilidad desconocida', StockStatus.unknown),
    ]) {
      test('$label NO es comprable', () {
        final result = Cart.empty.add(
          productId: 1,
          quantity: 1,
          snapshot: snapshot(stock: stock),
        );
        expect(
          (result as CartAddRejected).reason,
          CartRejection.notPurchasable,
        );
      });
    }

    test('sin precio NO es comprable (nunca "cero pesos")', () {
      final result = Cart.empty.add(
        productId: 1,
        quantity: 1,
        snapshot: snapshot(price: const OnRequest()),
      );
      expect((result as CartAddRejected).reason, CartRejection.notPurchasable);
    });

    test('un precio 0 se convierte en "sin precio" y tampoco se añade', () {
      expect(
        PriceStatus.fromContract(status: 'priced', amount: 0),
        isA<OnRequest>(),
      );
    });

    test('sin instantánea se admite (el servidor revalida)', () {
      expect(Cart.empty.add(productId: 1, quantity: 1), isA<CartAdded>());
    });

    test('la instantánea guarda solo datos de presentación', () {
      final snap = snapshot();
      expect(snap.isPurchasable, isTrue);
      expect(snap.name, isNotEmpty);
      expect(snap.hashCode, snapshot().hashCode);
      expect(snap, snapshot());
      expect(snap == snapshot(stock: StockStatus.outOfStock), isFalse);
    });

    test('la imagen de la instantánea conserva url y alt', () {
      final snap = CartLineSnapshot.fromProduct(
        productOf(imageUrl: 'https://staging.invalid/a.jpg'),
      );
      expect(snap.image!.url, 'https://staging.invalid/a.jpg');
    });
  });

  group('TC-041 · AC-049-5 · quitar, restaurar y totales', () {
    test('quitar una línea la elimina y baja el contador', () {
      const cart = Cart([
        CartLine(productId: 1, quantity: 2),
        CartLine(productId: 2, quantity: 3),
      ]);
      expect(cart.unitCount, 5);
      final next = cart.remove(1);
      expect(next.lines.single.productId, 2);
      expect(next.unitCount, 3);
    });

    test('quitar un producto que no está devuelve el mismo carrito', () {
      final cart = _cartOf(2);
      expect(identical(cart.remove(99), cart), isTrue);
    });

    test('removeAll quita varias y deja el resto en orden', () {
      final cart = _cartOf(5).removeAll({2, 4, 99});
      expect([for (final l in cart.lines) l.productId], [1, 3, 5]);
    });

    test('removeAll sin coincidencias no cambia nada', () {
      final cart = _cartOf(2);
      expect(identical(cart.removeAll({7}), cart), isTrue);
      expect(identical(cart.removeAll({}), cart), isTrue);
    });

    test('restore devuelve la línea a su posición', () {
      final cart = _cartOf(3);
      final line = cart.lineOf(2)!;
      final restored = cart.remove(2).restore(line, 1);
      expect([for (final l in restored.lines) l.productId], [1, 2, 3]);
    });

    test('restore con un índice fuera de rango la deja al final', () {
      final restored = _cartOf(2)
          .restore(const CartLine(productId: 9, quantity: 1), 50);
      expect(restored.lines.last.productId, 9);
      final first = _cartOf(2)
          .restore(const CartLine(productId: 8, quantity: 1), -3);
      expect(first.lines.first.productId, 8);
    });

    test(
      'restore no duplica, no pasa de 100 líneas y rechaza datos inválidos',
      () {
        final cart = _cartOf(3);
        expect(
          identical(
            cart.restore(const CartLine(productId: 2, quantity: 1), 0),
            cart,
          ),
          isTrue,
        );
        final full = _cartOf(100);
        expect(
          identical(
            full.restore(const CartLine(productId: 500, quantity: 1), 0),
            full,
          ),
          isTrue,
        );
        expect(
          identical(
            cart.restore(const CartLine(productId: 0, quantity: 1), 0),
            cart,
          ),
          isTrue,
        );
        expect(
          identical(
            cart.restore(const CartLine(productId: 9, quantity: 0), 0),
            cart,
          ),
          isTrue,
        );
      },
    );

    test('restore acota una cantidad de más de 99', () {
      final restored = Cart.empty.restore(
        const CartLine(productId: 9, quantity: 500),
        0,
      );
      expect(restored.lines.single.quantity, 99);
    });

    test('withSnapshots reemplaza solo las líneas indicadas', () {
      final cart = Cart([lineOf(1, 1), lineOf(2, 1)]);
      final fresh = CartLineSnapshot.fromProduct(
        productOf(id: 2, name: 'Otro nombre'),
      );
      final next = cart.withSnapshots({2: fresh});
      expect(next.lineOf(1)!.snapshot, cart.lineOf(1)!.snapshot);
      expect(next.lineOf(2)!.snapshot, fresh);
      expect(identical(cart.withSnapshots({}), cart), isTrue);
    });

    test('igualdad y hash por contenido', () {
      final a = Cart([lineOf(1, 2)]);
      final b = Cart([lineOf(1, 2)]);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == Cart([lineOf(1, 3)]), isFalse);
      expect(a == _cartOf(2), isFalse);
      expect(Cart.empty.isEmpty, isTrue);
      expect(a.lineOf(1).toString(), contains('CartLine(1 x2)'));
    });

    test('CartLine.copyWith y el hash por contenido', () {
      final line = lineOf(1, 2);
      expect(line.copyWith(quantity: 5).quantity, 5);
      expect(line.copyWith().snapshot, line.snapshot);
      expect(line.hashCode, lineOf(1, 2).hashCode);
    });
  });

  group('IR-04 · reconstrucción desde datos externos (sanitize)', () {
    test('descarta ids inválidos y repetidos (gana el primero)', () {
      final cart = Cart.sanitize(const [
        CartLine(productId: 0, quantity: 1),
        CartLine(productId: -3, quantity: 1),
        CartLine(productId: 4, quantity: 2),
        CartLine(productId: 4, quantity: 9),
        CartLine(productId: 5, quantity: 1),
      ]);
      expect([for (final l in cart.lines) l.productId], [4, 5]);
      expect(cart.lineOf(4)!.quantity, 2);
    });

    test('lleva las cantidades a 1–99 y descarta las ≤ 0', () {
      final cart = Cart.sanitize(const [
        CartLine(productId: 1, quantity: 0),
        CartLine(productId: 2, quantity: -4),
        CartLine(productId: 3, quantity: 500),
        CartLine(productId: 4, quantity: 99),
      ]);
      expect([for (final l in cart.lines) l.productId], [3, 4]);
      expect(cart.lineOf(3)!.quantity, 99);
    });

    test('corta en 100 líneas', () {
      final cart = Cart.sanitize([
        for (var i = 1; i <= 150; i++) CartLine(productId: i, quantity: 1),
      ]);
      expect(cart.lineCount, 100);
      expect(cart.lines.last.productId, 100);
    });

    test('lista vacía → carrito vacío', () {
      expect(Cart.sanitize(const []).isEmpty, isTrue);
    });
  });
}
