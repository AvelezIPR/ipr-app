import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/features/cart/domain/entities/cart.dart';
import 'package:ipr_mobile/features/cart/domain/entities/cart_line.dart';
import 'package:ipr_mobile/features/cart/domain/entities/cart_overview.dart';
import 'package:ipr_mobile/features/cart/domain/entities/cart_validation.dart';
import 'package:ipr_mobile/features/cart/domain/rules/cart_reconciler.dart';
import 'package:ipr_mobile/features/cart/domain/rules/cart_retention_policy.dart';
import 'package:ipr_mobile/features/cart/domain/rules/checkout_gate.dart';
import 'package:ipr_mobile/shared/domain/money.dart';
import 'package:ipr_mobile/shared/domain/price_status.dart';
import 'package:ipr_mobile/shared/domain/stock_status.dart';

import 'cart_test_support.dart';

ValidatedCartLine _blocked(
  int id,
  CartLineStatus status, {
  int quantity = 1,
  StockStatus stock = StockStatus.outOfStock,
  PriceStatus price = const Priced(Money(80000)),
  bool withProduct = true,
}) => ValidatedCartLine(
  id: id,
  quantity: quantity,
  status: status,
  product: withProduct
      ? productOf(id: id, name: 'Producto $id', price: price, stock: stock)
      : null,
);

CartReadiness _readiness(
  Cart cart,
  CartValidation? validation, {
  Map<int, int>? validatedFor,
  bool enabled = true,
  bool failed = false,
  Map<int, CartLineChange> changes = const {},
}) => evaluateCartReadiness(
  cart: cart,
  checkoutEnabled: enabled,
  validation: validation,
  validatedFor: validatedFor,
  validationFailed: failed,
  overview: CartOverview.build(
    cart: cart,
    validation: validation,
    validatedFor: validatedFor,
    validationFailed: failed,
    changes: changes,
  ),
);

void main() {
  group('RF-050 · estado de las líneas validadas', () {
    test('available + producto en stock con precio → comprable', () {
      final line = availableLine(1, 2);
      expect(line.isPurchasable, isTrue);
      expect(line.isBlocking, isFalse);
      expect(line.unitPrice, const Priced(Money(100000)));
    });

    for (final status in [
      CartLineStatus.outOfStock,
      CartLineStatus.onBackorder,
      CartLineStatus.priceOnRequest,
      CartLineStatus.notFound,
    ]) {
      test('${status.name} bloquea el pago', () {
        final line = _blocked(1, status);
        expect(line.isPurchasable, isFalse);
        expect(line.isBlocking, isTrue);
      });
    }

    test(
      'IR-02 · "available" con producto sin precio sigue sin ser comprable',
      () {
        final line = _blocked(
          1,
          CartLineStatus.available,
          stock: StockStatus.inStock,
          price: const OnRequest(),
        );
        expect(line.isPurchasable, isFalse);
      },
    );

    test('CR-017 · "available" con producto bajo pedido no es comprable', () {
      final line = _blocked(
        1,
        CartLineStatus.available,
        stock: StockStatus.onBackorder,
      );
      expect(line.isPurchasable, isFalse);
    });

    test('"available" sin producto no es comprable y no tiene precio', () {
      final line = _blocked(1, CartLineStatus.available, withProduct: false);
      expect(line.isPurchasable, isFalse);
      expect(line.unitPrice, const OnRequest());
    });

    test('lectura tolerante del estado del contrato', () {
      expect(
        CartLineStatus.fromContract('available'),
        CartLineStatus.available,
      );
      expect(
        CartLineStatus.fromContract('out_of_stock'),
        CartLineStatus.outOfStock,
      );
      expect(
        CartLineStatus.fromContract('on_backorder'),
        CartLineStatus.onBackorder,
      );
      expect(
        CartLineStatus.fromContract('price_on_request'),
        CartLineStatus.priceOnRequest,
      );
      expect(CartLineStatus.fromContract('not_found'), CartLineStatus.notFound);
      // Lo desconocido bloquea (falla cerrado).
      expect(
        CartLineStatus.fromContract('discontinued'),
        CartLineStatus.notFound,
      );
      expect(CartLineStatus.fromContract(null), CartLineStatus.notFound);
    });

    test('lineFor encuentra por id', () {
      final validation = validationOf([
        availableLine(1, 1),
        availableLine(2, 1),
      ]);
      expect(validation.lineFor(2)!.id, 2);
      expect(validation.lineFor(3), isNull);
    });
  });

  group('RF-051 · AC-051-3 · subtotal informativo', () {
    test('suma precio × cantidad de las líneas comprables', () {
      final cart = Cart([lineOf(1, 2), lineOf(2, 1)]);
      final validation = validationOf([
        availableLine(1, 2),
        availableLine(2, 1, price: 50000),
      ]);
      final overview = CartOverview.build(
        cart: cart,
        validation: validation,
        validatedFor: const {1: 2, 2: 1},
      );
      // Mismo carrito que se validó: manda el subtotal del servidor.
      expect(overview.subtotal.amount, const Money(250000));
      expect(overview.subtotal.verified, isTrue);
      expect(overview.subtotal.excludedLines, 0);
    });

    test(
      'TC-050 · 100.000 + 50.000 = 150.000 y el ítem sin precio no suma',
      () {
        final cart = Cart([lineOf(1, 1), lineOf(2, 1), lineOf(3, 1, price: 0)]);
        final validation = validationOf([
          availableLine(1, 1),
          availableLine(2, 1, price: 50000),
          _blocked(
            3,
            CartLineStatus.priceOnRequest,
            stock: StockStatus.inStock,
            price: const OnRequest(),
          ),
        ], subtotal: 150000);
        final overview = CartOverview.build(
          cart: cart,
          validation: validation,
          validatedFor: const {1: 1, 2: 1, 3: 1},
        );
        expect(overview.subtotal.amount, const Money(150000));
        expect(overview.subtotal.excludedLines, 1);
        expect(overview.lines.last.lineSubtotal, isNull);
        expect(overview.lines.last.unitPrice, const OnRequest());
      },
    );

    test(
      'si el usuario cambió una cantidad se recalcula con precios del servidor',
      () {
        final cart = Cart([lineOf(1, 3)]);
        final validation = validationOf([
          availableLine(1, 1),
        ], subtotal: 100000);
        final overview = CartOverview.build(
          cart: cart,
          validation: validation,
          validatedFor: const {1: 1},
        );
        expect(overview.subtotal.amount, const Money(300000));
        expect(overview.subtotal.verified, isTrue);
      },
    );

    test('con líneas quitadas desde la validación también se recalcula', () {
      final cart = Cart([lineOf(2, 1, price: 50000)]);
      final validation = validationOf([
        availableLine(1, 1),
        availableLine(2, 1, price: 50000),
      ], subtotal: 150000);
      final overview = CartOverview.build(
        cart: cart,
        validation: validation,
        validatedFor: const {1: 1, 2: 1},
      );
      expect(overview.subtotal.amount, const Money(50000));
    });

    test('sin validación usa lo guardado y NO lo da por verificado', () {
      final cart = Cart([lineOf(1, 2, price: 70000)]);
      final overview = CartOverview.build(cart: cart);
      expect(overview.subtotal.amount, const Money(140000));
      expect(overview.subtotal.verified, isFalse);
      expect(overview.lines.single.isVerified, isFalse);
      expect(overview.lines.single.status, isNull);
    });

    test(
      'tras un fallo de revalidación los datos viejos dejan de ser verificados',
      () {
        final cart = Cart([lineOf(1, 1)]);
        final validation = validationOf([availableLine(1, 1)]);
        final overview = CartOverview.build(
          cart: cart,
          validation: validation,
          validatedFor: const {1: 1},
          validationFailed: true,
        );
        expect(overview.subtotal.verified, isFalse);
      },
    );

    test('una línea añadida después de validar no queda verificada', () {
      final cart = Cart([lineOf(1, 1), lineOf(2, 1)]);
      final overview = CartOverview.build(
        cart: cart,
        validation: validationOf([availableLine(1, 1)]),
        validatedFor: const {1: 1},
      );
      expect(overview.subtotal.verified, isFalse);
    });

    test('sin ningún producto con precio el subtotal es cero (la UI no lo muestra como "cero pesos")', () {
      final cart = Cart([lineOf(1, 1, price: 0)]);
      final overview = CartOverview.build(cart: cart);
      expect(overview.subtotal.amount.isZero, isTrue);
      expect(overview.subtotal.excludedLines, 1);
    });

    test('las líneas bloqueadas con precio no suman', () {
      final cart = Cart([lineOf(1, 1), lineOf(2, 1)]);
      final validation = validationOf([
        availableLine(1, 1),
        _blocked(2, CartLineStatus.outOfStock),
      ]);
      final overview = CartOverview.build(
        cart: cart,
        validation: validation,
        validatedFor: const {1: 1, 2: 1},
      );
      expect(overview.subtotal.amount, const Money(100000));
      expect(overview.blockingLines.single.productId, 2);
      expect(overview.hasBlockingLines, isTrue);
    });
  });

  group('RF-050 · vista de línea', () {
    test(
      'con validación manda el producto del servidor sobre la instantánea',
      () {
        final cart = Cart([lineOf(1, 1, name: 'Nombre viejo')]);
        final overview = CartOverview.build(
          cart: cart,
          validation: validationOf([availableLine(1, 1)]),
          validatedFor: const {1: 1},
        );
        final view = overview.lines.single;
        expect(view.name, 'Producto 1');
        expect(view.sku, 'SKU-1');
        expect(view.brandName, 'Copeland');
        expect(view.availability, StockStatus.inStock);
        expect(view.isVerified, isTrue);
      },
    );

    test('AC-050-6 · not_found conserva la línea y sus datos guardados', () {
      final cart = Cart([lineOf(1, 1, name: 'Guardado')]);
      final overview = CartOverview.build(
        cart: cart,
        validation: validationOf([
          _blocked(1, CartLineStatus.notFound, withProduct: false),
        ]),
        validatedFor: const {1: 1},
      );
      final view = overview.lines.single;
      expect(view.name, 'Guardado');
      expect(view.unitPrice, isNull);
      expect(view.availability, isNull);
      expect(view.isBlocking, isTrue);
      expect(view.contributesToSubtotal, isFalse);
    });

    test('sin instantánea ni validación no hay nombre', () {
      final overview = CartOverview.build(
        cart: const Cart([CartLine(productId: 9, quantity: 1)]),
      );
      final view = overview.lines.single;
      expect(view.name, isNull);
      expect(view.unitPrice, isNull);
      expect(view.image, isNull);
      expect(view.lineSubtotal, isNull);
    });

    test('los cambios acumulados llegan a la vista', () {
      final cart = Cart([lineOf(1, 1)]);
      const change = CartLineChange(
        productId: 1,
        previousPrice: Priced(Money(100000)),
        currentPrice: Priced(Money(110000)),
        previousAvailability: StockStatus.inStock,
        currentAvailability: StockStatus.inStock,
      );
      final overview = CartOverview.build(
        cart: cart,
        changes: const {1: change},
      );
      expect(overview.lines.single.hasPendingChange, isTrue);
      expect(overview.changedLines, hasLength(1));
      expect(overview.pendingAcknowledgements, [1]);
    });
  });

  group('RF-050 · conciliación de la instantánea (N-05)', () {
    test('TC-045 · AC-050-2 · informa el precio anterior y el nuevo', () {
      final cart = Cart([lineOf(1, 1)]);
      final result = reconcileCart(
        cart: cart,
        validation: validationOf([availableLine(1, 1, price: 110000)]),
      );
      final change = result.changes[1]!;
      expect(change.priceChanged, isTrue);
      expect(change.previousPrice, const Priced(Money(100000)));
      expect(change.currentPrice, const Priced(Money(110000)));
      expect(change.requiresAcknowledgement, isTrue);
      // La instantánea ya refleja el precio del servidor.
      expect(
        result.cart.lineOf(1)!.snapshot!.price,
        const Priced(Money(110000)),
      );
    });

    test('sin cambios no informa nada', () {
      final cart = Cart([lineOf(1, 1)]);
      final result = reconcileCart(
        cart: cart,
        validation: validationOf([availableLine(1, 1)]),
      );
      expect(result.changes, isEmpty);
    });

    test('un cambio de disponibilidad se informa pero no exige aceptar', () {
      final cart = Cart([lineOf(1, 1)]);
      final validation = validationOf([_blocked(1, CartLineStatus.outOfStock)]);
      final result = reconcileCart(cart: cart, validation: validation);
      final change = result.changes[1]!;
      expect(change.availabilityChanged, isTrue);
      expect(change.priceChanged, isTrue);
      const onlyAvailability = CartLineChange(
        productId: 1,
        previousAvailability: StockStatus.inStock,
        currentAvailability: StockStatus.outOfStock,
        previousPrice: Priced(Money(1)),
        currentPrice: Priced(Money(1)),
      );
      expect(onlyAvailability.hasChange, isTrue);
      expect(onlyAvailability.requiresAcknowledgement, isFalse);
    });

    test('AC-050-5 · un precio que pasa a "sin precio" se informa', () {
      final cart = Cart([lineOf(1, 1)]);
      final validation = validationOf([
        _blocked(
          1,
          CartLineStatus.priceOnRequest,
          stock: StockStatus.inStock,
          price: const OnRequest(),
        ),
      ]);
      final result = reconcileCart(cart: cart, validation: validation);
      expect(result.changes[1]!.currentPrice, const OnRequest());
    });

    test(
      'una línea sin instantánea no genera aviso pero recibe la del servidor',
      () {
        const cart = Cart([CartLine(productId: 1, quantity: 1)]);
        final result = reconcileCart(
          cart: cart,
          validation: validationOf([availableLine(1, 1)]),
        );
        expect(result.changes, isEmpty);
        expect(result.cart.lineOf(1)!.snapshot!.name, 'Producto 1');
      },
    );

    test('un producto que el servidor no resolvió conserva su instantánea', () {
      final cart = Cart([lineOf(1, 1, name: 'Guardado')]);
      final result = reconcileCart(
        cart: cart,
        validation: validationOf([
          _blocked(1, CartLineStatus.notFound, withProduct: false),
        ]),
      );
      expect(result.cart.lineOf(1)!.snapshot!.name, 'Guardado');
      expect(result.changes, isEmpty);
    });

    test('un cambio sin aceptar sobrevive a la siguiente revalidación', () {
      final cart = Cart([lineOf(1, 1)]);
      final first = reconcileCart(
        cart: cart,
        validation: validationOf([availableLine(1, 1, price: 110000)]),
      );
      // Segunda revalidación (la previa al pago): el servidor repite 110.000.
      final second = reconcileCart(
        cart: first.cart,
        validation: validationOf([availableLine(1, 1, price: 110000)]),
        pending: first.changes,
      );
      expect(second.changes[1]!.previousPrice, const Priced(Money(100000)));
      expect(second.changes[1]!.currentPrice, const Priced(Money(110000)));
    });

    test('un cambio que vuelve al valor original se descarta', () {
      final cart = Cart([lineOf(1, 1)]);
      final first = reconcileCart(
        cart: cart,
        validation: validationOf([availableLine(1, 1, price: 110000)]),
      );
      final back = reconcileCart(
        cart: first.cart,
        validation: validationOf([availableLine(1, 1)]),
        pending: first.changes,
      );
      expect(back.changes, isEmpty);
    });

    test('los cambios pendientes de una línea sin respuesta se conservan', () {
      final cart = Cart([lineOf(1, 1)]);
      const pending = {
        1: CartLineChange(
          productId: 1,
          previousPrice: Priced(Money(1)),
          currentPrice: Priced(Money(2)),
        ),
      };
      final result = reconcileCart(
        cart: cart,
        validation: validationOf(const []),
        pending: pending,
      );
      expect(result.changes, pending);
    });

    test('igualdad y hash de un cambio', () {
      const a = CartLineChange(productId: 1, previousPrice: Priced(Money(1)));
      const b = CartLineChange(productId: 1, previousPrice: Priced(Money(1)));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.hasChange, isFalse);
      expect(
        a ==
            const CartLineChange(productId: 2, previousPrice: Priced(Money(1))),
        isFalse,
      );
    });
  });

  group('RF-050/RF-052 · puerta de pago (CartReadiness)', () {
    final cart = Cart([lineOf(1, 1), lineOf(2, 1)]);
    final ok = validationOf([availableLine(1, 1), availableLine(2, 1)]);
    const covered = {1: 1, 2: 1};

    test('AC-049-6 · carrito vacío → empty', () {
      expect(_readiness(Cart.empty, null), CartReadiness.empty);
    });

    test('todo verificado y permitido → ready', () {
      expect(_readiness(cart, ok, validatedFor: covered), CartReadiness.ready);
    });

    test(
      'interruptor checkoutEnabled apagado → no se paga (falla cerrado)',
      () {
        expect(
          _readiness(cart, ok, validatedFor: covered, enabled: false),
          CartReadiness.checkoutDisabled,
        );
      },
    );

    test('sin validación → unverified', () {
      expect(_readiness(cart, null), CartReadiness.unverified);
      expect(_readiness(cart, ok), CartReadiness.unverified);
    });

    test(
      'AC-050-7 · el último intento falló → unverified aunque haya datos',
      () {
        expect(
          _readiness(cart, ok, validatedFor: covered, failed: true),
          CartReadiness.unverified,
        );
      },
    );

    test('una cantidad cambiada después de validar → unverified', () {
      final changed = Cart([lineOf(1, 5), lineOf(2, 1)]);
      expect(
        _readiness(changed, ok, validatedFor: covered),
        CartReadiness.unverified,
      );
    });

    test('una línea nueva no validada → unverified', () {
      final more = Cart([lineOf(1, 1), lineOf(2, 1), lineOf(3, 1)]);
      expect(
        _readiness(more, ok, validatedFor: covered),
        CartReadiness.unverified,
      );
    });

    test('el servidor no devolvió una línea → unverified', () {
      final partial = validationOf([availableLine(1, 1)]);
      expect(
        _readiness(cart, partial, validatedFor: covered),
        CartReadiness.unverified,
      );
    });

    test('TC-046 · AC-050-3 · línea agotada → blockedLines', () {
      final validation = validationOf([
        availableLine(1, 1),
        _blocked(2, CartLineStatus.outOfStock),
      ], checkoutAllowed: false);
      expect(
        _readiness(cart, validation, validatedFor: covered),
        CartReadiness.blockedLines,
      );
    });

    test('AC-050-4 · al quitar la agotada, el "no" viejo del servidor obliga a volver a preguntar', () {
      final validation = validationOf([
        availableLine(1, 1),
        _blocked(2, CartLineStatus.outOfStock),
      ], checkoutAllowed: false);
      final after = Cart([lineOf(1, 1)]);
      expect(
        _readiness(after, validation, validatedFor: covered),
        CartReadiness.unverified,
      );
    });

    test('con el mismo carrito, checkoutAllowed=false manda: serverDenied', () {
      final denied = validationOf([
        availableLine(1, 1),
        availableLine(2, 1),
      ], checkoutAllowed: false);
      expect(
        _readiness(cart, denied, validatedFor: covered),
        CartReadiness.serverDenied,
      );
    });

    test('un cambio de precio sin aceptar bloquea; aceptado, no', () {
      const change = CartLineChange(
        productId: 1,
        previousPrice: Priced(Money(100000)),
        currentPrice: Priced(Money(110000)),
      );
      expect(
        _readiness(cart, ok, validatedFor: covered, changes: {1: change}),
        CartReadiness.pendingChanges,
      );
      expect(_readiness(cart, ok, validatedFor: covered), CartReadiness.ready);
    });

    test('las líneas bloqueadas prevalecen sobre los cambios de precio', () {
      final validation = validationOf([
        availableLine(1, 1),
        _blocked(2, CartLineStatus.notFound, withProduct: false),
      ]);
      const change = CartLineChange(
        productId: 1,
        previousPrice: Priced(Money(1)),
        currentPrice: Priced(Money(2)),
      );
      expect(
        _readiness(
          cart,
          validation,
          validatedFor: covered,
          changes: {1: change},
        ),
        CartReadiness.blockedLines,
      );
    });
  });

  group('DN-10 · CR-040 · política de retención del carrito', () {
    test('H-07 pendiente: por defecto se conserva al cerrar sesión', () {
      expect(CartRetentionPolicy.current.clearOnLogout, isFalse);
    });

    test('RF-044 · se conserva al expirar la sesión', () {
      expect(CartRetentionPolicy.current.clearOnSessionExpired, isFalse);
    });

    test('CR-040 · se borra al eliminar la cuenta', () {
      expect(CartRetentionPolicy.current.clearOnAccountDeleted, isTrue);
    });

    test('es el único punto de decisión y se puede cambiar', () {
      const policy = CartRetentionPolicy(
        clearOnLogout: true,
        clearOnAccountDeleted: false,
      );
      expect(policy.clearOnLogout, isTrue);
      expect(policy.clearOnAccountDeleted, isFalse);
    });
  });
}
