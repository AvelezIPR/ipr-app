import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/features/cart/data/mappers/cart_validation_mapper.dart';
import 'package:ipr_mobile/features/catalog/data/mappers/catalog_mappers.dart';
import 'package:ipr_mobile/features/product_detail/data/dtos/product_detail_dto.dart';
import 'package:ipr_mobile/features/product_detail/data/mappers/product_detail_mapper.dart';
import 'package:ipr_mobile/features/product_detail/domain/entities/product_variant.dart';
import 'package:ipr_mobile/features/product_detail/domain/rules/variant_selection.dart';
import 'package:ipr_mobile/shared/domain/image_ref.dart';
import 'package:ipr_mobile/shared/domain/money.dart';
import 'package:ipr_mobile/shared/domain/price_status.dart';
import 'package:ipr_mobile/shared/domain/quantity_range.dart';
import 'package:ipr_mobile/shared/domain/stock_status.dart';

import 'product_detail_test_support.dart';

const _voltage = ProductVariantAxis(
  slug: 'pa_voltaje',
  name: 'Voltaje',
  options: [
    ProductVariantOption(value: '220-v', label: '220 V'),
    ProductVariantOption(value: '440-v', label: '440 V'),
  ],
);
const _diameter = ProductVariantAxis(
  slug: 'pa_diametro',
  name: 'Diámetro',
  options: [
    ProductVariantOption(value: '1-2', label: '1/2"'),
    ProductVariantOption(value: '3-4', label: '3/4"'),
  ],
);

ProductVariant _variant(
  int id,
  Map<String, String> selection, {
  PriceStatus price = const Priced(Money(100000)),
  StockStatus stock = StockStatus.inStock,
  bool purchasable = true,
}) => ProductVariant(
  id: id,
  sku: 'SKU-$id',
  price: price,
  availability: stock,
  selection: selection,
  serverPurchasable: purchasable,
);

/// 220/1-2, 220/3-4 y 440/1-2: la combinación 440 V + 3/4" no existe.
final List<ProductVariant> _variants = [
  _variant(1, {'pa_voltaje': '220-v', 'pa_diametro': '1-2'}),
  _variant(2, {
    'pa_voltaje': '220-v',
    'pa_diametro': '3-4',
  }, price: const Priced(Money(80000))),
  _variant(3, {'pa_voltaje': '440-v', 'pa_diametro': '1-2'}),
];

VariantSelection _selection([Map<String, String> chosen = const {}]) =>
    VariantSelection(
      axes: const [_voltage, _diameter],
      variants: _variants,
      chosen: chosen,
    );

void main() {
  group('W1-01 · VariantSelection', () {
    test('sin elegir no hay variación y "Desde" es el precio mínimo', () {
      final selection = _selection();
      expect(selection.isComplete, isFalse);
      expect(selection.variant, isNull);
      expect(selection.fromPrice, const Money(80000));
    });

    test('elegidos todos los ejes resuelve la variación', () {
      final selection = _selection()
          .toggle('pa_voltaje', '220-v')
          .toggle('pa_diametro', '3-4');
      expect(selection.isComplete, isTrue);
      expect(selection.variant!.id, 2);
      expect(selection.labelOf(selection.variant!), '220 V / 3/4"');
    });

    test('una opción incompatible con lo elegido limpia solo los ejes incompatibles', () {
      final selection = _selection().toggle('pa_voltaje', '440-v');
      expect(selection.isOptionAvailable('pa_diametro', '1-2'), isTrue);
      expect(selection.isOptionAvailable('pa_diametro', '3-4'), isFalse);
      expect(selection.hasAnyVariantFor('pa_diametro', '3-4'), isTrue);

      // Tocar 3/4" limpia 440 V (incompatible) y selecciona 3/4".
      final switched = selection.toggle('pa_diametro', '3-4');
      expect(switched.chosen, {'pa_diametro': '3-4'});
      expect(switched.variant, isNull);
    });

    test('una opción inexistente en todo el producto no cambia nada', () {
      final selection = _selection().toggle('pa_voltaje', '440-v');
      expect(selection.hasAnyVariantFor('pa_diametro', '1-0'), isFalse);
      expect(selection.toggle('pa_diametro', '1-0'), same(selection));
    });

    test('hasAnyVariantFor considera ejes comodín en la variación', () {
      final selection = VariantSelection(
        axes: const [_voltage, _diameter],
        variants: [
          _variant(10, {'pa_diametro': '1-2'}), // voltaje comodín
        ],
      );
      expect(selection.hasAnyVariantFor('pa_voltaje', '440-v'), isTrue);
      expect(selection.hasAnyVariantFor('pa_diametro', '1-2'), isTrue);
      expect(selection.hasAnyVariantFor('pa_diametro', '3-4'), isFalse);
    });

    test('toggle conserva ejes compatibles y limpia solo los incompatibles en 3 ejes', () {
      const material = ProductVariantAxis(
        slug: 'pa_material',
        name: 'Material',
        options: [
          ProductVariantOption(value: 'bronce', label: 'Bronce'),
          ProductVariantOption(value: 'acero', label: 'Acero'),
        ],
      );
      final selection = VariantSelection(
        axes: const [_voltage, _diameter, material],
        variants: [
          _variant(1, {
            'pa_voltaje': '220-v',
            'pa_diametro': '1-2',
            'pa_material': 'bronce',
          }),
          _variant(2, {
            'pa_voltaje': '220-v',
            'pa_diametro': '3-4',
            'pa_material': 'acero',
          }),
        ],
        chosen: const {
          'pa_voltaje': '220-v',
          'pa_diametro': '1-2',
          'pa_material': 'bronce',
        },
      );

      // Cambiar a acero es incompatible con 1/2", pero compatible con 220 V.
      final switched = selection.toggle('pa_material', 'acero');
      expect(switched.chosen, {'pa_material': 'acero', 'pa_voltaje': '220-v'});
    });

    test('VariantSelection.initial preselecciona si hay 1 variación total', () {
      final selection = VariantSelection.initial(
        axes: const [_voltage, _diameter],
        variants: [
          _variant(1, {
            'pa_voltaje': '220-v',
            'pa_diametro': '1-2',
          }, price: const OnRequest()),
        ],
      );
      expect(selection.isComplete, isTrue);
      expect(selection.chosen, {'pa_voltaje': '220-v', 'pa_diametro': '1-2'});
      expect(selection.variant!.id, 1);
    });

    test(
      'VariantSelection.initial preselecciona si hay exactamente 1 con precio',
      () {
        final selection = VariantSelection.initial(
          axes: const [_voltage, _diameter],
          variants: [
            _variant(1, {
              'pa_voltaje': '220-v',
              'pa_diametro': '1-2',
            }, price: const OnRequest()),
            _variant(2, {
              'pa_voltaje': '440-v',
              'pa_diametro': '3-4',
            }, price: const Priced(Money(95000))),
          ],
        );
        expect(selection.isComplete, isTrue);
        expect(selection.chosen, {'pa_voltaje': '440-v', 'pa_diametro': '3-4'});
        expect(selection.variant!.id, 2);
      },
    );

    test('VariantSelection.initial no preselecciona con múltiples variaciones con precio o ninguna', () {
      final multiplePriced = VariantSelection.initial(
        axes: const [_voltage, _diameter],
        variants: _variants,
      );
      expect(multiplePriced.chosen, isEmpty);
      expect(multiplePriced.variant, isNull);

      final nonePriced = VariantSelection.initial(
        axes: const [_voltage, _diameter],
        variants: [
          _variant(1, {
            'pa_voltaje': '220-v',
            'pa_diametro': '1-2',
          }, price: const OnRequest()),
          _variant(2, {
            'pa_voltaje': '440-v',
            'pa_diametro': '1-2',
          }, price: const OnRequest()),
        ],
      );
      expect(nonePriced.chosen, isEmpty);

      final empty = VariantSelection.initial(
        axes: const [_voltage],
        variants: const [],
      );
      expect(empty.chosen, isEmpty);
    });

    test(
      'VariantSelection.initial completa eje comodín si solo tiene una opción',
      () {
        const singleOptAxis = ProductVariantAxis(
          slug: 'pa_diametro',
          name: 'Diámetro',
          options: [ProductVariantOption(value: '1-2', label: '1/2"')],
        );
        final selection = VariantSelection.initial(
          axes: const [singleOptAxis],
          variants: [_variant(10, const {})],
        );
        expect(selection.chosen, {'pa_diametro': '1-2'});
        expect(selection.variant!.id, 10);
      },
    );

    test('sin nada elegido todas las opciones están disponibles', () {
      final selection = _selection();
      for (final axis in selection.axes) {
        for (final option in axis.options) {
          expect(selection.isOptionAvailable(axis.slug, option.value), isTrue);
        }
      }
    });

    test('tocar la opción elegida la quita', () {
      final selection = _selection()
          .toggle('pa_voltaje', '220-v')
          .toggle('pa_diametro', '3-4')
          .toggle('pa_diametro', '3-4');
      expect(selection.chosen, {'pa_voltaje': '220-v'});
      expect(selection.variant, isNull);
    });

    test('cambiar de opción en un eje reemplaza la anterior', () {
      final selection = _selection()
          .toggle('pa_voltaje', '220-v')
          .toggle('pa_voltaje', '440-v');
      expect(selection.chosen, {'pa_voltaje': '440-v'});
    });

    test('una combinación inexistente no da variación', () {
      const selection = VariantSelection(
        axes: [_voltage, _diameter],
        variants: [],
        chosen: {'pa_voltaje': '440-v', 'pa_diametro': '3-4'},
      );
      expect(selection.variant, isNull);
    });

    test('un eje vacío en la variación vale para cualquier opción', () {
      final selection = VariantSelection(
        axes: const [_voltage, _diameter],
        variants: [
          _variant(10, {'pa_diametro': '1-2'}), // voltaje: cualquiera
        ],
      ).toggle('pa_voltaje', '440-v').toggle('pa_diametro', '1-2');
      expect(selection.variant!.id, 10);
    });

    test('con varias válidas gana la más específica', () {
      final selection = VariantSelection(
        axes: const [_voltage, _diameter],
        variants: [
          _variant(10, {'pa_diametro': '1-2'}),
          _variant(11, {'pa_voltaje': '440-v', 'pa_diametro': '1-2'}),
        ],
      ).toggle('pa_voltaje', '440-v').toggle('pa_diametro', '1-2');
      expect(selection.variant!.id, 11);
    });

    test(r'sin ninguna variación con precio no hay "Desde" (nunca $0)', () {
      final selection = VariantSelection(
        axes: const [_voltage],
        variants: [
          _variant(1, {'pa_voltaje': '220-v'}, price: const OnRequest()),
        ],
      );
      expect(selection.fromPrice, isNull);
    });

    test('canAddToCart exige precio, stock y que el servidor no lo niegue', () {
      expect(_variant(1, {}).canAddToCart, isTrue);
      expect(_variant(1, {}, price: const OnRequest()).canAddToCart, isFalse);
      expect(
        _variant(1, {}, stock: StockStatus.onBackorder).canAddToCart,
        isFalse,
      );
      expect(_variant(1, {}, purchasable: false).canAddToCart, isFalse);
    });
  });

  group('W1-01 · ProductDetail variable (DTO → entidad)', () {
    test('lee ejes y variaciones del contrato', () {
      final product = fixtureProduct('ProductDetail.variable.json');
      expect(product.isVariable, isTrue);
      expect(product.variantAxes.map((a) => a.slug), [
        'pa_voltaje',
        'pa_diametro',
      ]);
      expect(product.variants.map((v) => v.id), [4701, 4702, 4703]);
      expect(product.variants[1].onSale, isTrue);
      expect(product.variants[1].regularPrice, const Money(260000));
      expect(product.variants[1].image, isNotNull);
      expect(product.variants[2].price, isA<OnRequest>());
    });

    test('un producto variable NUNCA se compra sin elegir variación', () {
      final product = fixtureProduct('ProductDetail.variable.json');
      expect(product.canAddToCart, isFalse);
    });

    test('un producto simple no cambia', () {
      final product = fixtureProduct('ProductDetail.priced.json');
      expect(product.isVariable, isFalse);
      expect(product.variants, isEmpty);
      expect(product.canAddToCart, isTrue);
    });

    test('withVariant usa el id, SKU, precio y stock de la variación', () {
      final product = fixtureProduct('ProductDetail.variable.json');
      final chosen = product.variants[1];
      final simple = product.withVariant(chosen, label: '220 V / 3/4"');
      expect(simple.id, 4702);
      expect(simple.sku, '470-0002');
      expect(simple.price, const Priced(Money(240000)));
      expect(simple.summary.strikeThroughPrice, const Money(260000));
      expect(simple.name, 'Válvula solenoide de prueba · 220 V / 3/4"');
      expect(simple.isVariable, isFalse);
      expect(simple.canAddToCart, isTrue);
      // La imagen de la variación va primero en la galería.
      expect(simple.gallery.first.url, contains('valvula-34'));
    });

    test('una variación sin precio no se compra (Más información)', () {
      final product = fixtureProduct('ProductDetail.variable.json');
      final simple = product.withVariant(product.variants[2], label: '440 V');
      expect(simple.canAddToCart, isFalse);
      expect(simple.price, isA<OnRequest>());
    });

    test('lectura tolerante: ejes u opciones ilegibles se descartan', () {
      final body =
          fixtureBody('ProductDetail.variable.json')['data']
              as Map<String, dynamic>;
      body['variantAxes'] = [
        'basura',
        {'slug': '', 'name': 'x', 'options': <Object?>[]},
        {'slug': 'a', 'name': 'Sin opciones', 'options': <Object?>[]},
        {
          'slug': 'ok',
          'name': 'Bueno',
          'options': [
            {'value': 'v', 'label': ''},
            {'value': 7},
          ],
        },
      ];
      body['variants'] = [
        {'id': 0, 'selection': <Object?>[]},
        'x',
        {
          'id': 9,
          'selection': [
            {'axis': 'ok', 'value': 'v'},
            {'axis': 'ok'},
          ],
        },
      ];
      final product = ProductDetailDto.fromJson(body).toEntity();
      expect(product.variantAxes.single.slug, 'ok');
      // Etiqueta vacía → se usa el valor.
      expect(product.variantAxes.single.options.single.label, 'v');
      expect(product.variants.single.id, 9);
      expect(product.variants.single.selection, {'ok': 'v'});
      // Precio ausente → sin precio, nunca $0.
      expect(product.variants.single.price, isA<OnRequest>());
    });

    test('sin ejes o sin variaciones no es variable', () {
      final body =
          fixtureBody('ProductDetail.variable.json')['data']
              as Map<String, dynamic>;
      body['variants'] = <Object?>[];
      expect(ProductDetailDto.fromJson(body).toEntity().isVariable, isFalse);
    });
  });

  group('W1-01 · tarjetas y carrito', () {
    Map<String, dynamic> catalogFixture(String name) =>
        jsonDecode(File('test/fixtures/catalog/$name').readAsStringSync())
            as Map<String, dynamic>;

    test('ProductSummary variable: hasVariants y "Desde"', () {
      final product = mapProductSummary(
        catalogFixture('ProductSummary.variable.json'),
      )!;
      expect(product.hasVariants, isTrue);
      expect(product.priceFrom, const Money(180000));
    });

    test('un producto simple no es variable', () {
      final product = mapProductSummary(
        catalogFixture('ProductSummary.priced.json'),
      )!;
      expect(product.hasVariants, isFalse);
      expect(product.priceFrom, isNull);
    });

    test('priceFrom en cero, ilegible o sin hasVariants se ignora', () {
      final base = catalogFixture('ProductSummary.variable.json');
      expect(mapProductSummary({...base, 'priceFrom': 0})!.priceFrom, isNull);
      expect(
        mapProductSummary({...base, 'priceFrom': 1500.5})!.priceFrom,
        isNull,
      );
      expect(
        mapProductSummary({...base, 'hasVariants': false})!.priceFrom,
        isNull,
      );
    });

    test('/cart/validate: la línea de una variación lleva la opción', () {
      final body = jsonDecode(
        File('test/fixtures/cart/CartValidation.variation.json')
            .readAsStringSync(),
      );
      final line = mapCartValidation(body).lines.single;
      expect(line.id, 4702);
      expect(line.product!.name, 'Válvula solenoide de prueba · 220 V / 3/4"');
      expect(line.product!.sku, '470-0002');
    });
  });

  group('W1-01 · entidades de ProductVariant', () {
    ProductVariantOption opt(String value, String label) =>
        ProductVariantOption(value: value, label: label);
    ImageRef img(String url, String alt) => ImageRef(url: url, alt: alt);
    QuantityRange range(int min, int max) => QuantityRange(min: min, max: max);

    test('ProductVariantOption igualdad y hashCode', () {
      final a = opt('220-v', '220 V');
      final b = opt('220-v', '220 V');
      final diffValue = opt('440-v', '220 V');
      final diffLabel = opt('220-v', '220V');

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == diffValue, isFalse);
      expect(a == diffLabel, isFalse);
      expect(a == Object(), isFalse);
    });

    test('ProductVariantAxis labelOf, igualdad y hashCode', () {
      final opt1 = opt('220-v', '220 V');
      final opt2 = opt('440-v', '440 V');
      final axisA = ProductVariantAxis(
        slug: 'pa_voltaje',
        name: 'Voltaje',
        options: [opt1, opt2],
      );
      final axisB = ProductVariantAxis(
        slug: 'pa_voltaje',
        name: 'Voltaje',
        options: [opt1, opt2],
      );
      final diffSlug = ProductVariantAxis(
        slug: 'pa_otro',
        name: 'Voltaje',
        options: [opt1, opt2],
      );
      final diffName = ProductVariantAxis(
        slug: 'pa_voltaje',
        name: 'Tensión',
        options: [opt1, opt2],
      );
      final diffLen = ProductVariantAxis(
        slug: 'pa_voltaje',
        name: 'Voltaje',
        options: [opt1],
      );
      final diffOpt = ProductVariantAxis(
        slug: 'pa_voltaje',
        name: 'Voltaje',
        options: [opt1, opt('110-v', '110 V')],
      );

      expect(axisA.labelOf('220-v'), '220 V');
      expect(axisA.labelOf('desconocido'), 'desconocido');
      expect(axisA, axisB);
      expect(axisA.hashCode, axisB.hashCode);
      expect(axisA == diffSlug, isFalse);
      expect(axisA == diffName, isFalse);
      expect(axisA == diffLen, isFalse);
      expect(axisA == diffOpt, isFalse);
      expect(axisA == Object(), isFalse);
    });

    test('ProductVariant constructor, igualdad, hashCode y canAddToCart', () {
      final image = img('https://staging.invalid/a.jpg', 'A');
      final qtyRange = range(2, 5);
      final v1 = ProductVariant(
        id: 10,
        sku: 'SKU-10',
        price: const Priced(Money(50000)),
        regularPrice: const Money(60000),
        onSale: true,
        availability: StockStatus.inStock,
        image: image,
        selection: const {'pa_voltaje': '220-v'},
        quantityRange: qtyRange,
      );
      final v2 = ProductVariant(
        id: 10,
        sku: 'SKU-10',
        price: const Priced(Money(50000)),
        regularPrice: const Money(60000),
        onSale: true,
        availability: StockStatus.inStock,
        image: image,
        selection: const {'pa_voltaje': '220-v'},
        quantityRange: qtyRange,
      );
      final diffSelLen = ProductVariant(
        id: 10,
        sku: 'SKU-10',
        price: const Priced(Money(50000)),
        regularPrice: const Money(60000),
        onSale: true,
        availability: StockStatus.inStock,
        image: image,
        selection: const {'pa_voltaje': '220-v', 'pa_diametro': '1-2'},
        quantityRange: qtyRange,
      );
      final diffSelVal = ProductVariant(
        id: 10,
        sku: 'SKU-10',
        price: const Priced(Money(50000)),
        regularPrice: const Money(60000),
        onSale: true,
        availability: StockStatus.inStock,
        image: image,
        selection: const {'pa_voltaje': '440-v'},
        quantityRange: qtyRange,
      );
      final diffId = ProductVariant(
        id: 11,
        sku: 'SKU-10',
        price: const Priced(Money(50000)),
        regularPrice: const Money(60000),
        onSale: true,
        availability: StockStatus.inStock,
        image: image,
        selection: const {'pa_voltaje': '220-v'},
        quantityRange: qtyRange,
      );

      expect(v1, v2);
      expect(v1.hashCode, v2.hashCode);
      expect(v1.canAddToCart, isTrue);
      expect(v1 == diffSelLen, isFalse);
      expect(v1 == diffSelVal, isFalse);
      expect(v1 == diffId, isFalse);
      expect(v1 == Object(), isFalse);
    });
  });
}
