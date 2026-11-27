import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/features/cart/data/mappers/cart_storage_codec.dart';
import 'package:ipr_mobile/features/cart/domain/entities/cart.dart';
import 'package:ipr_mobile/features/cart/domain/entities/cart_line.dart';
import 'package:ipr_mobile/features/cart/domain/entities/cart_overview.dart';
import 'package:ipr_mobile/features/cart/domain/entities/cart_validation.dart';
import 'package:ipr_mobile/features/cart/domain/rules/cart_reconciler.dart';
import 'package:ipr_mobile/features/catalog/data/mappers/catalog_mappers.dart';
import 'package:ipr_mobile/features/product_detail/domain/rules/quantity_rules.dart';
import 'package:ipr_mobile/shared/domain/product_summary.dart';
import 'package:ipr_mobile/shared/domain/quantity_range.dart';

import '../product_detail/product_detail_test_support.dart';
import 'cart_test_support.dart';

const _three = QuantityRange(max: 3);
const _twoToFive = QuantityRange(min: 2, max: 5);

CartAdded _added(CartAddResult result) => result as CartAdded;

void main() {
  group('W1-06 · QuantityRange', () {
    test('sin datos es el rango general 1–99', () {
      expect(QuantityRange.fromContract(), QuantityRange.standard);
      expect(QuantityRange.standard.isStandard, isTrue);
    });

    test('lee mínimo y máximo del contrato', () {
      final range = QuantityRange.fromContract(min: 2, max: 5);
      expect(range, _twoToFive);
      expect(range.isStandard, isFalse);
    });

    test('valores ilegibles o fuera de 1–99 se ignoran uno a uno', () {
      expect(
        QuantityRange.fromContract(min: 0, max: 5),
        const QuantityRange(max: 5),
      );
      expect(
        QuantityRange.fromContract(min: 'x', max: 150),
        QuantityRange.standard,
      );
      expect(
        QuantityRange.fromContract(min: 2.5, max: 4.0),
        const QuantityRange(max: 4),
      );
      expect(QuantityRange.fromContract(), QuantityRange.standard);
    });

    test('un rango incoherente (máximo < mínimo) se descarta entero', () {
      expect(
        QuantityRange.fromContract(min: 5, max: 3),
        QuantityRange.standard,
      );
    });

    test('clamp e isAtMax', () {
      expect(_twoToFive.clamp(0), 2);
      expect(_twoToFive.clamp(3), 3);
      expect(_twoToFive.clamp(99), 5);
      expect(_twoToFive.isAtMax(5), isTrue);
      expect(_twoToFive.isAtMax(4), isFalse);
    });

    test('QuantityRules respeta el mínimo y el máximo del producto', () {
      expect(QuantityRules.clamp(1, minQuantity: 2, maxQuantity: 5), 2);
      expect(QuantityRules.clamp(9, minQuantity: 2, maxQuantity: 5), 5);
      final empty = QuantityRules.parse('', minQuantity: 2, maxQuantity: 5);
      expect((empty.value, empty.corrected), (2, true));
      final big = QuantityRules.parse(
        '9999999',
        minQuantity: 2,
        maxQuantity: 5,
      );
      expect(big.value, 5);
      final low = QuantityRules.parse('1', minQuantity: 2, maxQuantity: 5);
      expect((low.value, low.corrected), (2, true));
      final ok = QuantityRules.parse('4', minQuantity: 2, maxQuantity: 5);
      expect((ok.value, ok.corrected), (4, false));
    });
  });

  group('W1-06 · Cart con límites por producto', () {
    CartLineSnapshot snapshot(QuantityRange range) =>
        CartLineSnapshot.fromProduct(productOf(id: 7, range: range));

    test('añadir un producto nuevo respeta su máximo y avisa', () {
      final result = _added(
        Cart.empty.add(productId: 7, quantity: 5, snapshot: snapshot(_three)),
      );
      expect(result.quantity, 3);
      expect(result.clamped, isTrue);
      expect(result.maxQuantity, 3);
    });

    test('añadir menos que el mínimo sube al mínimo sin avisar de tope', () {
      final result = _added(
        Cart.empty.add(
          productId: 7,
          quantity: 1,
          snapshot: snapshot(_twoToFive),
        ),
      );
      expect(result.quantity, 2);
      expect(result.clamped, isFalse);
    });

    test('sumar a una línea existente se acota al máximo del producto', () {
      final first = _added(
        Cart.empty.add(productId: 7, quantity: 2, snapshot: snapshot(_three)),
      );
      final second = _added(
        first.cart.add(productId: 7, quantity: 2, snapshot: snapshot(_three)),
      );
      expect(second.merged, isTrue);
      expect(second.quantity, 3);
      expect(second.clamped, isTrue);
    });

    test('sin instantánea nueva se usan los límites que ya tenía la línea', () {
      final first = _added(
        Cart.empty.add(productId: 7, quantity: 2, snapshot: snapshot(_three)),
      );
      final second = _added(first.cart.add(productId: 7, quantity: 5));
      expect(second.quantity, 3);
    });

    test('sin límites propios sigue valiendo 1–99', () {
      final result = _added(
        Cart.empty.add(
          productId: 7,
          quantity: 150,
          snapshot: snapshot(QuantityRange.standard),
        ),
      );
      expect(result.quantity, 99);
      expect(result.maxQuantity, 99);
    });

    test('setQuantity usa el rango de la línea', () {
      final cart = Cart([lineOf(1, 2, range: _twoToFive)]);
      expect(cart.setQuantity(1, 50).lineOf(1)!.quantity, 5);
      expect(cart.setQuantity(1, 1).lineOf(1)!.quantity, 2);
      expect(cart.setQuantity(1, 4).lineOf(1)!.quantity, 4);
    });

    test('sanitize recorta lo guardado al rango de cada línea', () {
      final cart = Cart.sanitize([
        lineOf(1, 50, range: _three),
        lineOf(2, 1, range: _twoToFive),
        lineOf(3, 120),
      ]);
      expect(cart.lineOf(1)!.quantity, 3);
      expect(cart.lineOf(2)!.quantity, 2);
      expect(cart.lineOf(3)!.quantity, 99);
    });

    test('restore acota al rango de la línea', () {
      final restored = Cart.empty.restore(lineOf(1, 9, range: _three), 0);
      expect(restored.lineOf(1)!.quantity, 3);
    });

    test('una revalidación con un máximo menor recorta la cantidad (N-05)', () {
      final cart = Cart([lineOf(1, 8)]);
      final validation = validationOf([
        availableLine(1, 8).copyWithProduct(
          productOf(id: 1, name: 'Producto 1', sku: 'SKU-1', range: _three),
        ),
      ]);
      final result = reconcileCart(cart: cart, validation: validation);
      expect(result.cart.lineOf(1)!.quantity, 3);
      expect(result.cart.lineOf(1)!.snapshot!.quantityRange, _three);
    });

    test('la vista de la línea prefiere el rango del servidor', () {
      final cart = Cart([lineOf(1, 2, range: _twoToFive)]);
      final overview = CartOverview.build(
        cart: cart,
        validation: validationOf([
          availableLine(1, 2).copyWithProduct(
            productOf(id: 1, name: 'Producto 1', sku: 'SKU-1', range: _three),
          ),
        ]),
        validatedFor: const {1: 2},
      );
      expect(overview.lines.single.quantityRange, _three);
      // Sin revalidar, el de la instantánea guardada.
      final offline = CartOverview.build(cart: cart);
      expect(offline.lines.single.quantityRange, _twoToFive);
    });
  });

  group('W1-06 · persistencia local', () {
    test('el rango del producto sobrevive a guardar y leer', () {
      final cart = Cart([lineOf(1, 2, range: _twoToFive)]);
      final decoded = CartStorageCodec.decode(CartStorageCodec.encode(cart));
      expect(decoded.lineOf(1)!.quantityRange, _twoToFive);
      expect(decoded.lineOf(1)!.quantity, 2);
    });

    test('el rango general no se escribe (el JSON no cambia)', () {
      final text = CartStorageCodec.encode(Cart([lineOf(1, 2)]));
      expect(text, isNot(contains('minQuantity')));
      expect(text, isNot(contains('maxQuantity')));
    });

    test('un carrito guardado antes de W1-06 se lee con el rango general', () {
      final old = jsonEncode({
        'v': 1,
        'lines': [
          {
            'productId': 1,
            'quantity': 4,
            'snapshot': {
              'name': 'Viejo',
              'sku': 'V-1',
              'price': 1000,
              'availability': 'in_stock',
            },
          },
        ],
      });
      final decoded = CartStorageCodec.decode(old);
      expect(decoded.lineOf(1)!.quantityRange, QuantityRange.standard);
      expect(decoded.lineOf(1)!.quantity, 4);
    });

    test('límites guardados corruptos se ignoran', () {
      final text = jsonEncode({
        'v': 1,
        'lines': [
          {
            'productId': 1,
            'quantity': 4,
            'snapshot': {
              'name': 'X',
              'sku': 'X',
              'price': 1000,
              'availability': 'in_stock',
              'minQuantity': 'abc',
              'maxQuantity': 7000,
            },
          },
        ],
      });
      final decoded = CartStorageCodec.decode(text);
      expect(decoded.lineOf(1)!.quantityRange, QuantityRange.standard);
    });
  });

  group('W1-06 · lectura del contrato', () {
    test('tarjetas: minQuantity y maxQuantity', () {
      final base = jsonDecode(
        File('test/fixtures/catalog/ProductSummary.priced.json')
            .readAsStringSync(),
      ) as Map<String, dynamic>;
      expect(mapProductSummary(base)!.quantityRange, QuantityRange.standard);
      final limited = mapProductSummary({
        ...base,
        'minQuantity': 2,
        'maxQuantity': 6,
      })!;
      expect(limited.quantityRange, const QuantityRange(min: 2, max: 6));
    });

    test('ficha: límites de la variación y del producto', () {
      final product = fixtureProduct('ProductDetail.variable.json');
      expect(
        product.variants[0].quantityRange,
        const QuantityRange(min: 2, max: 12),
      );
      expect(product.variants[1].quantityRange, _three);
      expect(product.variants[2].quantityRange, QuantityRange.standard);
      // Al elegir la variación, la ficha toma sus límites.
      final simple = product.withVariant(product.variants[1], label: '220 V');
      expect(simple.summary.quantityRange, _three);
    });

    test('/cart/validate: la línea trae los límites del producto', () {
      final line = cartFixture('CartValidation.variation.json').lines.single;
      expect(line.product!.quantityRange, _three);
    });
  });
}

extension on ValidatedCartLine {
  /// Misma línea validada con otro producto.
  ValidatedCartLine copyWithProduct(ProductSummary product) =>
      ValidatedCartLine(
        id: id,
        quantity: quantity,
        status: status,
        product: product,
        lineSubtotal: lineSubtotal,
      );
}
