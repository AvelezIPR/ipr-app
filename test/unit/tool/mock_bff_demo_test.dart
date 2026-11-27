import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/mock_bff/mock_bff.dart';

/// Modo `--demo` del BFF simulado: datos parecidos a los reales que cumplen el
/// contrato (el servidor responde 500 si un cuerpo de demostración no lo
/// cumple, así que un 200 ya implica que el esquema valida).
void main() {
  late HttpServer demo;
  late HttpServer plain;
  late HttpClient http;

  Future<(int, Map<String, dynamic>)> get(
    HttpServer server,
    String path,
  ) async {
    final request = await http.getUrl(
      Uri.parse('http://127.0.0.1:${server.port}/mobile/v1$path'),
    );
    request.headers
      ..set('X-App-Version', '1.0.0')
      ..set('X-App-Platform', 'android');
    final response = await request.close();
    final text = await utf8.decoder.bind(response).join();
    return (response.statusCode, jsonDecode(text) as Map<String, dynamic>);
  }

  List<Map<String, dynamic>> dataOf(Map<String, dynamic> body) =>
      (body['data'] as List<dynamic>).cast<Map<String, dynamic>>();

  setUpAll(() async {
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
    test('8 categorías raíz con los nombres de la web', () async {
      final (status, body) = await get(demo, '/categories');
      expect(status, 200);
      expect(dataOf(body).map((c) => c['name']), [
        'Aire Acondicionado',
        'Refrigeración',
        'Eléctricos',
        'Materiales y Consumibles',
        'Herramientas',
        'Tableros y Controles',
        'Ventilación',
        'Refrigerantes',
      ]);
      expect(dataOf(body).every((c) => c['parentId'] == null), isTrue);
    });

    test('marcas con página propia', () async {
      final (status, body) = await get(demo, '/brands');
      expect(status, 200);
      final brands = dataOf(body);
      expect(brands.length, greaterThan(10));
      expect(brands.every((b) => b['hasLanding'] == true), isTrue);
      expect(brands.map((b) => b['slug']), contains('fullgauge'));
    });

    test('sedes: 31 abiertas en 9 ciudades y Cartagena por abrir', () async {
      final (status, body) = await get(demo, '/stores');
      expect(status, 200);
      final stores = dataOf(body);
      final open = stores.where((s) => s['upcoming'] == false).toList();
      expect(open, hasLength(31));
      expect(open.map((s) => s['city']).toSet(), hasLength(9));
      final upcoming = stores.where((s) => s['upcoming'] == true).single;
      expect(upcoming['city'], 'Cartagena');
    });

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
        '/products?category=aire-acondicionado',
      );
      expect(
        dataOf(byCategory).every(
          (p) => (p['categorySlugs'] as List<dynamic>).contains(
            'aire-acondicionado',
          ),
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

    test(
      '/config trae la portada de la web: campañas, cifras y bloques',
      () async {
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
        expect(home['highlights'] as List<dynamic>, hasLength(2));
      },
    );

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

    test(
      'landings de marca (W3-01): Daikin, Samsung y Midea; otra marca, 404',
      () async {
        for (final slug in ['daikin', 'samsung', 'midea']) {
          final (status, body) = await get(demo, '/brands/$slug');
          expect(status, 200, reason: slug);
          final data = body['data'] as Map<String, dynamic>;
          expect(data['slug'], slug);
          final types = (data['blocks'] as List<dynamic>)
              .cast<Map<String, dynamic>>()
              .map((b) => b['type']);
          expect(types, containsAll(<String>['hero', 'faq', 'cta']));
        }
        final (missing, _) = await get(demo, '/brands/no-existe');
        expect(missing, 404);
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

  test(
    'sin --demo sigue sirviendo los ejemplos sintetizados del contrato',
    () async {
      final (status, body) = await get(plain, '/categories');
      expect(status, 200);
      expect(dataOf(body).single['name'], 'ejemplo');
    },
  );
}
