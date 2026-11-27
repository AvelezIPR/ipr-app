import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/network/uuid_v4.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/brand_landing.dart';

import '../../../tool/contract/openapi_contract.dart';
import '../../../tool/mock_bff/mock_bff.dart';

/// Modo `--demo` del BFF simulado: datos parecidos a los reales que cumplen el
/// contrato (el servidor responde 500 si un cuerpo de demostración no lo
/// cumple, así que un 200 ya implica que el esquema valida).
void main() {
  late HttpServer demo;
  late HttpServer plain;
  late HttpClient http;
  late OpenApiContract contract;

  Future<(int, Map<String, dynamic>)> get(
    HttpServer server,
    String path, {
    Map<String, String> headers = const {},
  }) async {
    final request = await http.getUrl(
      Uri.parse('http://127.0.0.1:${server.port}/mobile/v1$path'),
    );
    request.headers
      ..set('X-App-Version', '1.0.0')
      ..set('X-App-Platform', 'android');
    headers.forEach(request.headers.set);
    final response = await request.close();
    final text = await utf8.decoder.bind(response).join();
    return (response.statusCode, jsonDecode(text) as Map<String, dynamic>);
  }

  Future<(int, Map<String, dynamic>)> sendJson(
    HttpServer server,
    String method,
    String path,
    Map<String, dynamic> payload, {
    Map<String, String> headers = const {},
  }) async {
    final request = await http.openUrl(
      method,
      Uri.parse('http://127.0.0.1:${server.port}/mobile/v1$path'),
    );
    request.headers
      ..set('X-App-Version', '1.0.0')
      ..set('X-App-Platform', 'android')
      ..set('Content-Type', 'application/json');
    headers.forEach(request.headers.set);
    request.add(utf8.encode(jsonEncode(payload)));
    final response = await request.close();
    final text = await utf8.decoder.bind(response).join();
    return (response.statusCode, jsonDecode(text) as Map<String, dynamic>);
  }

  List<Map<String, dynamic>> dataOf(Map<String, dynamic> body) =>
      (body['data'] as List<dynamic>).cast<Map<String, dynamic>>();

  setUpAll(() async {
    contract = OpenApiContract.load('contract/openapi.yaml');
    demo = await startMockBff(demo: true);
    plain = await startMockBff();
    http = HttpClient();
  });
  tearDownAll(() async {
    http.close(force: true);
    await demo.close(force: true);
    await plain.close(force: true);
  });

  group('--demo · categorías, marcas y sedes', () {
    test('3 ramas principales con subcategorías anidadas, productCount y filtros', () async {
      final (status, body) = await get(demo, '/categories');
      expect(status, 200);
      final roots = dataOf(body);
      expect(roots.map((c) => c['name']), [
        'Aire Acondicionado',
        'Refrigeración',
        'Ventilación',
      ]);
      expect(roots.map((c) => c['slug']), [
        'aire-acondicionado',
        'refrigeracion',
        'ventilacion',
      ]);
      expect(roots.every((c) => c['parentId'] == null), isTrue);

      void verifyProductCount(List<Map<String, dynamic>> nodes) {
        for (final node in nodes) {
          expect(node['productCount'], isA<int>());
          expect(node['productCount'] as int, greaterThanOrEqualTo(0));
          final children = (node['children'] as List<dynamic>)
              .cast<Map<String, dynamic>>();
          verifyProductCount(children);
        }
      }

      verifyProductCount(roots);

      final aire = roots.firstWhere((c) => c['slug'] == 'aire-acondicionado');
      final aireChildren = (aire['children'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(
        aireChildren.map((c) => c['slug']),
        containsAll(<String>[
          'repuestos-aa',
          'tuberia-accesorios-capilares',
          'tableros-y-controles',
        ]),
      );
      expect(aireChildren.every((c) => c['parentId'] == aire['id']), isTrue);

      final refri = roots.firstWhere((c) => c['slug'] == 'refrigeracion');
      final refriChildren = (refri['children'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(
        refriChildren.map((c) => c['slug']),
        containsAll(<String>['herramientas', 'refrigerantes']),
      );
      expect(refriChildren.every((c) => c['parentId'] == refri['id']), isTrue);

      // Filtrar por la rama padre incluye productos de sus subcategorías.
      final (aireStatus, aireProducts) = await get(
        demo,
        '/products?category=aire-acondicionado&perPage=24',
      );
      expect(aireStatus, 200);
      final aireSlugs = dataOf(aireProducts)
          .expand((p) => (p['categorySlugs'] as List<dynamic>).cast<String>())
          .toSet();
      expect(
        aireSlugs,
        containsAll(<String>[
          'aire-acondicionado',
          'tuberia-accesorios-capilares',
          'tableros-y-controles',
        ]),
      );
      expect(aireSlugs, isNot(contains('herramientas')));

      // Filtrar por una subcategoría devuelve solo esa subcategoría.
      final (toolsStatus, toolsProducts) = await get(
        demo,
        '/products?category=herramientas',
      );
      expect(toolsStatus, 200);
      final tools = dataOf(toolsProducts);
      expect(tools, isNotEmpty);
      expect(
        tools.every(
          (p) => (p['categorySlugs'] as List<dynamic>).contains('herramientas'),
        ),
        isTrue,
      );

      // La ficha de producto de una subcategoría responde 200 con su categoría.
      final subSlug = tools.first['slug'] as String;
      final (detailStatus, detailBody) = await get(demo, '/products/$subSlug');
      expect(detailStatus, 200);
      final detailData = detailBody['data'] as Map<String, dynamic>;
      final detailCategories = (detailData['categories'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(detailCategories.map((c) => c['slug']), contains('herramientas'));
    });

    test('marcas con página propia', () async {
      final (status, body) = await get(demo, '/brands');
      expect(status, 200);
      final brands = dataOf(body);
      expect(brands.length, greaterThan(10));
      expect(brands.every((b) => b['hasLanding'] == true), isTrue);
      final slugs = brands.map((b) => b['slug']).toList();
      expect(slugs, containsAll(<String>['fullgauge', 'fiberglass', 'ipr']));
    });

    test(
      'sedes: 31 abiertas en 9 ciudades con datos reales y Cartagena por abrir',
      () async {
        final (status, body) = await get(demo, '/stores');
        expect(status, 200);
        final stores = dataOf(body);
        final open = stores.where((s) => s['upcoming'] == false).toList();
        expect(open, hasLength(31));
        expect(open.map((s) => s['city']).toSet(), hasLength(9));
        expect(
          open.every(
            (s) =>
                (s['address'] as String).isNotEmpty &&
                s['address'] != 'Dirección por confirmar' &&
                (s['phones'] as List<dynamic>).isNotEmpty &&
                s['whatsapp'] != null &&
                s['imageUrl'] != null,
          ),
          isTrue,
        );
        final upcoming = stores.where((s) => s['upcoming'] == true).single;
        expect(upcoming['city'], 'Cartagena');
      },
    );

    test('/config enciende la calculadora de BTU', () async {
      final (status, body) = await get(demo, '/config');
      expect(status, 200);
      final data = body['data'] as Map<String, dynamic>;
      expect(
        (data['features'] as Map<String, dynamic>)['btuCalculatorEnabled'],
        isTrue,
      );
    });
  });

  group('--demo · productos y búsqueda', () {
    test('listado por popularidad: precio, SKU y paginación', () async {
      final (status, body) = await get(demo, '/products?sort=popularity');
      expect(status, 200);
      final products = dataOf(body);
      expect(products, isNotEmpty);
      final meta = body['meta'] as Map<String, dynamic>;
      expect(meta['total'], greaterThanOrEqualTo(products.length));
      expect(products.first['sku'], matches(RegExp(r'^\d{3}-\d{4}$')));
      expect(
        (products.first['price'] as Map<String, dynamic>)['status'],
        'priced',
      );
    });

    test('filtra por categoría y marca', () async {
      final (_, byCategory) = await get(
        demo,
        '/products?category=aire-acondicionado&perPage=24',
      );
      const aireTreeSlugs = {
        'aire-acondicionado',
        'tuberia-accesorios-capilares',
        'repuestos-aa',
        'tableros-y-controles',
      };
      expect(dataOf(byCategory), isNotEmpty);
      expect(
        dataOf(byCategory).every(
          (p) =>
              (p['categorySlugs'] as List<dynamic>).any(aireTreeSlugs.contains),
        ),
        isTrue,
      );
      final (_, byBrand) = await get(demo, '/products?brand=uniweld');
      expect(
        dataOf(byBrand).every(
          (p) => (p['brand'] as Map<String, dynamic>)['slug'] == 'uniweld',
        ),
        isTrue,
      );
    });

    test('ordena por precio ascendente y descendente', () async {
      num amount(Map<String, dynamic> p) =>
          (p['price'] as Map<String, dynamic>)['amount'] as num;
      final (_, asc) = await get(demo, '/products?sort=price-asc&perPage=24');
      final (_, desc) = await get(demo, '/products?sort=price-desc&perPage=24');
      final up = dataOf(asc).map(amount).toList();
      expect(up, orderedEquals([...up]..sort()));
      expect(dataOf(desc).map(amount).toList(), orderedEquals(up.reversed));
    });

    test('pagina con perPage=12 sin repetir ni perder productos', () async {
      final (_, page1) = await get(demo, '/products?perPage=12&page=1');
      final (_, page2) = await get(demo, '/products?perPage=12&page=2');
      final meta = page1['meta'] as Map<String, dynamic>;
      final total = meta['total'] as int;
      expect(dataOf(page1).length + dataOf(page2).length, total);
      final ids = [...dataOf(page1), ...dataOf(page2)].map((p) => p['id']);
      expect(ids.toSet(), hasLength(total));
    });

    test('búsqueda sin tildes ni mayúsculas', () async {
      final (status, body) = await get(demo, '/search?q=VACUOMETRO');
      expect(status, 200);
      expect(dataOf(body), isNotEmpty);
      expect(
        dataOf(body).every((p) => (p['name'] as String).contains('Vacuómetro')),
        isTrue,
      );
      expect((body['meta'] as Map<String, dynamic>)['query'], 'VACUOMETRO');
    });

    test('búsqueda sin coincidencias: lista vacía (no error)', () async {
      final (status, body) = await get(demo, '/search?q=zzzxxyy');
      expect(status, 200);
      expect(dataOf(body), isEmpty);
    });

    test('filtros de una categoría: marca y atributos que existen', () async {
      final (status, body) = await get(
        demo,
        '/filters?category=aire-acondicionado',
      );
      expect(status, 200);
      final dims = dataOf(body);
      expect(dims.map((d) => d['key']), contains('brand'));
      final btu = dims.firstWhere((d) => d['key'] == 'attr[pa_capacidad-btu]');
      expect(btu['label'], 'Capacidad BTU');
      expect(
        (btu['options'] as List<dynamic>).cast<Map<String, dynamic>>().map(
          (o) => o['value'],
        ),
        ['12000'],
      );
    });

    test('un filtro de atributo reduce el listado', () async {
      final (_, all) = await get(demo, '/products?perPage=24');
      final (status, filtered) = await get(
        demo,
        '/products?perPage=24&attr[pa_voltaje]=110/220V',
      );
      expect(status, 200);
      expect(dataOf(filtered), isNotEmpty);
      expect(dataOf(filtered).length, lessThan(dataOf(all).length));
      expect(
        dataOf(filtered)
            .every((p) => (p['name'] as String).contains('110/220')),
        isTrue,
      );
    });

    test('ficha de producto conocida y 404 para un slug desconocido', () async {
      final (_, list) = await get(demo, '/products');
      final slug = dataOf(list).first['slug'] as String;
      final (status, detail) = await get(demo, '/products/$slug');
      expect(status, 200);
      final data = detail['data'] as Map<String, dynamic>;
      expect(data['slug'], slug);
      expect(data['webUrl'], 'https://iprpartesyrepuestos.com/producto/$slug');

      final (missing, _) = await get(demo, '/products/no-existe');
      expect(missing, 404);
    });

    test(
      'producto variable (W1-01): tarjeta "Desde" y ficha con variaciones',
      () async {
        const slug = 'desincrustante-alfa-coil-cleaner-con-rinse';
        final (_, found) = await get(demo, '/search?q=alfa%20coil');
        final card = dataOf(found).single;
        expect(card['slug'], slug);
        expect(card['hasVariants'], isTrue);
        expect(card['priceFrom'], 8200);
        expect(card['purchasable'], isFalse);

        final (status, detail) = await get(demo, '/products/$slug');
        expect(status, 200);
        final data = detail['data'] as Map<String, dynamic>;
        final axes = data['variantAxes'] as List<dynamic>;
        expect((axes.single as Map<String, dynamic>)['name'], 'Volumen');
        final variants = (data['variants'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        // Máximo por línea de demostración en el galón (W1-06).
        expect(variants.map((v) => v['maxQuantity']), [null, null, 3]);
        expect(variants.map((v) => v['sku']), [
          '470-0001',
          '470-0003',
          '470-0002',
        ]);
        expect(
          variants.map((v) => (v['price'] as Map<String, dynamic>)['amount']),
          [8200, 12500, 31000],
        );
      },
    );

    test('/config trae la portada de la web: campañas, cifras con target y 4 bloques', () async {
      final (status, body) = await get(demo, '/config');
      expect(status, 200);
      final home =
          (body['data'] as Map<String, dynamic>)['home']
              as Map<String, dynamic>;
      final banners = (home['banners'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(banners.map((b) => b['id']), [
        'jugada-samsung',
        'parche-midea',
        'fiberglass',
        'equipo-ingenieria',
        'addi',
      ]);
      final stats = (home['stats'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(stats.first['value'], '+30');
      final branches = stats.firstWhere((s) => s['id'] == 'branches');
      expect(branches['value'], '31');
      expect(branches['target'], {'kind': 'branches'});
      final references = stats.firstWhere((s) => s['id'] == 'references');
      expect(references['target'], {
        'kind': 'category',
        'ref': 'aire-acondicionado',
      });

      final highlights = (home['highlights'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(highlights.length, greaterThan(2));
      expect(highlights.map((h) => h['id']), [
        'engineering',
        'training',
        'rse',
        'promotions',
      ]);
    });

    test(
      '/config trae el equipo de ingeniería por especialidad (W3-02)',
      () async {
        final (status, body) = await get(demo, '/config');
        expect(status, 200);
        final engineering =
            ((body['data'] as Map<String, dynamic>)['contact']
                    as Map<String, dynamic>)['engineering']
                as Map<String, dynamic>;
        final specialties = (engineering['specialties'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        expect(specialties.map((s) => s['id']), ['aire', 'refrigeracion']);
        final refri = (specialties.last['contacts'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        expect(refri.map((c) => c['city']), [
          'Medellín',
          'Cali',
          'Montería',
          'Bogotá',
          'Bucaramanga',
        ]);
      },
    );

    test('landings de marca (W3-01): las 12 marcas dedicadas responden 200; otra marca, 404', () async {
      const dedicated = [
        'daikin',
        'samsung',
        'midea',
        'gree',
        'hisense',
        'trane',
        'rowa',
        'danfoss',
        'aspen',
        'fullgauge',
        'elitech',
        'ipr',
      ];
      for (final slug in dedicated) {
        final (status, body) = await get(demo, '/brands/$slug');
        expect(status, 200, reason: slug);
        final data = body['data'] as Map<String, dynamic>;
        expect(data['slug'], slug);
        final blocks = (data['blocks'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        final types = blocks.map((b) => b['type']);
        expect(
          types,
          containsAll(<String>['hero', 'faq', 'cta']),
          reason: slug,
        );
        final accent = blocks.first['accentColor'] as String?;
        if (slug == 'midea') {
          expect(BrandAccent.tryParse(accent), isNull);
        } else {
          expect(BrandAccent.tryParse(accent), isNotNull, reason: slug);
        }
      }
      final (missing, _) = await get(demo, '/brands/no-existe');
      expect(missing, 404);
    });

    test(
      'liquidaciones y onSale=true devuelven productos reales con descuento',
      () async {
        final (status, body) = await get(demo, '/liquidaciones');
        expect(status, 200);
        final products = dataOf(body);
        expect(products.length, greaterThanOrEqualTo(3));
        for (final p in products) {
          final price = p['price'] as Map<String, dynamic>;
          expect(price['onSale'], isTrue);
          expect(
            (price['regularAmount'] as num) > (price['amount'] as num),
            isTrue,
          );
          expect(price['discountPercent'] as int, greaterThan(0));
        }
        final (saleStatus, saleBody) = await get(demo, '/products?onSale=true');
        expect(saleStatus, 200);
        expect(dataOf(saleBody).length, products.length);
      },
    );

    test(
      'GET /orders y GET /orders/{id} en --demo validan y usan COP',
      () async {
        final authHeaders = {
          'Authorization': 'Bearer ipra_${'A' * 43}',
          'X-Device-Id': uuidV4(),
        };
        final (status, body) = await get(demo, '/orders', headers: authHeaders);
        expect(status, 200);
        final orders = dataOf(body);
        expect(orders, isNotEmpty);
        for (final order in orders) {
          expect(order['currency'], 'COP');
          expect(
            contract.validate(order, contract.schema('OrderSummary')),
            isEmpty,
          );
        }

        final firstId = orders.first['id'];
        final (detailStatus, detailBody) = await get(
          demo,
          '/orders/$firstId',
          headers: authHeaders,
        );
        expect(detailStatus, 200);
        expect(
          contract.validate(detailBody['data'], contract.schema('OrderDetail')),
          isEmpty,
        );

        final (missingStatus, _) = await get(
          demo,
          '/orders/999999',
          headers: authHeaders,
        );
        expect(missingStatus, 404);
      },
    );

    test('un producto simple no trae variaciones', () async {
      final (_, list) = await get(demo, '/products?category=herramientas');
      final slug = dataOf(list).first['slug'] as String;
      final (_, detail) = await get(demo, '/products/$slug');
      final data = detail['data'] as Map<String, dynamic>;
      expect(data.containsKey('variants'), isFalse);
      expect(dataOf(list).first.containsKey('hasVariants'), isFalse);
    });
  });

  group(
    '--demo · paridad E2E (config, sugerencias, carrito, checkout, cuenta)',
    () {
      test(
        '/config trae contacto real, allowedHosts de IPR y avisos en español',
        () async {
          final (status, body) = await get(demo, '/config');
          expect(status, 200);
          final data = body['data'] as Map<String, dynamic>;
          expect(
            contract.validate(data, contract.schema('AppConfig')),
            isEmpty,
          );

          final contact = data['contact'] as Map<String, dynamic>;
          final phone = contact['phone'] as Map<String, dynamic>;
          expect(phone['display'], '(604) 322 23 23');
          expect(phone['dial'], '+576043222323');
          expect(contact['salesEmail'], 'ventas@iprpartesyrepuestos.com');
          expect(
            contact['pqrsEmail'],
            'servicioalcliente@iprpartesyrepuestos.com',
          );

          final whatsapp = contact['whatsapp'] as Map<String, dynamic>;
          expect(whatsapp['number'], '573014021882');
          expect(whatsapp['defaultMessage'], isNot('ejemplo'));

          final checkout = data['checkout'] as Map<String, dynamic>;
          expect(
            checkout['allowedHosts'],
            containsAll(<String>[
              'iprpartesyrepuestos.com',
              'ipr.iprpartesyrepuestos.com',
            ]),
          );
          expect(checkout['returnPathPrefix'], '/app/pedido');

          final notices = data['notices'] as Map<String, dynamic>;
          expect(notices['shipping'], isNot('ejemplo'));
          expect(notices['warranty'], isNot('ejemplo'));
          expect(notices['priceOnRequest'], isNot('ejemplo'));
        },
      );

      test(
        'GET /search/suggestions devuelve coincidencias con precio COP',
        () async {
          final (status, body) = await get(demo, '/search/suggestions?q=full');
          expect(status, 200);
          final data = body['data'] as Map<String, dynamic>;
          expect(data['query'], 'full');
          expect(data['total'] as int, greaterThan(0));
          final items = (data['items'] as List<dynamic>)
              .cast<Map<String, dynamic>>();
          expect(items, isNotEmpty);
          expect(items.length, lessThanOrEqualTo(6));
          for (final item in items) {
            expect(
              contract.validate(item, contract.schema('Suggestion')),
              isEmpty,
            );
            expect((item['price'] as Map<String, dynamic>)['currency'], 'COP');
            expect(item['brandName'], 'Full Gauge');
          }

          // También funciona sin tildes ni mayúsculas.
          final (accentStatus, accentBody) = await get(
            demo,
            '/search/suggestions?q=VACUOMETRO',
          );
          expect(accentStatus, 200);
          final accentItems =
              ((accentBody['data'] as Map<String, dynamic>)['items']
                      as List<dynamic>)
                  .cast<Map<String, dynamic>>();
          expect(
            accentItems.any(
              (s) => (s['name'] as String).contains('Vacuómetro'),
            ),
            isTrue,
          );
        },
      );

      test(
        'POST /cart/validate valida simple + variación, subtotal COP y topes',
        () async {
          final headers = {'X-Device-Id': uuidV4()};

          // Producto simple (104: 541.000) + variación "1 galón" (4702: 31.000 * 2).
          final (status, body) = await sendJson(
            demo,
            'POST',
            '/cart/validate',
            {
              'items': [
                {'id': 104, 'quantity': 1},
                {'id': 4702, 'quantity': 2},
              ],
            },
            headers: headers,
          );
          expect(status, 200);
          final data = body['data'] as Map<String, dynamic>;
          expect(
            contract.validate(data, contract.schema('CartValidation')),
            isEmpty,
          );
          expect(data['checkoutAllowed'], isTrue);
          final subtotal = data['informativeSubtotal'] as Map<String, dynamic>;
          expect(subtotal['currency'], 'COP');
          expect(subtotal['amount'], 541000 + 31000 * 2);

          final lines = (data['lines'] as List<dynamic>)
              .cast<Map<String, dynamic>>();
          expect(lines, hasLength(2));
          expect(lines.every((l) => l['status'] == 'available'), isTrue);
          final variantProduct = lines[1]['product'] as Map<String, dynamic>;
          expect(variantProduct['variantLabel'], '1 galón');
          expect(variantProduct['maxQuantity'], 3);

          // Superar maxQuantity: 3 bloquea el checkout.
          final (overStatus, overBody) = await sendJson(
            demo,
            'POST',
            '/cart/validate',
            {
              'items': [
                {'id': 4702, 'quantity': 4},
              ],
            },
            headers: headers,
          );
          expect(overStatus, 200);
          expect(
            (overBody['data'] as Map<String, dynamic>)['checkoutAllowed'],
            isFalse,
          );

          // ID inexistente o padre variable devuelve not_found y checkoutAllowed: false.
          final (missingStatus, missingBody) = await sendJson(
            demo,
            'POST',
            '/cart/validate',
            {
              'items': [
                {'id': 999999, 'quantity': 1},
                {'id': 140, 'quantity': 1},
              ],
            },
            headers: headers,
          );
          expect(missingStatus, 200);
          final missingData = missingBody['data'] as Map<String, dynamic>;
          expect(missingData['checkoutAllowed'], isFalse);
          final missingLines = (missingData['lines'] as List<dynamic>)
              .cast<Map<String, dynamic>>();
          expect(missingLines.every((l) => l['status'] == 'not_found'), isTrue);
        },
      );

      test('POST /checkout y GET /checkout/{ref} cumplen contrato con host IPR y orden COP', () async {
        final authHeaders = {
          'Authorization': 'Bearer ipra_${'A' * 43}',
          'X-Device-Id': uuidV4(),
          'Idempotency-Key': uuidV4(),
        };
        final (postStatus, postBody) = await sendJson(
          demo,
          'POST',
          '/checkout',
          {
            'items': [
              {'id': 104, 'quantity': 1},
            ],
          },
          headers: authHeaders,
        );
        expect(postStatus, 201);
        final session = postBody['data'] as Map<String, dynamic>;
        expect(
          contract.validate(session, contract.schema('CheckoutSession')),
          isEmpty,
        );
        expect(
          Uri.parse(session['checkoutUrl'] as String).host,
          'iprpartesyrepuestos.com',
        );
        expect(session['allowedHosts'], contains('iprpartesyrepuestos.com'));

        final ref = session['checkoutRef'] as String;
        final (getStatus, getBody) = await get(
          demo,
          '/checkout/$ref',
          headers: {
            'Authorization': 'Bearer ipra_${'A' * 43}',
            'X-Device-Id': uuidV4(),
          },
        );
        expect(getStatus, 200);
        final statusData = getBody['data'] as Map<String, dynamic>;
        expect(
          contract.validate(statusData, contract.schema('CheckoutStatus')),
          isEmpty,
        );
        expect(statusData['checkoutRef'], ref);
        expect(statusData['state'], 'order_created');
        final order = statusData['order'] as Map<String, dynamic>;
        expect(order['currency'], 'COP');
      });

      test('GET /me, PATCH /me y POST /auth/login devuelven perfil colombiano válido', () async {
        final authHeaders = {
          'Authorization': 'Bearer ipra_${'A' * 43}',
          'X-Device-Id': uuidV4(),
        };

        final (meStatus, meBody) = await get(demo, '/me', headers: authHeaders);
        expect(meStatus, 200);
        final me = meBody['data'] as Map<String, dynamic>;
        expect(contract.validate(me, contract.schema('UserProfile')), isEmpty);
        expect(me['displayName'], 'Carlos Ramírez');
        final billing = me['billing'] as Map<String, dynamic>;
        expect(billing['department'], 'ANT');
        expect(billing['city'], 'Medellín');

        final (patchStatus, patchBody) = await sendJson(demo, 'PATCH', '/me', {
          'firstName': 'Ana',
          'lastName': 'Gómez',
        }, headers: authHeaders);
        expect(patchStatus, 200);
        final patched = patchBody['data'] as Map<String, dynamic>;
        expect(
          contract.validate(patched, contract.schema('UserProfile')),
          isEmpty,
        );
        expect(patched['displayName'], 'Ana Gómez');

        final (loginStatus, loginBody) = await sendJson(
          demo,
          'POST',
          '/auth/login',
          {'login': 'carlos.ramirez@inverprimos.test', 'password': 'secret'},
          headers: {'X-Device-Id': uuidV4()},
        );
        expect(loginStatus, 200);
        expect(
          contract.validate(loginBody, contract.schema('AuthSessionResponse')),
          isEmpty,
        );
        final loginUser =
            (loginBody['data'] as Map<String, dynamic>)['user']
                as Map<String, dynamic>;
        expect(loginUser['displayName'], 'Carlos Ramírez');
        expect(
          (loginUser['shipping'] as Map<String, dynamic>)['department'],
          'ANT',
        );
      });
    },
  );

  test(
    'sin --demo sigue sirviendo los ejemplos sintetizados del contrato',
    () async {
      final (status, body) = await get(plain, '/categories');
      expect(status, 200);
      expect(dataOf(body).single['name'], 'ejemplo');
    },
  );
}
