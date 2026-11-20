import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/core/storage/durable_store.dart';
import 'package:ipr_mobile/features/cart/data/mappers/cart_storage_codec.dart';
import 'package:ipr_mobile/features/cart/data/mappers/cart_validation_mapper.dart';
import 'package:ipr_mobile/features/cart/data/repositories/api_cart_validation_repository.dart';
import 'package:ipr_mobile/features/cart/data/repositories/durable_cart_repository.dart';
import 'package:ipr_mobile/features/cart/domain/entities/cart.dart';
import 'package:ipr_mobile/features/cart/domain/entities/cart_line.dart';
import 'package:ipr_mobile/features/cart/domain/entities/cart_validation.dart';
import 'package:ipr_mobile/shared/domain/money.dart';
import 'package:ipr_mobile/shared/domain/price_status.dart';
import 'package:ipr_mobile/shared/domain/stock_status.dart';

import '../../../mocks/fake_http_adapter.dart';
import '../../../mocks/test_clients.dart';
import 'cart_test_support.dart';

CartLine _line(int id, int quantity, {String? imageUrl, String? brand}) =>
    CartLine(
      productId: id,
      quantity: quantity,
      snapshot: CartLineSnapshot.fromProduct(
        productOf(id: id, imageUrl: imageUrl, brand: brand),
      ),
    );

void main() {
  group('TC-040 · AC-049-4 · persistencia ida y vuelta', () {
    test(
      'lo guardado se lee idéntico (líneas, cantidades e instantáneas)',
      () async {
        final store = MemoryDurableStore();
        final repo = DurableCartRepository(store);
        final cart = Cart([
          _line(1, 2, imageUrl: 'https://staging.invalid/a.jpg'),
          _line(2, 5),
          const CartLine(productId: 3, quantity: 99),
        ]);
        await repo.save(cart);
        final read = await DurableCartRepository(store).load();
        expect(read, cart);
        expect(
          read.lineOf(1)!.snapshot!.image!.url,
          'https://staging.invalid/a.jpg',
        );
        expect(read.lineOf(2)!.snapshot!.brandName, isNull);
        expect(read.lineOf(3)!.snapshot, isNull);
      },
    );

    test('un carrito vacío borra la clave', () async {
      final store = MemoryDurableStore();
      final repo = DurableCartRepository(store);
      await repo.save(Cart([_line(1, 1)]));
      expect(store.data, contains(CartStorageCodec.storageKey));
      await repo.save(Cart.empty);
      expect(store.data, isEmpty);
    });

    test('clear() deja el almacén sin la clave', () async {
      final store = MemoryDurableStore();
      final repo = DurableCartRepository(store);
      await repo.save(Cart([_line(1, 1)]));
      await repo.clear();
      expect(store.data, isEmpty);
      expect((await repo.load()).isEmpty, isTrue);
    });

    test('sin nada guardado → carrito vacío', () async {
      expect(
        (await DurableCartRepository(MemoryDurableStore()).load()).isEmpty,
        isTrue,
      );
    });

    test('una clave única y versionada', () {
      expect(CartStorageCodec.storageKey, 'cart.v1');
    });

    test(
      'un fallo de lectura del disco → carrito vacío, sin excepción',
      () async {
        const repo = DurableCartRepository(BrokenDurableStore(failRead: true));
        expect((await repo.load()).isEmpty, isTrue);
      },
    );

    test(
      'un fallo de escritura se traga (el carrito sigue en memoria)',
      () async {
        const repo = DurableCartRepository(BrokenDurableStore(failWrite: true));
        await repo.save(Cart([_line(1, 1)]));
        await repo.save(Cart.empty);
        await repo.clear();
      },
    );
  });

  group('AC-049-7 · AC-029-8 · qué se guarda (sin PII ni totales)', () {
    test('solo ids, cantidades y datos de presentación', () {
      final json = jsonDecode(
        CartStorageCodec.encode(
          Cart([
            _line(
              4521,
              2,
              imageUrl: 'https://staging.invalid/a.jpg',
              brand: 'Copeland',
            ),
          ]),
        ),
      ) as Map<String, dynamic>;
      expect(json.keys, unorderedEquals(['v', 'lines']));
      final line = (json['lines'] as List).single as Map<String, dynamic>;
      expect(line.keys, unorderedEquals(['productId', 'quantity', 'snapshot']));
      expect(line['productId'], 4521);
      expect(line['quantity'], 2);
      final snapshot = line['snapshot'] as Map<String, dynamic>;
      expect(
        snapshot.keys,
        unorderedEquals([
          'name',
          'sku',
          'brand',
          'imageUrl',
          'imageAlt',
          'price',
          'availability',
        ]),
      );
    });

    test(
      'el texto guardado no contiene tokens, correos, totales ni envíos',
      () {
        final text = CartStorageCodec.encode(Cart([_line(1, 3)])).toLowerCase();
        for (final forbidden in [
          'token',
          'bearer',
          'email',
          'correo',
          'total',
          'subtotal',
          'shipping',
          'envio',
          'password',
          'user',
        ]) {
          expect(text.contains(forbidden), isFalse, reason: forbidden);
        }
      },
    );

    test('sin precio se guarda null, nunca 0', () {
      final cart = Cart([
        CartLine(
          productId: 1,
          quantity: 1,
          snapshot: CartLineSnapshot.fromProduct(
            productOf(price: const OnRequest()),
          ),
        ),
      ]);
      final json =
          jsonDecode(CartStorageCodec.encode(cart)) as Map<String, dynamic>;
      final snap =
          ((json['lines'] as List).single as Map<String, dynamic>)['snapshot']
              as Map<String, dynamic>;
      expect(snap['price'], isNull);
      final read = CartStorageCodec.decode(CartStorageCodec.encode(cart));
      expect(read.lines.single.snapshot!.price, isA<OnRequest>());
    });

    test('la disponibilidad se guarda con los valores del contrato', () {
      for (final (stock, text) in [
        (StockStatus.inStock, 'in_stock'),
        (StockStatus.outOfStock, 'out_of_stock'),
        (StockStatus.onBackorder, 'on_backorder'),
        (StockStatus.unknown, 'unknown'),
      ]) {
        final cart = Cart([
          CartLine(
            productId: 1,
            quantity: 1,
            snapshot: CartLineSnapshot.fromProduct(productOf(stock: stock)),
          ),
        ]);
        final encoded = CartStorageCodec.encode(cart);
        expect(encoded, contains('"availability":"$text"'));
        expect(
          CartStorageCodec.decode(encoded).lines.single.snapshot!.availability,
          stock,
        );
      }
    });
  });

  group('datos corruptos → carrito vacío sin crash', () {
    final corrupt = <String, String?>{
      'null': null,
      'cadena vacía': '',
      'no es JSON': 'esto no es json {',
      'JSON truncado': '{"v":1,"lines":[{"productId":1,',
      'una lista': '[1,2,3]',
      'un número': '42',
      'sin versión': '{"lines":[]}',
      'otra versión': '{"v":99,"lines":[{"productId":1,"quantity":1}]}',
      'versión de tipo erróneo': '{"v":"1","lines":[]}',
      'lines no es lista': '{"v":1,"lines":"hola"}',
      'lines nulo': '{"v":1,"lines":null}',
    };
    for (final entry in corrupt.entries) {
      test(entry.key, () async {
        final repo = DurableCartRepository(
          MemoryDurableStore({CartStorageCodec.storageKey: ?entry.value}),
        );
        expect((await repo.load()).isEmpty, isTrue);
      });
    }

    test('las líneas ilegibles se omiten y las buenas se conservan', () {
      const raw =
          '{"v":1,"lines":[1,"x",{"productId":"7","quantity":1},'
          '{"productId":8},{"productId":9,"quantity":2},'
          '{"productId":0,"quantity":1},{"productId":9,"quantity":5}]}';
      final cart = CartStorageCodec.decode(raw);
      expect([for (final l in cart.lines) l.productId], [9]);
      expect(cart.lines.single.quantity, 2);
    });

    test('cantidades fuera de rango se corrigen al leer', () {
      final cart = CartStorageCodec.decode(
        '{"v":1,"lines":[{"productId":1,"quantity":500},{"productId":2,"quantity":0}]}',
      );
      expect(cart.lines.single.quantity, 99);
    });

    test('una instantánea ilegible no pierde la línea', () {
      final cart = CartStorageCodec.decode(
        '{"v":1,"lines":[{"productId":1,"quantity":2,"snapshot":{"name":""}},'
        '{"productId":2,"quantity":1,"snapshot":"x"}]}',
      );
      expect(cart.lineCount, 2);
      expect(cart.lines.every((l) => l.snapshot == null), isTrue);
    });

    test('precio 0 o negativo guardado se lee como "sin precio"', () {
      final cart = CartStorageCodec.decode(
        '{"v":1,"lines":[{"productId":1,"quantity":1,"snapshot":'
        '{"name":"X","sku":"S","price":0,"availability":"in_stock"}},'
        '{"productId":2,"quantity":1,"snapshot":'
        '{"name":"Y","sku":"S","price":-5,"availability":"in_stock"}}]}',
      );
      expect(cart.lines[0].snapshot!.price, isA<OnRequest>());
      expect(cart.lines[1].snapshot!.price, isA<OnRequest>());
    });

    test('una disponibilidad nueva se lee como desconocida', () {
      final cart = CartStorageCodec.decode(
        '{"v":1,"lines":[{"productId":1,"quantity":1,"snapshot":'
        '{"name":"X","price":10,"availability":"preorder"}}]}',
      );
      expect(cart.lines.single.snapshot!.availability, StockStatus.unknown);
      expect(cart.lines.single.snapshot!.sku, '');
    });
  });

  group('TC-044 · mapeo de CartValidation', () {
    test('las 5 situaciones del contrato', () {
      final validation = cartFixture('CartValidation.mixed.json');
      expect(validation.checkoutAllowed, isFalse);
      expect(validation.informativeSubtotal, const Money(2469134));
      expect(validation.lines.map((l) => l.status).toList(), [
        CartLineStatus.available,
        CartLineStatus.outOfStock,
        CartLineStatus.onBackorder,
        CartLineStatus.priceOnRequest,
        CartLineStatus.notFound,
      ]);
      final first = validation.lines.first;
      expect(first.id, 4521);
      expect(first.quantity, 2);
      expect(first.lineSubtotal, const Money(2469134));
      expect(first.product!.name, 'Compresor scroll 24.000 BTU R410A');
      expect(first.product!.brandName, 'Copeland');
      expect(first.product!.price, const Priced(Money(1234567)));
      expect(first.product!.image!.url, startsWith('https://'));
      final onRequest = validation.lines[3];
      expect(onRequest.product!.price, isA<OnRequest>());
      expect(validation.lines.last.product, isNull);
      expect(validation.lines.last.lineSubtotal, isNull);
    });

    test('un status desconocido se trata como no disponible', () {
      final validation = cartFixture('CartValidation.unknown-status.json');
      expect(validation.lines.single.status, CartLineStatus.notFound);
      expect(validation.lines.single.isBlocking, isTrue);
    });

    test('checkoutAllowed ausente o no booleano → false (falla cerrado)', () {
      for (final value in [null, 'true', 1]) {
        final body = {
          'data': {
            'lines': <Object?>[],
            'informativeSubtotal': {'amount': 0},
            'checkoutAllowed': ?value,
          },
        };
        expect(mapCartValidation(body).checkoutAllowed, isFalse);
      }
    });

    test('precio 0 en el producto → "sin precio", nunca "cero pesos"', () {
      final body = cartFixtureBody('CartValidation.all-available.json');
      final data = body['data'] as Map<String, dynamic>;
      final line = (data['lines'] as List).first as Map<String, dynamic>;
      ((line['product'] as Map<String, dynamic>)['price']
              as Map<String, dynamic>)['amount'] =
          0;
      final mapped = mapCartValidation(body);
      expect(mapped.lines.first.product!.price, isA<OnRequest>());
      expect(mapped.lines.first.isPurchasable, isFalse);
    });

    test(
      'un producto ilegible queda sin producto pero no rompe la respuesta',
      () {
        final body = {
          'data': {
            'lines': [
              {'id': 1, 'quantity': 1, 'status': 'available', 'product': 'x'},
              {
                'id': 2,
                'quantity': 1,
                'status': 'available',
                'product': {'id': 2},
              },
            ],
            'informativeSubtotal': {'amount': 10},
            'checkoutAllowed': true,
          },
        };
        final mapped = mapCartValidation(body);
        expect(mapped.lines.every((l) => l.product == null), isTrue);
        expect(mapped.lines.every((l) => l.isBlocking), isTrue);
      },
    );

    test('un subtotal con decimales o negativo no se acepta', () {
      for (final amount in [1500.5, -1, 'x', null]) {
        expect(
          () => mapCartValidation({
            'data': {
              'lines': <Object?>[],
              'informativeSubtotal': {'amount': amount},
              'checkoutAllowed': true,
            },
          }),
          throwsFormatException,
        );
      }
    });

    final malformed = <String, Object?>{
      'null': null,
      'sin data': {'lines': <Object?>[]},
      'data no es objeto': {'data': <Object?>[]},
      'sin lines': {
        'data': {
          'informativeSubtotal': {'amount': 0},
        },
      },
      'sin subtotal': {
        'data': {'lines': <Object?>[]},
      },
      'línea que no es objeto': {
        'data': {
          'lines': ['x'],
          'informativeSubtotal': {'amount': 0},
        },
      },
      'línea sin id': {
        'data': {
          'lines': [
            {'quantity': 1, 'status': 'available'},
          ],
          'informativeSubtotal': {'amount': 0},
        },
      },
      'línea con id 0': {
        'data': {
          'lines': [
            {'id': 0, 'quantity': 1, 'status': 'available'},
          ],
          'informativeSubtotal': {'amount': 0},
        },
      },
    };
    for (final entry in malformed.entries) {
      test('estructura irreconocible (${entry.key}) → FormatException', () {
        expect(() => mapCartValidation(entry.value), throwsFormatException);
      });
    }
  });

  group('TC-044 · AC-050-8 · POST /cart/validate', () {
    ApiCartValidationRepository repo(FakeHttpAdapter adapter) =>
        ApiCartValidationRepository(buildTestClient(adapter: adapter).client);

    test('envía SOLO {id, quantity}: ni precios ni totales (IR-01)', () async {
      final adapter = FakeHttpAdapter([
        (_) => FakeHttpAdapter.json(
          cartFixtureBody('CartValidation.all-available.json'),
        ),
      ]);
      final cart = Cart([_line(4521, 2), _line(4522, 1)]);
      final result = await repo(adapter).validate(cart);

      expect(result, isA<Ok<CartValidation>>());
      expect(adapter.requests, hasLength(1));
      final request = adapter.requests.single;
      expect(request.method, 'POST');
      expect(request.path, endsWith('/cart/validate'));
      final body = request.data as Map<String, dynamic>;
      expect(body.keys, ['items']);
      final items = body['items'] as List<Object?>;
      expect(items, [
        {'id': 4521, 'quantity': 2},
        {'id': 4522, 'quantity': 1},
      ]);
      final sent = jsonEncode(body).toLowerCase();
      for (final forbidden in [
        'price',
        'amount',
        'total',
        'subtotal',
        'name',
      ]) {
        expect(sent.contains(forbidden), isFalse, reason: forbidden);
      }
    });

    test('el cuerpo cumple CartItemsRequest (máx. 100 líneas, 1–99)', () {
      final cart = Cart([
        for (var i = 1; i <= 100; i++) CartLine(productId: i, quantity: 99),
      ]);
      final body = ApiCartValidationRepository.requestBody(cart);
      final items = body['items']! as List<Object?>;
      expect(items, hasLength(100));
      expect(
        items.every(
          (i) => (i! as Map)['quantity'] == 99 && (i as Map).length == 2,
        ),
        isTrue,
      );
    });

    test('no exige sesión (un invitado también revalida)', () async {
      final adapter = FakeHttpAdapter([
        (_) => FakeHttpAdapter.json(
          cartFixtureBody('CartValidation.all-available.json'),
        ),
      ]);
      await repo(adapter).validate(Cart([_line(1, 1)]));
      expect(
        adapter.requests.single.headers.containsKey('Authorization'),
        isFalse,
      );
    });

    test('un carrito vacío no genera petición', () async {
      final adapter = FakeHttpAdapter();
      final result = await repo(adapter).validate(Cart.empty);
      expect(adapter.requests, isEmpty);
      expect(result, isA<Ok<CartValidation>>());
      expect(result.valueOrNull!.checkoutAllowed, isFalse);
    });

    test('devuelve la validación mapeada', () async {
      final adapter = FakeHttpAdapter([
        (_) =>
            FakeHttpAdapter.json(cartFixtureBody('CartValidation.mixed.json')),
      ]);
      final result = await repo(adapter).validate(Cart([_line(4521, 2)]));
      expect(result.valueOrNull!.lines, hasLength(5));
    });

    final failures = <String, (FakeHttpAdapter, Matcher)>{
      '400 validation_failed': (
        FakeHttpAdapter([
          (_) => FakeHttpAdapter.problem(400, 'validation_failed'),
        ]),
        isA<Validation>(),
      ),
      '503': (
        FakeHttpAdapter([
          (_) => FakeHttpAdapter.problem(503, 'service_unavailable'),
        ]),
        isA<ServiceUnavailable>(),
      ),
      'sin red': (
        FakeHttpAdapter([FakeHttpAdapter.connectionError]),
        isA<NoConnection>(),
      ),
      'tiempo agotado': (
        FakeHttpAdapter([FakeHttpAdapter.timeout]),
        isA<RequestTimeout>(),
      ),
      'cuerpo irreconocible': (
        FakeHttpAdapter([
          (_) => FakeHttpAdapter.json({'oops': true}),
        ]),
        isA<ContractFailure>(),
      ),
    };
    for (final entry in failures.entries) {
      test('${entry.key} llega como Err y el POST no se reintenta', () async {
        final (adapter, matcher) = entry.value;
        final result = await repo(adapter).validate(Cart([_line(1, 1)]));
        expect(result.failureOrNull, matcher);
        expect(adapter.requests, hasLength(1));
      });
    }
  });
}
