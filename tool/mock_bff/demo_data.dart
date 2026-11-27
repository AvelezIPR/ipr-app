// Datos de DEMOSTRACIÓN para el BFF simulado (`--demo`).
//
// Solo para previsualizar la app con contenido parecido al real; NO son el
// catálogo ni el inventario vigentes de IPR y no sustituyen al BFF real.
//
// Origen: nombres de categorías, marcas, productos (nombre, SKU, precio e
// imagen) y sedes (ciudades y nombres) tomados de la web pública
// iprpartesyrepuestos.com el 2026-11-23. Las direcciones solo están donde la
// web las publica en el índice de sedes (Medellín); el resto queda
// "Dirección por confirmar". Nada de esto se incrusta en la app: solo lo sirve
// este servidor de desarrollo, y cada respuesta se valida contra el contrato.
//
// Las URL de imagen son las reales, pero la app de desarrollo solo carga
// imágenes de `mediaHosts` (`dev.invalid`, SC-043) y, además, ese servidor no
// permite CORS desde `localhost`: en la vista web se ve el marcador de
// posición. Se verán al apuntar `mediaHosts` a `ipr.iprpartesyrepuestos.com`
// en una build móvil.
import 'dart:convert';
import 'dart:math' as math;

typedef Json = Map<String, dynamic>;

const _site = 'https://iprpartesyrepuestos.com';
const _media = 'https://ipr.iprpartesyrepuestos.com/wp-content/uploads';

final class _Category {
  const new(this.id, this.slug, this.name);

  final int id;
  final String slug;
  final String name;
}

/// Nodo del árbol de subcategorías de demostración: un nombre, con hijos y
/// slug opcional (`_Node('Mini splits')` / `_Node('Eléctricos', const [], 'repuestos-aa')`).
final class _Node {
  const new(this.name, [this.children = const [], this.slug]);

  final String name;
  final List<_Node> children;
  final String? slug;
}

/// Subcategorías de las tres divisiones, con los nombres y el orden del
/// índice de productos de la web pública (primeros niveles, no todo el árbol).
/// Los slugs se derivan del nombre y NO son los reales de WooCommerce.
const _subcategories = <String, List<_Node>>{
  'aire-acondicionado': [
    _Node('Equipos de aire acondicionado', [
      _Node('Aires portátiles'),
      _Node('Mini splits'),
      _Node('Multi splits'),
      _Node('Sistemas tipo cassette inverter'),
      _Node('Sistemas tipo piso techo inverter'),
      _Node('Condensadoras convencionales'),
      _Node('Evaporadoras convencionales', [
        _Node('Cassettes'),
        _Node('Piso techo'),
        _Node('Fan coil'),
        _Node('Manejadora de aire'),
      ]),
      _Node('Aires tipo paquetes', [
        _Node('Condensado por aire'),
        _Node('Condensado por agua'),
      ]),
      _Node('Chillers'),
      _Node('Sistemas VRV'),
    ]),
    _Node('Tubería - accesorios - capilares', [
      _Node('Accesorios de cobre y bronce', [
        _Node('Bronce', [
          _Node('Tapón macho'),
          _Node('Tuerca'),
          _Node('Unión'),
        ]),
        _Node('Cobre', [_Node('Adaptadores'), _Node('Codos'), _Node('Tee')]),
      ]),
      _Node('Capilares'),
      _Node('Tubería de cobre flexible'),
    ]),
    _Node('Aislantes - paneles - ductos', [
      _Node('Duct wrap'),
      _Node('Cintas', [_Node('Cintas aislantes'), _Node('Cintas de aluminio')]),
      _Node('Rubatex'),
      _Node('Ductos'),
    ]),
    _Node('Termostatos'),
    _Node('Eléctricos', [], 'repuestos-aa'),
    _Node('Tableros y Controles', [], 'tableros-y-controles'),
  ],
  'refrigeracion': [
    _Node('Unidades condensadoras', [
      _Node('Unidades condensadoras scroll'),
      _Node('Unidades condensadoras semihermeticas'),
      _Node('Unidades condensadoras reciprocantes'),
    ]),
    _Node('Evaporadores y difusores', [
      _Node('Evaporadores estáticos'),
      _Node('Evaporadores baja silueta'),
      _Node('Evaporadores media silueta'),
    ]),
    _Node('Compresores de refrigeración', [
      _Node('Compresores reciprocantes'),
      _Node('Compresores scroll de refrigeración'),
      _Node('Compresores semihermeticos'),
    ]),
    _Node('Herramientas'),
    _Node('Refrigerantes', [], 'refrigerantes'),
  ],
  'ventilacion': [
    _Node('Ventiladores', [
      _Node('Helicocentrífugos'),
      _Node('Cajas de ventilación'),
    ]),
    _Node('Extractores', [
      _Node('Extractores de baño'),
      _Node('Extractores tipo hongo'),
      _Node('Extractores helicoidales'),
    ]),
    _Node('Cortinas de aire', [_Node('Comerciales'), _Node('Industriales')]),
  ],
};

const _categories = [
  _Category(1, 'aire-acondicionado', 'Aire Acondicionado'),
  _Category(2, 'refrigeracion', 'Refrigeración'),
  _Category(3, 'ventilacion', 'Ventilación'),
];

/// Marcas con página propia (slug → nombre).
const _brands = {
  'ipr': 'IPR',
  'daikin': 'Daikin',
  'danfoss': 'Danfoss',
  'copeland': 'Copeland',
  'samsung': 'Samsung',
  'midea': 'Midea',
  'gree': 'Gree',
  'hisense': 'Hisense',
  'embraco': 'Embraco',
  'fiberglass': 'Fiberglass',
  'fullgauge': 'Full Gauge',
  'elitech': 'Elitech',
  'rowa': 'Rowa',
  'trane': 'Trane',
  'soler-y-palau': 'Soler & Palau',
  'uniweld': 'Uniweld',
  'aspen': 'Aspen',
  'chint': 'Chint',
  'clearway': 'Clearway',
  'dorin': 'Dorin',
  'elgin': 'Elgin',
  'harris': 'Harris',
  'honeywell': 'Honeywell',
  'mastercool': 'Mastercool',
  'siccom': 'Siccom',
  'tecumseh': 'Tecumseh',
  'ziehl-abegg': 'Ziehl-Abegg',
};

final class _Product {
  const new({
    required this.id,
    required this.slug,
    required this.name,
    required this.sku,
    required this.amount,
    required this.category,
    this.regularAmount,
    this.brand,
    this.image,
    this.purchasable = true,
    this.attributes = const {},
    this.axis,
    this.variants = const [],
  });

  final int id;
  final String slug;
  final String name;
  final String sku;
  final int amount;
  final int? regularAmount;
  final String category;
  final String? brand;

  bool get isOnSale => regularAmount != null && regularAmount! > amount;

  /// Ruta del archivo bajo `wp-content/uploads/` (`null` = sin foto).
  final String? image;

  /// `false` = la web muestra "Hablar con un asesor" aunque tenga precio.
  final bool purchasable;
  final Map<String, List<String>> attributes;

  /// Producto variable (W1-01): un eje de elección y sus variaciones.
  final _DemoAxis? axis;
  final List<_DemoVariant> variants;
}

/// Eje de elección de un producto variable de demostración.
final class _DemoAxis {
  const new(this.slug, this.name);

  final String slug;
  final String name;
}

/// Variación de demostración: `option` es la etiqueta visible (su valor se
/// deriva de ella). Los ids son de demostración, no los de WooCommerce.
final class _DemoVariant {
  const new({
    required this.id,
    required this.sku,
    required this.option,
    required this.amount,
    this.image,
    this.maxQuantity,
  });

  final int id;
  final String sku;
  final String option;
  final int amount;
  final String? image;

  /// Máximo por línea de DEMOSTRACIÓN (W1-06): los reales los define WordPress.
  final int? maxQuantity;

  String get value => _fold(option).replaceAll(RegExp('[^a-z0-9]+'), '-');
}

const _products = [
  _Product(
    id: 101,
    slug: 'aire-acondicionado-mini-split-on-off-11000-btu-220v-eficiencia-13s-r410a-midea',
    name: 'Mini Split On/off Midea 12000 BTU 220V R410a',
    sku: '613-0025',
    amount: 1120000,
    category: 'aire-acondicionado',
    brand: 'midea',
    image: '2021/02/613-0024.png',
    purchasable: false,
    attributes: {
      'Capacidad BTU': ['12000'],
      'Voltaje': ['220V'],
      'Refrigerante': ['R410a'],
    },
  ),
  _Product(
    id: 102,
    slug: 'uniweld-regulador-de-nitrogeno-0-a-800-psi',
    name: 'Regulador De Nitrógeno Uniweld 0 A 800 Psi',
    sku: '515-0017',
    amount: 452000,
    category: 'herramientas',
    brand: 'uniweld',
    purchasable: false,
  ),
  _Product(
    id: 103,
    slug: 'aire-acondicionado-mini-split-inverter-12000-btu-h-220v-r410a-advance-samsung',
    name: 'Mini Split Inverter Samsung Deluxe 12000 BTU 220V R410a',
    sku: '614-0054',
    amount: 1830000,
    category: 'aire-acondicionado',
    brand: 'samsung',
    purchasable: false,
    attributes: {
      'Capacidad BTU': ['12000'],
      'Voltaje': ['220V'],
      'Refrigerante': ['R410a'],
    },
  ),
  _Product(
    id: 104,
    slug: 'vacuometro-digital-bluetooth-elitech-vgw-760',
    name: 'Vacuómetro Digital Bluetooth Elitech Vgw-760',
    sku: '500-0123',
    amount: 541000,
    regularAmount: 615000,
    category: 'herramientas',
    brand: 'elitech',
  ),
  _Product(
    id: 105,
    slug: 'controlador-electronico-full-gauge-conservacion-mt512e-2hp-110-220v-full-gauge-3614',
    name: 'Controlador Mt512e-2hp Full Gauge 110/220v',
    sku: '180-0025',
    amount: 75800,
    regularAmount: 89000,
    category: 'tableros-y-controles',
    brand: 'fullgauge',
    image: '2018/09/180-0025.jpg',
    attributes: {
      'Voltaje': ['110/220V'],
    },
  ),
  _Product(
    id: 106,
    slug: 'ipr-gas-map',
    name: 'Gas MAPP Para Soldar Tubería De Cobre IPR',
    sku: '480-0008',
    amount: 21500,
    category: 'tuberia-accesorios-capilares',
    image: '2018/09/105.png',
  ),
  _Product(
    id: 107,
    slug: 'full-gauge-caja-conexion-sitrad-full-gauge',
    name: 'Caja De Conexión Sitrad Full Gauge',
    sku: '180-0016',
    amount: 19700,
    category: 'tableros-y-controles',
    brand: 'fullgauge',
    image: '2018/09/180-0016.jpg',
  ),
  _Product(
    id: 108,
    slug:
        'juego-manometros-r410a-r22-r404a-para-refrigeracion-uniweld-qs4l3h-5',
    name: 'Juego De Manómetros Uniweld R410a, R22 Y R404a',
    sku: '500-0073',
    amount: 228000,
    regularAmount: 265000,
    category: 'herramientas',
    brand: 'uniweld',
    image: '2018/09/500-0073.jpg',
  ),
  _Product(
    id: 109,
    slug: 'full-gauge-controlador-electronico-mt-543ri-log-110-220v-termostato-3-etapas',
    name: 'Controlador Mt-543e Log Full Gauge 110/220v',
    sku: '180-0095',
    amount: 285200,
    category: 'tableros-y-controles',
    brand: 'fullgauge',
    image: '2022/08/1.png',
    purchasable: false,
    attributes: {
      'Voltaje': ['110/220V'],
    },
  ),
  _Product(
    id: 110,
    slug: 'full-gauge-control-ti44e-plus-4-sondas-110-220v',
    name: 'Controlador Digital Ti-44e Plus Full Gauge 110/220v',
    sku: '180-0056',
    amount: 157000,
    category: 'tableros-y-controles',
    brand: 'fullgauge',
    image: '2019/01/Diseno-sin-titulo-1.png',
    attributes: {
      'Voltaje': ['110/220V'],
    },
  ),
  _Product(
    id: 111,
    slug: 'bomba-de-vacio-1-2-cfm-1-etapa-110v-zru-0-5a',
    name: 'Bomba De Vacío 1.2 CFM 1 Etapa 110V',
    sku: '500-0010',
    amount: 278000,
    regularAmount: 325000,
    category: 'herramientas',
    image: '2018/09/500-0010-0.jpg',
    attributes: {
      'Voltaje': ['110V'],
    },
  ),
  _Product(
    id: 112,
    slug: 'full-gauge-sensor-sb41-negro-full-gauge',
    name: 'Sensor De Temperatura SB41 Negro Hermético Full Gauge',
    sku: '180-0080',
    amount: 13800,
    category: 'tableros-y-controles',
    brand: 'fullgauge',
    image: '2018/09/1990.jpg',
  ),
  _Product(
    id: 113,
    slug: 'boquilla-para-soldar-ecualizable-sencilla-uniweld-rp3t5',
    name: 'Boquilla Para Soldar Equalizable Sencilla Uniweld Rp3t5',
    sku: '515-0005',
    amount: 187000,
    category: 'herramientas',
    brand: 'uniweld',
    image: '2018/09/515-0005-2.jpg',
  ),
  // Producto variable (piloto VAR0416 de la web): nombre, SKU, opciones y
  // precios son los que publica la ficha pública (JSON-LD, 2026-11-26). Los
  // ids de las variaciones son de demostración.
  _Product(
    id: 140,
    slug: 'desincrustante-alfa-coil-cleaner-con-rinse',
    name: 'Desincrustante Alfa Coil Cleaner Con Enjuague',
    sku: '',
    amount: 8200,
    category: 'aire-acondicionado',
    image: '2025/02/470-0001.png',
    purchasable: false,
    axis: _DemoAxis('pa_volumen', 'Volumen'),
    variants: [
      _DemoVariant(
        id: 4701,
        sku: '470-0001',
        option: '500 cc',
        amount: 8200,
        image: '2025/02/470-0001.png',
      ),
      _DemoVariant(id: 4703, sku: '470-0003', option: '1 L', amount: 12500),
      _DemoVariant(
        id: 4702,
        sku: '470-0002',
        option: '1 galón',
        amount: 31000,
        image: '2025/02/470-0002.png',
        maxQuantity: 3,
      ),
    ],
  ),
];

final class _StorePhone {
  const new(this.type, this.display, this.dial);

  final String type;
  final String display;
  final String dial;
}

final class _Store {
  const new({
    required this.slug,
    required this.city,
    required this.name,
    required this.address,
    required this.image,
    this.phones = const [],
    this.upcoming = false,
  });

  final String slug;
  final String city;
  final String name;
  final String address;
  final String image;
  final List<_StorePhone> phones;
  final bool upcoming;
}

const _corporateWhatsapp = '573014021882';

/// Sedes reales de IPR tomadas de `ipr-frontend/src/lib/sedes-data.ts`.
const _stores = <_Store>[
  _Store(
    slug: 'medellin-sede-principal-guayabal',
    city: 'Medellín',
    name: 'Sede Principal Guayabal',
    address: 'Calle 14 sur #51c-5',
    image: '/sedes/Imagen-IPR-scaled.jpg',
    phones: [
      _StorePhone('landline', '(604) 3604440', '+576043604440'),
      _StorePhone('sales_parts', '321 840 9879', '+573218409879'),
      _StorePhone('sales_ac', '312 288 7501', '+573122887501'),
    ],
  ),
  _Store(
    slug: 'medellin-cundinamarca',
    city: 'Medellín',
    name: 'Cundinamarca',
    address: 'Cra. 53 #58-66',
    image: '/sedes/CUNDINAMARCA.jpg',
    phones: [
      _StorePhone('landline', '(604) 4446440', '+576044446440'),
      _StorePhone('mobile', '314 684 2532', '+573146842532'),
    ],
  ),
  _Store(
    slug: 'medellin-carabobo',
    city: 'Medellín',
    name: 'Carabobo',
    address: 'Calle 59 #51d-71',
    image: '/sedes/CARABOBO.jpg',
    phones: [
      _StorePhone('landline', '(604) 4446440', '+576044446440'),
      _StorePhone('mobile', '314 684 1229', '+573146841229'),
    ],
  ),
  _Store(
    slug: 'medellin-carabobo-industrial',
    city: 'Medellín',
    name: 'Carabobo Industrial',
    address: 'Calle 59 No 52-18',
    image: '/sedes/carabobo-industrial.jpeg',
    phones: [
      _StorePhone('landline', '(604) 3604440', '+576043604440'),
      _StorePhone('mobile', '314 684 1229', '+573146841229'),
    ],
  ),
  _Store(
    slug: 'medellin-la-america',
    city: 'Medellín',
    name: 'La América',
    address: 'Cl. 44 #79-105',
    image: '/sedes/AMERICA.jpg',
    phones: [
      _StorePhone('landline', '(604) 3604440', '+576043604440'),
      _StorePhone('mobile', '304 216 8990', '+573042168990'),
    ],
  ),
  _Store(
    slug: 'medellin-av-oriental',
    city: 'Medellín',
    name: 'Av Oriental',
    address: 'Carrera 46 #40-06',
    image: '/sedes/orinetal.jpg',
    phones: [_StorePhone('landline', '(604) 4446440', '+576044446440')],
  ),
  _Store(
    slug: 'medellin-itagui',
    city: 'Medellín',
    name: 'Itagüí',
    address: 'Calle 63 #44-70',
    image: '/sedes/ITAGUI.jpg',
    phones: [_StorePhone('landline', '(604) 3604440', '+576043604440')],
  ),
  _Store(
    slug: 'medellin-bello',
    city: 'Medellín',
    name: 'Bello',
    address: 'Carrera 50 #32-23',
    image: '/sedes/BELLO.jpg',
    phones: [
      _StorePhone('landline', '(604) 3604440', '+576043604440'),
      _StorePhone('mobile', '323 229 2158', '+573232292158'),
    ],
  ),
  _Store(
    slug: 'medellin-cristo-rey',
    city: 'Medellín',
    name: 'Cristo Rey',
    address: 'Carrera 52 #2sur-44',
    image: '/sedes/CRISTO-REY.jpg',
    phones: [
      _StorePhone('landline', '(604) 3604440', '+576043604440'),
      _StorePhone('mobile', '320 676 0104', '+573206760104'),
    ],
  ),
  _Store(
    slug: 'cali-sede-principal',
    city: 'Cali',
    name: 'Sede Principal',
    address: 'Calle 58 No. 1N - 85',
    image: '/sedes/BODEGA-PRINCIPAL-scaled.jpg',
    phones: [
      _StorePhone('landline', '(602) 3827756', '+576023827756'),
      _StorePhone('mobile', '313 719 2587', '+573137192587'),
    ],
  ),
  _Store(
    slug: 'cali-la-flora',
    city: 'Cali',
    name: 'La Flora',
    address: 'Calle 58 No. 1N - 85',
    image: '/sedes/BODEGA-PRINCIPAL-CALI.jpg',
    phones: [_StorePhone('landline', '(602) 3828210', '+576023828210')],
  ),
  _Store(
    slug: 'cali-san-nicolas',
    city: 'Cali',
    name: 'San Nicolás',
    address: 'Carrera 6 #19-36',
    image: '/sedes/SAN-NICOLAS-CALI.jpg',
    phones: [
      _StorePhone('landline', '(602) 3827828', '+576023827828'),
      _StorePhone('mobile', '314 589 4926', '+573145894926'),
    ],
  ),
  _Store(
    slug: 'cali-pasoancho',
    city: 'Cali',
    name: 'Pasoancho',
    address: 'Avenida Pasoancho Calle 13 #47a-05',
    image: '/sedes/PASOANCHO-CALI.jpg',
    phones: [
      _StorePhone('landline', '(602) 382 82 15', '+576023828215'),
      _StorePhone('mobile', '314 589 37 08', '+573145893708'),
    ],
  ),
  _Store(
    slug: 'cali-la-quinta',
    city: 'Cali',
    name: 'La Quinta',
    address: 'Carrera 5 No. 18 - 11',
    image: '/sedes/cali-la-quinta.jpg',
    phones: [_StorePhone('mobile', '314 589 4927', '+573145894927')],
  ),
  _Store(
    slug: 'barranquilla-sede-principal',
    city: 'Barranquilla',
    name: 'Sede Principal Centro',
    address: 'Calle 44 #41-45',
    image: '/sedes/CALLE-44-BARRANQUILLA.jpg',
    phones: [
      _StorePhone('landline', '(605) 3111031', '+576053111031'),
      _StorePhone('mobile', '314 683 8721', '+573146838721'),
    ],
  ),
  _Store(
    slug: 'bucaramanga-sede-principal',
    city: 'Bucaramanga',
    name: 'Sede Principal',
    address: 'Calle 16 No. 14-23 Barrio Gaitán',
    image: '/sedes/FOTO-PAGINA-BUCARAMANGA.jpg',
    phones: [
      _StorePhone('landline', '(607) 691 79 88', '+576076917988'),
      _StorePhone('mobile', '300 481 18 57', '+573004811857'),
    ],
  ),
  _Store(
    slug: 'bucaramanga-alarcon',
    city: 'Bucaramanga',
    name: 'Alarcón',
    address: 'Carrera 21 No. 28-88 Barrio Alarcón',
    image: '/sedes/ALARCON-2022.jpg',
    phones: [
      _StorePhone('landline', '(607) 691 79 05', '+576076917905'),
      _StorePhone('mobile', '324 574 4831', '+573245744831'),
    ],
  ),
  _Store(
    slug: 'bucaramanga-industrial',
    city: 'Bucaramanga',
    name: 'Industrial',
    address: 'Calle 16 No. 14-23 Barrio Gaitán',
    image: '/sedes/FOTO-PAGINA-BUCARAMANGA.jpg',
    phones: [
      _StorePhone('landline', '(607) 691 79 88', '+576076917988'),
      _StorePhone('mobile', '324 574 4797', '+573245744797'),
    ],
  ),
  _Store(
    slug: 'bogota-sede-principal',
    city: 'Bogotá',
    name: 'Sede Principal',
    address: 'Calle 18 #69-91 (Zona Industrial Montevideo)',
    image: '/sedes/BODEGA-BGTA.png',
    phones: [
      _StorePhone('landline', '(601) 4823379', '+576014823379'),
      _StorePhone('mobile', '310 510 3293', '+573105103293'),
    ],
  ),
  _Store(
    slug: 'bogota-av-19',
    city: 'Bogotá',
    name: 'Av 19',
    address: 'Avenida Calle 19 #18-08',
    image: '/sedes/LA-19-BOGOTA.jpg',
    phones: [
      _StorePhone('landline', '(601) 482 32 74', '+576014823274'),
      _StorePhone('mobile', '314 589 24 38', '+573145892438'),
    ],
  ),
  _Store(
    slug: 'bogota-chapinero',
    city: 'Bogotá',
    name: 'Chapinero',
    address: 'Calle 70 # 14-41',
    image: '/sedes/CHAPINERO-BOGOTA.jpg',
    phones: [
      _StorePhone('landline', '(601) 4824049', '+576014824049'),
      _StorePhone('mobile', '314 589 6251', '+573145896251'),
    ],
  ),
  _Store(
    slug: 'barranquilla-centro',
    city: 'Barranquilla',
    name: 'Centro',
    address: 'Calle 44 #41-45',
    image: '/sedes/CALLE-44-BARRANQUILLA.jpg',
    phones: [
      _StorePhone('landline', '(605) 3111031', '+576053111031'),
      _StorePhone('mobile', '314 683 8721', '+573146838721'),
    ],
  ),
  _Store(
    slug: 'barranquilla-industrial',
    city: 'Barranquilla',
    name: 'Barranquilla Industrial',
    address: 'Calle 44 #41-45',
    image: '/sedes/CALLE-44-BARRANQUILLA.jpg',
    phones: [
      _StorePhone('landline', '(605) 3111031', '+576053111031'),
      _StorePhone('mobile', '301 131 2023', '+573011312023'),
    ],
  ),
  _Store(
    slug: 'barranquilla-la-43',
    city: 'Barranquilla',
    name: 'La 43',
    address: 'Calle 43 # 41 - 111 Local 1',
    image: '/sedes/la-43-barranquilla.jpeg',
    phones: [
      _StorePhone('landline', '(605) 3198520', '+576053198520'),
      _StorePhone('mobile', '314 589 8748', '+573145898748'),
    ],
  ),
  _Store(
    slug: 'barranquilla-la-66-el-rosario',
    city: 'Barranquilla',
    name: 'La 66 El Rosario',
    address: 'Calle 43 No. 41 - 67 Centro Comercial Rosario, Local 2',
    image: '/sedes/bquilla-la-66-el-rosario.jpg',
    phones: [
      _StorePhone('landline', '(605) 3197927', '+576053197927'),
      _StorePhone('mobile', '314 589 7513', '+573145897513'),
    ],
  ),
  _Store(
    slug: 'monteria-sede-principal',
    city: 'Montería',
    name: 'Sede Principal',
    address: 'Calle 39 #5-10',
    image: '/sedes/Monteria-sede-principal-1.jpg',
    phones: [_StorePhone('mobile', '301 637 3025', '+573016373025')],
  ),
  _Store(
    slug: 'monteria-industrial',
    city: 'Montería',
    name: 'Industrial',
    address: 'Calle 38 # 5 - 45',
    image: '/sedes/Monteria-industrial.jpg',
    phones: [_StorePhone('mobile', '301 637 3025', '+573016373025')],
  ),
  _Store(
    slug: 'villavicencio-sede-principal',
    city: 'Villavicencio',
    name: 'Sede Principal',
    address: 'Calle 35 #24-51',
    image: '/sedes/Villavicencio-Pagina-web.png',
    phones: [
      _StorePhone('mobile', '324 688 6127', '+573246886127'),
      _StorePhone('mobile', '323 436 4603', '+573234364603'),
    ],
  ),
  _Store(
    slug: 'villavicencio-industrial',
    city: 'Villavicencio',
    name: 'Industrial',
    address: 'Calle 35 # 24 - 53, Barrio San Isidro',
    image: '/sedes/Villavicencio-Pagina-web.png',
    phones: [
      _StorePhone('mobile', '324 688 6127', '+573246886127'),
      _StorePhone('mobile', '323 436 4603', '+573234364603'),
    ],
  ),
  _Store(
    slug: 'rionegro',
    city: 'Rionegro',
    name: 'Rionegro',
    address: 'Carrera 51 #52-21',
    image: '/sedes/RIONEGRO.jpg',
    phones: [
      _StorePhone('landline', '(604) 5627864', '+5745627864'),
      _StorePhone('mobile', '323 229 3375', '+573232293375'),
    ],
  ),
  _Store(
    slug: 'apartado',
    city: 'Apartadó',
    name: 'Apartadó',
    address: 'Calle 92 # 100 -91',
    image: '/sedes/apartado.jpg',
    phones: [_StorePhone('landline', '301 524 0961', '+573015240961')],
  ),
  _Store(
    slug: 'cartagena',
    city: 'Cartagena',
    name: 'Cartagena',
    address: '',
    image: '/sedes/primo-proximamente.png',
    upcoming: true,
  ),
];

const _pendingAddress = 'Dirección por confirmar';

/// Cuerpo de demostración para la operación [template] (ruta del contrato) o
/// `null` si esa ruta no tiene datos de demostración y se sirve el ejemplo
/// sintetizado del contrato.
///
/// [example] es el ejemplo sintetizado del contrato para esa respuesta.
Object? demoBody({
  required String template,
  required String path,
  required Map<String, String> query,
  required Object? example,
  Object? requestBody,
}) => switch (template) {
  '/config' => _config(example),
  '/categories' => {'data': _categoryJson()},
  '/brands' => {'data': _brandJson()},
  '/brands/{slug}' => _brandLanding(path),
  '/stores' => {'data': _storeJson()},
  '/products' => _productPage(query),
  '/liquidaciones' => _productPage({...query, 'onSale': 'true'}),
  '/search' => _productPage(query, searching: true),
  '/search/suggestions' => _suggestions(query),
  '/filters' => {'data': _filterJson(query)},
  '/products/{slug}' => _productDetail(path),
  '/cart/validate' => _cartValidate(requestBody),
  '/checkout' => _checkoutSession(),
  '/checkout/{checkoutRef}' => _checkoutStatus(path),
  '/me' => {'data': _demoUserProfile(requestBody)},
  '/me/addresses/{type}' => {'data': _demoUserProfile(null)},
  '/auth/login' || '/auth/register' || '/me/email' => _demoAuthSession(example),
  '/orders' => _orderPage(query),
  '/orders/{orderId}' => _orderDetail(path),
  _ => null,
};

/// `Capacidad BTU` → `capacidad-btu` (parte de la clave `attr[pa_…]`).
String _attrSlug(String name) => _fold(name).replaceAll(' ', '-');

/// Filtros disponibles para el listado: marca y los atributos que tienen los
/// productos de la categoría pedida (nada inventado: solo lo que hay).
List<Json> _filterJson(Map<String, String> query) {
  final category = query['category'];
  final allowed = (category != null && category.isNotEmpty)
      ? _categoryScope(category)
      : null;
  final scope = [
    for (final p in _products)
      if (allowed == null || allowed.contains(p.category)) p,
  ];

  final brandSlugs = {
    for (final p in scope)
      if (p.brand != null) p.brand!,
  };
  final attributes = <String, Set<String>>{};
  for (final p in scope) {
    for (final entry in p.attributes.entries) {
      attributes.putIfAbsent(entry.key, () => <String>{}).addAll(entry.value);
    }
  }

  return [
    if (brandSlugs.isNotEmpty)
      {
        'key': 'brand',
        'label': 'Marca',
        'type': 'multi',
        'options': [
          for (final slug in brandSlugs)
            {'value': slug, 'label': _brands[slug]},
        ],
      },
    for (final entry in attributes.entries)
      {
        'key': 'attr[pa_${_attrSlug(entry.key)}]',
        'label': entry.key,
        'type': 'multi',
        'options': [
          for (final value in entry.value) {'value': value, 'label': value},
        ],
      },
  ];
}

/// Aplica los filtros `attr[pa_…]` de la consulta: un producto pasa si, para
/// cada atributo pedido, tiene alguna de las opciones elegidas.
bool _matchesAttributes(_Product product, Map<String, String> query) {
  for (final entry in query.entries) {
    final match = RegExp(r'^attr\[pa_(.+)\]$').firstMatch(entry.key);
    if (match == null) continue;
    final wanted = entry.value.split(',').where((v) => v.isNotEmpty).toSet();
    if (wanted.isEmpty) continue;
    final options = [
      for (final attr in product.attributes.entries)
        if (_attrSlug(attr.key) == match.group(1)) ...attr.value,
    ];
    if (!options.any(wanted.contains)) return false;
  }
  return true;
}

/// Igual que el ejemplo del contrato, con la calculadora de BTU encendida
/// para poder ver su tarjeta en el inicio.
Object? _config(Object? example) {
  // Copia profunda: el ejemplo puede ser un objeto compartido del contrato.
  final copy = jsonDecode(jsonEncode(example));
  if (copy is! Json) return null;
  final data = copy['data'];
  if (data is! Json) return null;
  final features = data['features'];
  if (features is Json) features['btuCalculatorEnabled'] = true;
  data['home'] = _homeContent();
  final contact = data['contact'];
  if (contact is Json) {
    contact['phone'] = {'display': '(604) 322 23 23', 'dial': '+576043222323'};
    contact['whatsapp'] = {
      'number': _corporateWhatsapp,
      'defaultMessage':
          '¡Hola IPR! Quiero asesoría sobre un repuesto o equipo.',
    };
    contact['salesEmail'] = 'ventas@iprpartesyrepuestos.com';
    contact['pqrsEmail'] = 'servicioalcliente@iprpartesyrepuestos.com';
    if (contact['engineering'] is Json) {
      (contact['engineering']! as Json)['specialties'] =
          _engineeringSpecialties();
    }
  }
  data['checkout'] = {
    'allowedHosts': ['iprpartesyrepuestos.com', 'ipr.iprpartesyrepuestos.com'],
    'returnPathPrefix': '/app/pedido',
  };
  data['notices'] = {
    'shipping':
        'Despachos a toda Colombia desde nuestras sedes principales. El costo '
        'y el tiempo de envío se confirman al finalizar el pedido.',
    'warranty':
        'Todos nuestros equipos y repuestos cuentan con garantía directa de '
        'IPR Partes y Repuestos según términos del fabricante.',
    'priceOnRequest':
        'Este equipo o referencia requiere asesoría técnica para confirmar '
        'disponibilidad y precio vigente. Escríbenos por WhatsApp.',
  };
  return copy;
}

/// Equipo de ingeniería de DEMOSTRACIÓN (W3-02): canales corporativos por
/// ciudad tomados de la página pública de ingeniería de la web (2026-11-26).
/// Solo buzones y líneas de la empresa; ningún nombre ni contacto personal
/// (AC-080-2).
List<Json> _engineeringSpecialties() {
  Json contact(
    String id,
    String city,
    String email,
    String whatsapp,
    String phone,
    String? ext,
  ) => {
    'id': id,
    'city': city,
    'email': email,
    'whatsapp': whatsapp,
    'phoneDisplay': ext == null ? phone : '$phone ext. $ext',
    'phoneDial': phone,
  };
  return [
    {
      'id': 'aire',
      'name': 'Aire Acondicionado y Ventilación',
      'description': 'HVAC · Climatización y manejo de aire',
      'whatsappMessage':
          'Hola, me gustaría recibir asesoría del equipo de ingeniería en '
          'aire acondicionado y ventilación.',
      'contacts': [
        contact(
          'aire-bogota',
          'Bogotá',
          'ingenieriabogota01@inverprimos.com',
          '573011384285',
          '6043604440',
          null,
        ),
      ],
    },
    {
      'id': 'refrigeracion',
      'name': 'Refrigeración Comercial e Industrial',
      'description': 'Cuartos fríos, cámaras y procesos',
      'whatsappMessage':
          'Hola, me gustaría contactar al equipo de ingeniería en '
          'refrigeración',
      'contacts': [
        contact(
          'refri-medellin',
          'Medellín',
          'ingenieriamedellin@inverprimos.com',
          '573011384281',
          '6043604440',
          '1151',
        ),
        contact(
          'refri-cali',
          'Cali',
          'ingenieriacali@inverprimos.com',
          '573011384272',
          '6023827756',
          '2007',
        ),
        contact(
          'refri-monteria',
          'Montería',
          'ingenieriamonteria@inverprimos.com',
          '573011384259',
          '6043604440',
          '7003',
        ),
        contact(
          'refri-bogota',
          'Bogotá',
          'ingenieriabogota@inverprimos.com',
          '573246129811',
          '6014823379',
          '3007',
        ),
        contact(
          'refri-bucaramanga',
          'Bucaramanga',
          'ingenieriabucaramanga@inverprimos.com',
          '573212641972',
          '6076917988',
          '4007',
        ),
      ],
    },
  ];
}

const _webImages = 'https://iprpartesyrepuestos.com';

/// Contenido de portada de DEMOSTRACIÓN (W2): campañas, cifras y bloques
/// tomados de la portada pública de la web (iprpartesyrepuestos.com,
/// 2026-11-26). En producción lo entrega el BFF y lo mantiene Marketing (D-07).
Json _homeContent() {
  Json banner(String id, String file, String alt, Json target) => {
    'id': id,
    'alt': alt,
    'image': {
      'url': '$_webImages/slider-main/$file-mobile.webp',
      'alt': '',
      'width': 1600,
      'height': 1191,
    },
    'target': target,
  };
  Json web(String path) => {'kind': 'web', 'ref': '$_site$path'};

  final activeBranches = _stores.where((s) => !s.upcoming).length;
  return {
    'banners': [
      banner(
        'jugada-samsung',
        'jugada-navidena',
        'Jugada Navideña Samsung X IPR: gana increíbles premios este '
            'diciembre. Raspa tu tarjeta con cada equipo Samsung que compras en IPR',
        web('/jugada-samsung'),
      ),
      banner(
        'parche-midea',
        'parche-midea',
        'Parche Midea X IPR: compra tu aire acondicionado Midea, registra tu '
            'factura y gira la ruleta',
        web('/parche-midea'),
      ),
      banner(
        'fiberglass',
        'fiberglass',
        'Fiberglass Isover: gana una bicicleta eléctrica por tus compras '
            'Fiberglass',
        web('/fiberglass'),
      ),
      banner(
        'equipo-ingenieria',
        'equipo-ingenieria',
        'Equipo de Ingeniería IPR',
        {'kind': 'engineering'},
      ),
      banner(
        'addi',
        'addi',
        'En IPR puedes comprar ahora y pagar después con Addi: solo necesitas '
            'tu cédula y WhatsApp. Aplican términos y condiciones, sujeto a '
            'aprobación de crédito por parte de Addi',
        {
          'kind': 'whatsapp',
          'ref': '¡Hola IPR! Quiero comprar ahora y pagar después con Addi.',
        },
      ),
    ],
    'stats': [
      {
        'id': 'years',
        'value': '+30',
        'unit': 'años',
        'label': 'Importando y distribuyendo en Colombia',
      },
      {
        'id': 'branches',
        'value': '$activeBranches',
        'unit': null,
        'label': 'Sedes atendiendo el mercado nacional',
        'target': {'kind': 'branches'},
      },
      {
        'id': 'references',
        'value': '+10.000',
        'unit': null,
        'label':
            'Referencias para Aire Acondicionado, Refrigeración y '
            'Ventilación',
        'target': {'kind': 'category', 'ref': 'aire-acondicionado'},
      },
      {
        'id': 'leader',
        'value': 'Líder del sector HVAC-R*',
        'unit': null,
        'label':
            '(Comparado con empresas importadoras, distribuidoras y '
            'comercializadoras del sector)',
      },
    ],
    'highlights': [
      {
        'id': 'engineering',
        'eyebrow': 'Ingeniería IPR',
        'title': 'Ingenieros que te acompañan en tu proyecto',
        'body':
            'Dimensionamos cargas térmicas, seleccionamos equipos y '
            'acompañamos la instalación con ingenieros especializados en aire '
            'acondicionado y refrigeración comercial e industrial.',
        'cta': 'Conocer ingeniería',
        'image': {
          'url': '$_webImages/Ingenieria/ING-REFRI.webp',
          'alt': '',
          'width': null,
          'height': null,
        },
        'target': {'kind': 'engineering'},
      },
      {
        'id': 'training',
        'eyebrow': 'Formación técnica',
        'title': 'Capacitaciones con las marcas líderes',
        'body':
            'Jornadas técnicas con Samsung, Danfoss, Gree, Mabe y Full Gauge '
            'para que tu equipo instale y diagnostique mejor.',
        'cta': 'Ver capacitaciones',
        'image': null,
        'target': web('/capacitaciones'),
      },
      {
        'id': 'rse',
        'eyebrow': 'Sostenibilidad',
        'title': 'Responsabilidad Social Empresarial',
        'body':
            'Comprometidos con la reducción de nuestra huella de carbono, '
            'el desarrollo de las comunidades y un gobierno corporativo '
            'transparente.',
        'cta': 'Conocer programas RSE',
        'image': null,
        'target': web('/responsabilidad-social'),
      },
      {
        'id': 'promotions',
        'eyebrow': 'Campañas vigentes',
        'title': 'Actividades Promocionales IPR',
        'body':
            'Participa en nuestras campañas vigentes con Samsung, Midea y '
            'Fiberglass y descubre los sorteos y premios de temporada.',
        'cta': 'Ver actividades',
        'image': null,
        'target': web('/actividades-promocionales'),
      },
    ],
  };
}

final class _ResolvedCategory {
  const new({
    required this.id,
    required this.slug,
    required this.name,
    required this.parentId,
    required this.productCount,
    required this.subtreeSlugs,
    required this.children,
  });

  final int id;
  final String slug;
  final String name;
  final int? parentId;
  final int productCount;
  final Set<String> subtreeSlugs;
  final List<_ResolvedCategory> children;

  Json toJson() => {
    'id': id,
    'slug': slug,
    'name': name,
    'parentId': parentId,
    'productCount': productCount,
    'children': [for (final c in children) c.toJson()],
  };
}

String _slugify(String name) =>
    _fold(name).replaceAll(RegExp('[^a-z0-9]+'), '-');

final List<_ResolvedCategory> _categoryTree = _buildCategoryTree();
final Map<String, _ResolvedCategory> _categoriesBySlug = _indexCategories(
  _categoryTree,
);

List<_ResolvedCategory> _buildCategoryTree() {
  final ownCounts = <String, int>{};
  for (final p in _products) {
    ownCounts[p.category] = (ownCounts[p.category] ?? 0) + 1;
  }
  // Los hijos reciben ids desde 100, para no chocar con los de las raíces.
  var nextId = 100;

  _ResolvedCategory buildNode({
    required int id,
    required String slug,
    required String name,
    required int? parentId,
    required List<_Node> rawChildren,
  }) {
    final builtChildren = <_ResolvedCategory>[
      for (final child in rawChildren)
        buildNode(
          id: nextId++,
          slug: child.slug ?? _slugify(child.name),
          name: child.name,
          parentId: id,
          rawChildren: child.children,
        ),
    ];
    final subtreeSlugs = <String>{
      slug,
      for (final child in builtChildren) ...child.subtreeSlugs,
    };
    final productCount =
        (ownCounts[slug] ?? 0) +
        builtChildren.fold<int>(0, (sum, child) => sum + child.productCount);
    return _ResolvedCategory(
      id: id,
      slug: slug,
      name: name,
      parentId: parentId,
      productCount: productCount,
      subtreeSlugs: subtreeSlugs,
      children: builtChildren,
    );
  }

  return [
    for (final c in _categories)
      buildNode(
        id: c.id,
        slug: c.slug,
        name: c.name,
        parentId: null,
        rawChildren: _subcategories[c.slug] ?? const [],
      ),
  ];
}

Map<String, _ResolvedCategory> _indexCategories(List<_ResolvedCategory> roots) {
  final map = <String, _ResolvedCategory>{};
  void visit(_ResolvedCategory node) {
    assert(
      !map.containsKey(node.slug),
      'Slug de categoría duplicado: ${node.slug}',
    );
    map[node.slug] = node;
    node.children.forEach(visit);
  }

  roots.forEach(visit);
  return map;
}

Set<String> _categoryScope(String slug) =>
    _categoriesBySlug[slug]?.subtreeSlugs ?? {slug};

List<Json> _categoryJson() => [for (final c in _categoryTree) c.toJson()];

List<Json> _brandJson() => [
  for (final entry in _brands.entries)
    {
      'slug': entry.key,
      'name': entry.value,
      'logoUrl': null,
      'hasLanding': true,
    },
];

List<Json> _storeJson() => [
  for (final s in _stores)
    {
      'slug': s.slug,
      'city': s.city,
      'name': s.name,
      'address': s.address.isEmpty ? _pendingAddress : s.address,
      'upcoming': s.upcoming,
      'phones': [
        for (final p in s.phones)
          {'type': p.type, 'display': p.display, 'dial': p.dial},
      ],
      'whatsapp': {'number': _corporateWhatsapp},
      'imageUrl': '$_site${s.image}',
      'mapsQuery': s.address.isEmpty
          ? null
          : '${s.address}, ${s.city}, Colombia',
      'coordinates': null,
      'openingHours': null,
    },
];

Json _priceJson(int amount, {int? regularAmount}) {
  final onSale = regularAmount != null && regularAmount > amount;
  final discountPercent = onSale
      ? ((regularAmount - amount) * 100 / regularAmount).round()
      : null;
  return {
    'status': 'priced',
    'amount': amount,
    'regularAmount': onSale ? regularAmount : amount,
    'onSale': onSale,
    'discountPercent': discountPercent,
    'currency': 'COP',
    'taxIncluded': true,
  };
}

Json? _imageJson(String? image, String alt) => image == null
    ? null
    : {'url': '$_media/$image', 'alt': alt, 'width': 600, 'height': 600};

Json _summary(_Product p) {
  final brand = p.brand;
  return {
    'id': p.id,
    'slug': p.slug,
    'name': p.name,
    'sku': p.sku,
    'brand': brand == null ? null : {'name': _brands[brand], 'slug': brand},
    'price': _priceJson(p.amount, regularAmount: p.regularAmount),
    'availability': 'in_stock',
    'purchasable': p.purchasable,
    'image': _imageJson(p.image, p.name),
    'categorySlugs': [p.category],
    if (p.variants.isNotEmpty) ...{
      'hasVariants': true,
      'priceFrom': p.variants.map((v) => v.amount).reduce(math.min),
    },
  };
}

Json _suggestion(_Product p) => {
  'id': p.id,
  'slug': p.slug,
  'name': p.name,
  'sku': p.sku,
  'brandName': p.brand == null ? null : _brands[p.brand],
  'price': _priceJson(p.amount, regularAmount: p.regularAmount),
  'availability': 'in_stock',
  'image': _imageJson(p.image, p.name),
};

List<_Product> _searchProducts(Iterable<_Product> items, String rawQuery) {
  final text = _fold(rawQuery);
  if (text.isEmpty) return items.toList();
  final terms = text.split(' ').where((t) => t.isNotEmpty);
  return [
    for (final p in items)
      if (terms.every(
        _fold('${p.name} ${p.sku} ${_brands[p.brand] ?? ''}').contains,
      ))
        p,
  ];
}

Json _suggestions(Map<String, String> query) {
  final rawQuery = query['q'] ?? '';
  final matches = _searchProducts(_products, rawQuery);
  return {
    'data': {
      'query': rawQuery,
      'total': matches.length,
      'items': [for (final p in matches.take(6)) _suggestion(p)],
    },
  };
}

Json _productPage(Map<String, String> query, {bool searching = false}) {
  var items = _products.toList();

  final category = query['category'];
  if (category != null && category.isNotEmpty) {
    final allowed = _categoryScope(category);
    items = items.where((p) => allowed.contains(p.category)).toList();
  }
  final brands = (query['brand'] ?? '')
      .split(',')
      .where((b) => b.isNotEmpty)
      .toSet();
  if (brands.isNotEmpty) {
    items = items.where((p) => brands.contains(p.brand)).toList();
  }
  if (query['onSale'] == 'true') {
    items = items.where((p) => p.isOnSale).toList();
  }
  items = items.where((p) => _matchesAttributes(p, query)).toList();

  if (searching) {
    items = _searchProducts(items, query['q'] ?? '');
  }

  switch (query['sort']) {
    case 'price-asc':
      items.sort((a, b) => a.amount.compareTo(b.amount));
    case 'price-desc':
      items.sort((a, b) => b.amount.compareTo(a.amount));
    case 'name':
      items.sort((a, b) => a.name.compareTo(b.name));
    case 'latest':
      items = items.reversed.toList();
  }

  final perPage = int.tryParse(query['perPage'] ?? '') ?? 12;
  final page = (int.tryParse(query['page'] ?? '') ?? 1).clamp(1, 50);
  final totalPages = (items.length / perPage).ceil();
  final start = (page - 1) * perPage;
  final slice = start >= items.length
      ? <_Product>[]
      : items.sublist(start, (start + perPage).clamp(0, items.length));
  return {
    'data': [for (final p in slice) _summary(p)],
    'meta': {
      'page': page,
      'perPage': perPage,
      'total': items.length,
      'totalPages': totalPages,
      'hasMore': page < totalPages,
      if (searching) 'query': query['q'] ?? '',
    },
  };
}

Json? _productDetail(String path) {
  final slug = path.split('/').last;
  final product = _products.where((p) => p.slug == slug).firstOrNull;
  if (product == null) return null;
  final category =
      _categoriesBySlug[product.category] ??
      (throw StateError('Categoría desconocida: ${product.category}'));
  final image = product.image;
  final brand = _brands[product.brand];
  return {
    'data': {
      ..._summary(product),
      'shortDescription':
          '${product.name}${brand == null ? '' : ' de $brand'}.'
          '${product.sku.isEmpty ? '' : ' SKU ${product.sku}.'}',
      'descriptionHtml':
          '<p>${product.name}.</p>'
          '<p>${product.sku.isEmpty ? '' : 'Referencia ${product.sku}. '}'
          'Confirma compatibilidad y disponibilidad con un asesor de IPR.</p>',
      'gallery': [
        if (image != null)
          {
            'url': '$_media/$image',
            'alt': product.name,
            'width': 600,
            'height': 600,
          },
      ],
      'attributes': [
        for (final entry in product.attributes.entries)
          {
            'name': entry.key,
            'slug': _fold(entry.key).replaceAll(' ', '-'),
            'options': entry.value,
          },
      ],
      'categories': [
        {'id': category.id, 'slug': category.slug, 'name': category.name},
      ],
      'webUrl': '$_site/producto/${product.slug}',
      if (product.axis case final axis? when product.variants.isNotEmpty) ...{
        'variantAxes': [
          {
            'slug': axis.slug,
            'name': axis.name,
            'options': [
              for (final v in product.variants)
                {'value': v.value, 'label': v.option},
            ],
          },
        ],
        'variants': [
          for (final v in product.variants)
            {
              'id': v.id,
              'sku': v.sku,
              'price': {
                'status': 'priced',
                'amount': v.amount,
                'regularAmount': v.amount,
                'onSale': false,
                'discountPercent': null,
                'currency': 'COP',
                'taxIncluded': true,
              },
              'availability': 'in_stock',
              'purchasable': true,
              if (v.maxQuantity != null) 'maxQuantity': v.maxQuantity,
              'image': v.image == null
                  ? null
                  : {
                      'url': '$_media/${v.image}',
                      'alt': '${product.name} ${v.option}',
                      'width': 600,
                      'height': 600,
                    },
              'selection': [
                {'axis': axis.slug, 'value': v.value},
              ],
            },
        ],
      },
    },
  };
}

/// Minúsculas y sin tildes, para comparar texto de búsqueda.
String _fold(String input) {
  const from = 'áàäâéèëêíìïîóòöôúùüûñ';
  const to = 'aaaaeeeeiiiioooouuuun';
  final buffer = StringBuffer();
  for (final rune in input.toLowerCase().trim().runes) {
    final char = String.fromCharCode(rune);
    final index = from.indexOf(char);
    buffer.write(index >= 0 ? to[index] : char);
  }
  return buffer.toString();
}

final List<Json> _demoOrders = [
  {
    'id': 1001,
    'number': '1001',
    'status': 'processing',
    'statusLabel': 'En proceso',
    'paymentState': 'paid',
    'createdAt': '2026-11-24T14:20:00Z',
    'currency': 'COP',
    'total': 717600,
    'itemCount': 3,
    'subtotal': 692600,
    'shippingTotal': 25000,
    'discountTotal': 0,
    'taxTotal': 0,
    'paymentMethodTitle': 'Wompi',
    'items': [
      {
        'productId': 104,
        'name': 'Vacuómetro Digital Bluetooth Elitech Vgw-760',
        'sku': '500-0123',
        'quantity': 1,
        'total': 541000,
        'imageUrl': null,
      },
      {
        'productId': 105,
        'name': 'Controlador Mt512e-2hp Full Gauge 110/220v',
        'sku': '180-0025',
        'quantity': 2,
        'total': 151600,
        'imageUrl': '$_media/2018/09/180-0025.jpg',
      },
    ],
  },
  {
    'id': 1002,
    'number': '1002',
    'status': 'completed',
    'statusLabel': 'Completado',
    'paymentState': 'paid',
    'createdAt': '2026-11-10T09:45:00Z',
    'currency': 'COP',
    'total': 228000,
    'itemCount': 1,
    'subtotal': 228000,
    'shippingTotal': 0,
    'discountTotal': 0,
    'taxTotal': 0,
    'paymentMethodTitle': 'Wompi',
    'items': [
      {
        'productId': 108,
        'name': 'Juego De Manómetros Uniweld R410a, R22 Y R404a',
        'sku': '500-0073',
        'quantity': 1,
        'total': 228000,
        'imageUrl': '$_media/2018/09/500-0073.jpg',
      },
    ],
  },
];

Json _orderSummary(Json order) => {
  'id': order['id'],
  'number': order['number'],
  'status': order['status'],
  'statusLabel': order['statusLabel'],
  'paymentState': order['paymentState'],
  'createdAt': order['createdAt'],
  'currency': order['currency'],
  'total': order['total'],
  'itemCount': order['itemCount'],
};

Json _orderPage(Map<String, String> query) {
  final perPage = int.tryParse(query['perPage'] ?? '') ?? 10;
  final page = (int.tryParse(query['page'] ?? '') ?? 1).clamp(1, 100);
  final totalPages = (_demoOrders.length / perPage).ceil();
  final start = (page - 1) * perPage;
  final slice = start >= _demoOrders.length
      ? <Json>[]
      : _demoOrders.sublist(
          start,
          (start + perPage).clamp(0, _demoOrders.length),
        );
  return {
    'data': [for (final order in slice) _orderSummary(order)],
    'meta': {
      'page': page,
      'perPage': perPage,
      'total': _demoOrders.length,
      'totalPages': totalPages,
      'hasMore': page < totalPages,
    },
  };
}

Json? _orderDetail(String path) {
  final id = int.tryParse(path.split('/').last);
  if (id == null) return null;
  final order = _demoOrders.where((o) => o['id'] == id).firstOrNull;
  if (order == null) return null;
  return {'data': order};
}

Json _cartValidate(Object? requestBody) {
  final rawItems = requestBody is Json ? requestBody['items'] : null;
  final items = rawItems is List<dynamic>
      ? rawItems.whereType<Json>().toList()
      : const <Json>[];
  final lines = <Json>[];
  var totalAmount = 0;
  var allValid = true;

  for (final item in items) {
    final id = item['id'] as int;
    final qty = item['quantity'] as int;

    final simple = _products
        .where((p) => p.id == id && p.variants.isEmpty)
        .firstOrNull;
    if (simple != null) {
      final summary = _summary(simple);
      if (!simple.purchasable) {
        allValid = false;
        lines.add({
          'id': id,
          'quantity': qty,
          'status': 'price_on_request',
          'product': summary,
          'lineSubtotal': null,
        });
      } else {
        if (qty > 99) allValid = false;
        final subtotal = simple.amount * qty;
        totalAmount += subtotal;
        lines.add({
          'id': id,
          'quantity': qty,
          'status': 'available',
          'product': summary,
          'lineSubtotal': subtotal,
        });
      }
      continue;
    }

    (_Product, _DemoVariant)? matchedVariant;
    for (final p in _products) {
      for (final v in p.variants) {
        if (v.id == id) {
          matchedVariant = (p, v);
          break;
        }
      }
      if (matchedVariant != null) break;
    }

    if (matchedVariant == null) {
      allValid = false;
      lines.add({
        'id': id,
        'quantity': qty,
        'status': 'not_found',
        'product': null,
        'lineSubtotal': null,
      });
      continue;
    }

    final (parent, variant) = matchedVariant;
    final maxQuantity = variant.maxQuantity ?? 99;
    if (qty > maxQuantity) allValid = false;
    final subtotal = variant.amount * qty;
    totalAmount += subtotal;
    lines.add({
      'id': id,
      'quantity': qty,
      'status': 'available',
      'product': {
        'id': variant.id,
        'slug': parent.slug,
        'name': parent.name,
        'sku': variant.sku,
        'variantLabel': variant.option,
        'brand': parent.brand == null
            ? null
            : {'name': _brands[parent.brand], 'slug': parent.brand},
        'price': _priceJson(variant.amount),
        'availability': 'in_stock',
        'purchasable': true,
        'minQuantity': 1,
        if (variant.maxQuantity != null) 'maxQuantity': variant.maxQuantity,
        'image': _imageJson(
          variant.image ?? parent.image,
          '${parent.name} ${variant.option}',
        ),
        'categorySlugs': [parent.category],
      },
      'lineSubtotal': subtotal,
    });
  }

  return {
    'data': {
      'lines': lines,
      'informativeSubtotal': {
        'amount': totalAmount,
        'currency': 'COP',
        'taxIncluded': true,
      },
      'checkoutAllowed': lines.isNotEmpty && allValid,
    },
  };
}

Json _checkoutSession() => {
  'data': {
    'checkoutRef': '11111111-1111-4111-8111-111111111111',
    'checkoutUrl': '$_site/?ipr_ticket=${'A' * 32}',
    'expiresAt': '2026-12-31T23:59:59Z',
    'expiresIn': 60,
    'allowedHosts': ['iprpartesyrepuestos.com', 'ipr.iprpartesyrepuestos.com'],
    'returnUrlPrefix': '$_site/app/pedido',
  },
};

Json _checkoutStatus(String path) => {
  'data': {
    'checkoutRef': path.split('/').last,
    'state': 'order_created',
    'order': _orderSummary(_demoOrders.first),
  },
};

Json _demoUserProfile(Object? requestBody) {
  final body = requestBody is Json ? requestBody : null;
  final firstName = switch (body?['firstName']) {
    final String s when s.isNotEmpty => s,
    _ => 'Carlos',
  };
  final lastName = switch (body?['lastName']) {
    final String s when s.isNotEmpty => s,
    _ => 'Ramírez',
  };
  final address = <String, dynamic>{
    'firstName': firstName,
    'lastName': lastName,
    'company': 'Climatización Antioquia S.A.S.',
    'nationalId': '900.123.456-7',
    'address1': 'Cra. 50 # 38-20, Guayabal',
    'address2': 'Bodega 4',
    'department': 'ANT',
    'city': 'Medellín',
    'postcode': '050024',
    'phone': '+573148902612',
  };
  return {
    'id': 101,
    'email': 'carlos.ramirez@inverprimos.test',
    'firstName': firstName,
    'lastName': lastName,
    'displayName': '$firstName $lastName',
    'billing': address,
    'shipping': Map<String, dynamic>.of(address),
  };
}

Object? _demoAuthSession(Object? example) {
  final copy = jsonDecode(jsonEncode(example));
  if (copy is! Json) return null;
  final data = copy['data'];
  if (data is! Json) return null;
  data['user'] = _demoUserProfile(null);
  return copy;
}

/// Landings de marca de DEMOSTRACIÓN (W3-01): textos reales de las landings de
/// la web de IPR (`src/features/<marca>/content.ts`) adaptados a bloques.
/// El color de Midea (#0098D1) no deja leer texto blanco, así que la app lo
/// descarta y usa el azul de IPR (se ve la guarda de contraste).
Json? _brandLanding(String path) {
  final slug = path.split('/').last;
  final blocks = _brandBlocks[slug];
  if (blocks == null) return null;
  return {
    'data': {'slug': slug, 'blocks': blocks},
  };
}

const _faqGarantia =
    'Sí. Todos los equipos se entregan con garantía de fábrica y respaldo '
    'directo de IPR Partes y Repuestos, con facturación electrónica.';
const _faqEnvio = 'Despachamos a nivel nacional con transportadora aliada.';
const _faqB2b =
    'Contamos con lista de precios B2B, cupo comercial y atención preferencial '
    'para contratistas, talleres e integradores HVAC.';

Json _faq(String question, String answer) => {
  'title': question,
  'body': answer,
};

final Map<String, List<Json>> _brandBlocks = {
  'daikin': [
    {
      'type': 'hero',
      'title': 'Daikin',
      'subtitle':
          'Perfecting the Air. Línea Daikin · McQuay, la misma familia '
          'comercial en IPR.',
      'accentColor': '#0B2A3F',
    },
    {
      'type': 'highlights',
      'title': 'Tecnología Daikin',
      'items': [
        _faq(
          'VRV: el estándar que Daikin inventó',
          'Un solo sistema para climatizar edificios completos con control '
              'por zona, alta eficiencia y menor consumo. La tecnología que '
              'cambió la industria en 1982.',
        ),
        _faq(
          'Menos impacto, más eficiencia',
          'Tecnologías desarrolladas para reducir el consumo y el impacto '
              'ambiental de cada proyecto, con desempeño comprobado en climas '
              'cálidos.',
        ),
        _faq(
          'Gestión centralizada del aire',
          'Programa, monitorea y diagnostica cada equipo desde un solo punto: '
              'control centralizado para proyectos comerciales e industriales.',
        ),
      ],
    },
    {
      'type': 'faq',
      'title': 'Preguntas frecuentes',
      'items': [
        _faq(
          '¿Los equipos Daikin tienen garantía oficial?',
          'Sí. Todos los equipos se entregan con garantía de fábrica y '
              'respaldo directo de IPR Partes y Repuestos, con facturación '
              'electrónica y soporte técnico local.',
        ),
        _faq(
          '¿Cuándo conviene un sistema VRV o central?',
          'Cuando el proyecto tiene varias zonas o un área amplia (edificios, '
              'hoteles, clínicas, plantas). Nuestro equipo de ingeniería evalúa '
              'carga térmica, recorridos y presupuesto para definir la mejor '
              'solución.',
        ),
        _faq(
          '¿Venden repuestos Daikin y McQuay?',
          'Sí. Manejamos repuestos y accesorios originales de la línea '
              'Daikin · McQuay. Escríbenos con la referencia o el modelo del '
              'equipo y lo cotizamos.',
        ),
        _faq('¿Hacen envíos a todo el país?', _faqEnvio),
      ],
    },
    {
      'type': 'cta',
      'title': '¿Un proyecto con Daikin?',
      'body': 'Nuestro equipo de ingeniería te acompaña desde el diseño.',
      'ctaLabel': 'Hablar con ingeniería',
      'target': {'kind': 'engineering'},
    },
  ],
  'samsung': [
    {
      'type': 'hero',
      'title': 'Samsung',
      'subtitle': 'Tecnología que transforma el confort.',
      'accentColor': '#1428A0',
    },
    {
      'type': 'faq',
      'title': 'Preguntas frecuentes',
      'items': [
        _faq(
          '¿Los equipos tienen garantía oficial?',
          'Sí. Todos los equipos Samsung se entregan con garantía de fábrica '
              'y respaldo directo de IPR Partes y Repuestos, con facturación '
              'electrónica.',
        ),
        _faq('¿Hacen envíos a todo el país?', _faqEnvio),
        _faq(
          '¿Pueden asesorarme para elegir la capacidad correcta?',
          'Sí. Nuestro equipo de ingeniería calcula la capacidad en BTU/h '
              'según el volumen, la carga térmica y el tipo de proyecto, sin '
              'costo adicional.',
        ),
        _faq('¿Manejan precios para contratistas y empresas?', _faqB2b),
      ],
    },
    {
      'type': 'cta',
      'title': 'Jugada Navideña Samsung X IPR',
      'body':
          'Raspa tu tarjeta con cada equipo Samsung que compras en IPR y gana '
          'premios este diciembre.',
      'ctaLabel': 'Conocer la campaña',
      'target': {'kind': 'web', 'ref': '$_site/jugada-samsung'},
    },
  ],
  'midea': [
    {
      'type': 'hero',
      'title': 'Midea',
      'subtitle': 'Simply ideal.',
      'accentColor': '#0098D1',
    },
    {
      'type': 'faq',
      'title': 'Preguntas frecuentes',
      'items': [
        _faq('¿Los equipos Midea tienen garantía oficial?', _faqGarantia),
        _faq(
          '¿Cómo sé qué capacidad en BTU necesito?',
          'Nuestro equipo de ingeniería calcula la capacidad según el área, '
              'la carga térmica y el tipo de proyecto. También puedes usar la '
              'calculadora BTU y validar el resultado con un asesor.',
        ),
        _faq('¿Hacen envíos a todo el país?', _faqEnvio),
        _faq('¿Manejan precios para contratistas y empresas?', _faqB2b),
      ],
    },
    {
      'type': 'cta',
      'title': 'Parche Midea X IPR',
      'body':
          'Compra tu aire acondicionado Midea, registra tu factura y gira la '
          'ruleta.',
      'ctaLabel': 'Conocer la campaña',
      'target': {'kind': 'web', 'ref': '$_site/parche-midea'},
    },
  ],
  'gree': [
    {
      'type': 'hero',
      'title': 'Gree',
      'subtitle':
          'Eficiencia que evoluciona. Mini split Inverter DC con etiqueta '
          'energética clase A.',
      'accentColor': '#164194',
    },
    {
      'type': 'highlights',
      'title': 'Líneas y diferenciales Gree',
      'items': [
        _faq(
          'Línea Fairy Inverter',
          'Inverter DC con eficiencia energética 3,75 Wt/We, tres filtros de '
              'aire y purificación Cold Plasma en 12.000, 18.000 y 24.000 BTU '
              'a 220 V.',
        ),
        _faq(
          'Cosmos Solar listo para paneles',
          'Versión preparada para trabajar con energía solar, eficiencia de '
              'hasta 4,00 Wt/We en 12.000 BTU y operación estable de 16 a 52 °C.',
        ),
        _faq(
          'Garantía oficial Gree Colombia',
          '1 año de garantía en partes y 10 años en el compresor, con '
              'facturación electrónica y respaldo directo de IPR.',
        ),
      ],
    },
    {
      'type': 'faq',
      'title': 'Preguntas frecuentes',
      'items': [
        _faq(
          '¿Cuál es la diferencia entre la línea Fairy y la Cosmos Solar?',
          'Las dos son mini split Inverter a 220 V con etiqueta energética A. '
              'Cosmos Solar está preparada para conexión a paneles solares, '
              'con eficiencia de hasta 4,00 Wt/We frente a 3,75 Wt/We de Fairy.',
        ),
        _faq(
          '¿El panel solar viene incluido con el equipo?',
          'No. La línea Cosmos Solar está preparada para trabajar con energía '
              'solar, pero el panel solar no va incluido con el equipo. Te '
              'asesoramos sobre el arreglo fotovoltaico de tu proyecto.',
        ),
        _faq(
          '¿Cómo sé qué capacidad en BTU necesito?',
          'Como referencia se calculan unos 230 BTU por metro cúbico. Usa '
              'nuestra calculadora de BTU o envíanos el volumen y la carga '
              'térmica del espacio para recomendarte la referencia exacta.',
        ),
        _faq('¿Hacen envíos a todo el país?', _faqEnvio),
        _faq('¿Manejan precios para empresas y proyectos?', _faqB2b),
      ],
    },
    {
      'type': 'cta',
      'title': '¿Necesitas asesoría para elegir tu Gree?',
      'body':
          'Dimensionamos la capacidad según el área y la carga térmica de tu '
          'proyecto.',
      'ctaLabel': 'Hablar con ingeniería',
      'target': {'kind': 'engineering'},
    },
  ],
  'hisense': [
    {
      'type': 'hero',
      'title': 'Hisense',
      'subtitle':
          'Dale un plus a tu espacio. Aires acondicionados Inverter para hogar '
          'y oficina.',
      'accentColor': '#00827F',
    },
    {
      'type': 'highlights',
      'title': 'Series y diferenciales Hisense',
      'items': [
        _faq(
          'Serie Perla (110 V y 220 V)',
          'Tecnología Inverter de bajo consumo con modos de sueño '
              'diferenciados, disponible en 12.000, 18.000 y 24.000 BTU.',
        ),
        _faq(
          'Luso Premium Negro',
          'Diseño en acabado negro de 12.000 BTU a 220 V con auto limpieza, '
              'filtro de catequinas y compuerta 4D.',
        ),
        _faq(
          'Compuerta 4D y confort nocturno',
          'Distribución del aire en cuatro direcciones y perfiles de sueño '
              'pensados para el descanso de toda la familia.',
        ),
      ],
    },
    {
      'type': 'faq',
      'title': 'Preguntas frecuentes',
      'items': [
        _faq(
          '¿Cuál es la diferencia entre la serie Perla y la Luso Premium?',
          'Perla usa modos de sueño diferenciados en 12.000 a 24.000 BTU. '
              'Luso Premium Negro es de 12.000 BTU con acabado negro, auto '
              'limpieza, filtro de catequinas y compuerta 4D.',
        ),
        _faq(
          '¿Hay equipos en 110 V?',
          'Sí. La serie Perla de 12.000 BTU está disponible en 110 V y 220 V. '
              'Las capacidades de 18.000 y 24.000 BTU, y la Luso Premium, son '
              'a 220 V.',
        ),
        _faq('¿Los equipos tienen garantía oficial?', _faqGarantia),
        _faq('¿Hacen envíos a todo el país?', _faqEnvio),
      ],
    },
    {
      'type': 'cta',
      'title': '¿Buscas el Hisense ideal para tu espacio?',
      'body': 'Calcula los BTU recomendados según las medidas de tu espacio.',
      'ctaLabel': 'Calcular BTU',
      'target': {'kind': 'calculator'},
    },
  ],
  'trane': [
    {
      'type': 'hero',
      'title': 'Trane',
      'subtitle':
          'Eficiencia energética líder para proyectos residenciales y '
          'comerciales.',
      'accentColor': '#DA291C',
    },
    {
      'type': 'highlights',
      'title': 'Líneas Trane en IPR',
      'items': [
        _faq(
          'Mini Split Inverter 220 V',
          'Equipos residenciales y de oficina de 12.000, 18.000 y 24.000 BTU '
              'con compresor de velocidad variable.',
        ),
        _faq(
          'Paquetes condensados por agua',
          'Capacidades de 3 y 5 TR para sistemas centrales que no dependen de '
              'intercambio directo con el aire exterior.',
        ),
        _faq(
          'Condensadora y manejadora 5 TR SEER 14',
          'Unidad condensadora comercial Inverter con eficiencia SEER 14 a '
              '220 V y su manejadora compatible.',
        ),
      ],
    },
    {
      'type': 'faq',
      'title': 'Preguntas frecuentes',
      'items': [
        _faq(
          '¿Qué significa la capacidad en TR de los equipos comerciales?',
          'TR significa tonelada de refrigeración y dimensiona los equipos '
              'comerciales. La condensadora y manejadora Trane son de 5 TR, y '
              'el paquete condensado por agua está disponible en 3 TR y 5 TR.',
        ),
        _faq(
          '¿Con qué voltaje operan?',
          'Los mini splits de 12.000, 18.000 y 24.000 BTU y la condensadora '
              'de 5 TR operan a 220 V.',
        ),
        _faq('¿Manejan equipos y precios para proyectos?', _faqB2b),
        _faq('¿Los equipos tienen garantía oficial?', _faqGarantia),
      ],
    },
    {
      'type': 'cta',
      'title': '¿Un proyecto comercial con Trane?',
      'body':
          'Nuestro equipo de ingeniería dimensiona la capacidad y el sistema '
          'correcto para tu proyecto.',
      'ctaLabel': 'Hablar con ingeniería',
      'target': {'kind': 'engineering'},
    },
  ],
  'rowa': [
    {
      'type': 'hero',
      'title': 'Rowa',
      'subtitle': 'El aire ideal para tu espacio. Líneas Elite Inverter y Elite On/Off.',
      'accentColor': '#7250D9',
    },
    {
      'type': 'highlights',
      'title': 'Tecnología y líneas Rowa',
      'items': [
        _faq(
          'Elite Inverter (9.000 a 24.000 BTU)',
          'Compresor de velocidad variable que modula su potencia según la '
              'carga térmica, con arranque suave y operación silenciosa.',
        ),
        _faq(
          'Elite On/Off (110 V y 220 V)',
          'Opción convencional de instalación sencilla, disponible en doble '
              'voltaje para adaptarse a la red eléctrica del proyecto.',
        ),
        _faq(
          'Respaldo y garantía de 12 meses',
          'Stock real en bodega, facturación electrónica, repuestos y '
              'asesoría de ingeniería IPR.',
        ),
      ],
    },
    {
      'type': 'faq',
      'title': 'Preguntas frecuentes',
      'items': [
        _faq(
          '¿Cuál es la diferencia entre Elite Inverter y Elite On/Off?',
          'Elite Inverter usa compresor de velocidad variable para mantener '
              'la temperatura estable con menor consumo. Elite On/Off es la '
              'opción convencional disponible en 110 V y 220 V.',
        ),
        _faq(
          '¿Los equipos Rowa tienen garantía oficial?',
          'Sí. Todos los equipos se entregan con 12 meses de garantía de '
              'fábrica y respaldo directo de IPR Partes y Repuestos.',
        ),
        _faq('¿Hacen envíos a todo el país?', _faqEnvio),
        _faq('¿Manejan precios para empresas y proyectos?', _faqB2b),
      ],
    },
    {
      'type': 'cta',
      'title': 'Cotiza tu equipo Rowa',
      'body': 'Stock real en bodega y despacho nacional con asesoría técnica.',
      'ctaLabel': 'Hablar con un asesor',
      'target': {
        'kind': 'whatsapp',
        'ref': 'Hola IPR, quiero cotizar equipos Rowa.',
      },
    },
  ],
  'danfoss': [
    {
      'type': 'hero',
      'title': 'Danfoss',
      'subtitle': 'Ingeniería danesa para la refrigeración mundial.',
      'accentColor': '#C8102E',
    },
    {
      'type': 'highlights',
      'title': 'Ciclo completo de refrigeración',
      'items': [
        _faq(
          'Compresores scroll y unidades condensadoras',
          'Compresores scroll para R22, R410A y R404A trifásicos de 4 y 7 HP, '
              'y unidades condensadoras Optyma Slim Pack y micro canal.',
        ),
        _faq(
          'Válvulas de expansión y solenoides',
          'Cuerpos, elementos y orificios TE5 y TE12, solenoides EVR con '
              'bobina, reguladoras KVL/KVP, cheque, bola y balanceo LENO.',
        ),
        _faq(
          'Presostatos KP, controles EKC y ERC',
          'Presostatos KP1, KP5 y KP15, termostatos UT72, controles EKC 202C '
              'y ERC 211A, sensores PTC y filtros deshidratadores DML.',
        ),
      ],
    },
    {
      'type': 'faq',
      'title': 'Preguntas frecuentes',
      'items': [
        _faq(
          '¿Qué compresores Danfoss manejan?',
          'Compresores scroll para refrigeración y aire acondicionado en R22, '
              'R410A y R404A, trifásicos de 4 y 7 HP, además de unidades '
              'condensadoras Optyma y Scroll Slim.',
        ),
        _faq(
          '¿Tienen válvulas de expansión y sus repuestos?',
          'Sí. Manejamos cuerpos TE5 y TE12, elementos, orificios y toberas '
              'por capacidad para reemplazo o repotenciación.',
        ),
        _faq(
          '¿Manejan controles electrónicos y sensores?',
          'Sí: control ERC 211A, control EKC 202C, sensores PTC y controles '
              'de nivel de aceite en 24 V y 230 V.',
        ),
        _faq('¿Atienden proyectos y precios B2B?', _faqB2b),
      ],
    },
    {
      'type': 'cta',
      'title': '¿Necesitas soporte técnico en refrigeración?',
      'body':
          'Te ayudamos a seleccionar compresor, válvula, control y accesorios '
          'Danfoss.',
      'ctaLabel': 'Hablar con ingeniería',
      'target': {'kind': 'engineering'},
    },
  ],
  'aspen': [
    {
      'type': 'hero',
      'title': 'Aspen Pumps',
      'subtitle':
          'Bombas de condensado y herramientas para aire acondicionado.',
      'accentColor': '#A63A12',
    },
    {
      'type': 'highlights',
      'title': 'Líneas Aspen en IPR',
      'items': [
        _faq(
          'Bombas de condensado (12 a 511 L/h)',
          'Mini Blanc, Mini Orange y Silence+ Mini White de 12 L/h, Maxi '
              'Orange de 26 L/h y M4 Tank de 379 y 511 L/h con tanque.',
        ),
        _faq(
          'Repuestos originales de instalación',
          'Manguera Aspen de 1/4 y filtro de protección para las líneas Mini, '
              'Maxi y Aqua.',
        ),
        _faq(
          'Herramientas para tubería de cobre',
          'Enderezadores manuales en medidas 1/4, 3/8, 1/2 y 5/8 para '
              'instalación y mantenimiento.',
        ),
      ],
    },
    {
      'type': 'faq',
      'title': 'Preguntas frecuentes',
      'items': [
        _faq(
          '¿Cómo elijo la bomba de condensado correcta?',
          'Depende del caudal que genera tu equipo y del desnivel al '
              'desagüe. Manejamos desde 12 L/h (línea Mini) hasta 511 L/h '
              '(M4 Tank).',
        ),
        _faq(
          '¿Tienen una bomba silenciosa?',
          'Sí, la Silence+ Mini White está pensada para instalaciones donde el '
              'ruido es crítico, como dormitorios y oficinas.',
        ),
        _faq(
          '¿Venden mangueras, filtros y herramientas para cobre?',
          'Sí. Manejamos manguera de 1/4, filtros de repuesto y enderezadores '
              'manuales de tubo de cobre de 1/4 a 5/8.',
        ),
        _faq('¿Atienden proyectos y precios B2B?', _faqB2b),
      ],
    },
    {
      'type': 'cta',
      'title': 'Cotiza bombas y repuestos Aspen',
      'body':
          'Te ayudamos a elegir caudal, voltaje y accesorios según tu '
          'instalación.',
      'ctaLabel': 'Hablar con un asesor',
      'target': {
        'kind': 'whatsapp',
        'ref': 'Hola IPR, quiero cotizar bombas y repuestos Aspen.',
      },
    },
  ],
  'fullgauge': [
    {
      'type': 'hero',
      'title': 'Full Gauge',
      'subtitle':
          'Control electrónico de precisión para refrigeración, climatización '
          'y monitoreo Sitrad.',
      'accentColor': '#014F1E',
    },
    {
      'type': 'highlights',
      'title': 'Del sensor a la nube con Sitrad',
      'items': [
        _faq(
          'Controladores para cada aplicación',
          'Referencias como MT-543E LOG, TC-900E POWER, MT-512E y TI-44E Plus '
              'para cámaras, congelación, exhibidores y racks.',
        ),
        _faq(
          'Sondas, presión y medición de energía',
          'Sensores NTC/Pt100 serie SB, sensores de presión PCT/SB-69 y '
              'medidores EnergyLog y PhaseLog.',
        ),
        _faq(
          'Monitoreo remoto Sitrad',
          'Convertidores Conv32, TCP-485 y Sitrad Inbox para alertas por '
              'correo y celular e histórico para auditorías sanitarias.',
        ),
      ],
    },
    {
      'type': 'faq',
      'title': 'Preguntas frecuentes',
      'items': [
        _faq(
          '¿Qué es Sitrad y qué necesito para usarlo?',
          'Sitrad es el software de monitoreo remoto de Full Gauge. Necesitas '
              'un convertidor o datalogger (Conv32, TCP-485 o Sitrad Inbox) y '
              'el software gratuito de Full Gauge.',
        ),
        _faq(
          '¿Tienen sensores y repuestos para controladores instalados?',
          'Sí. Manejamos sondas SB, módulos expansores, cajas y accesorios de '
              'instalación para mantener tus equipos Full Gauge.',
        ),
        _faq(
          '¿Los productos Full Gauge tienen garantía oficial?',
          _faqGarantia,
        ),
        _faq('¿Manejan precios para contratistas y empresas?', _faqB2b),
      ],
    },
    {
      'type': 'cta',
      'title': '¿Armamos tu sistema Full Gauge?',
      'body':
          'Cuéntanos tu aplicación y te recomendamos controlador, sonda y '
          'conectividad Sitrad.',
      'ctaLabel': 'Hablar con ingeniería',
      'target': {'kind': 'engineering'},
    },
  ],
  'elitech': [
    {
      'type': 'hero',
      'title': 'Elitech',
      'subtitle': 'Instrumentos de medición y diagnóstico HVAC/R de precisión.',
      'accentColor': '#0060A8',
    },
    {
      'type': 'highlights',
      'title': 'Instrumentación Elitech para el técnico',
      'items': [
        _faq(
          'Diagnóstico sin contacto',
          'Cámara termográfica TIC-210 (-20 a 150 °C) y detectores de fugas '
              'para refrigerantes HFC, HFO, HC y CO2.',
        ),
        _faq(
          'Vacío y presión digitales',
          'Bomba de vacío digital de 12 CFM, vacuómetro Bluetooth VGW-760, '
              'manómetro inteligente y manifold digital.',
        ),
        _faq(
          'Termómetros, dataloggers y balanzas',
          'Termómetros tipo K, dataloggers GSP-6 y RC-5+, balanzas Bluetooth '
              'y tableros WiFi para cuartos fríos.',
        ),
      ],
    },
    {
      'type': 'faq',
      'title': 'Preguntas frecuentes',
      'items': [
        _faq(
          '¿Con qué refrigerantes funcionan los detectores de fugas?',
          'Manejamos detectores para HFC, HFO y HC, para CO2 (R744) y para '
              'R600, R290 y refrigerantes tradicionales, según el modelo.',
        ),
        _faq(
          '¿Qué instrumentos de vacío y presión manejan?',
          'Bomba de vacío digital de 12 CFM y 2 etapas, vacuómetros Bluetooth '
              'e inalámbrico, manómetro inteligente, manifold digital y reloj '
              'Pg-30 Pro.',
        ),
        _faq('¿Los instrumentos tienen garantía oficial?', _faqGarantia),
        _faq('¿Manejan precios para contratistas y empresas?', _faqB2b),
      ],
    },
    {
      'type': 'cta',
      'title': '¿Necesitas seleccionar un instrumento Elitech?',
      'body':
          'Cuéntanos la aplicación y el refrigerante para cotizar la '
          'referencia exacta.',
      'ctaLabel': 'Hablar con un asesor',
      'target': {
        'kind': 'whatsapp',
        'ref': 'Hola IPR, quiero cotizar instrumentos Elitech.',
      },
    },
  ],
  'ipr': [
    {
      'type': 'hero',
      'title': 'IPR',
      'subtitle':
          'Soluciones integrales en climatización: equipos, repuestos y '
          'herramientas de marca propia.',
      'accentColor': '#2A7D28',
    },
    {
      'type': 'text',
      'title': 'Respaldo directo de IPR Partes y Repuestos',
      'body':
          'Toda la línea propia IPR con stock nacional: equipos de aire '
          'acondicionado, cortinas de aire, refrigeración y cuartos fríos, '
          'herramientas para cobre y gases, repuestos eléctricos y accesorios '
          'de control.',
    },
    {
      'type': 'highlights',
      'title': 'Líneas propias IPR',
      'items': [
        _faq(
          'Aire acondicionado y cortinas de aire',
          'Mini splits, cassettes, piso-techo, condensadoras, manejadoras y '
              'cortinas comerciales e industriales para accesos.',
        ),
        _faq(
          'Refrigeración y cuartos fríos',
          'Evaporadores, difusores, condensadores, motores y controles para '
              'conservación y congelación.',
        ),
        _faq(
          'Herramientas, eléctricos y accesorios',
          'Herramientas para cobre y gases, protectores de voltaje, '
              'capacitores, relays, transformadores y consumibles.',
        ),
      ],
    },
    {
      'type': 'faq',
      'title': 'Preguntas frecuentes',
      'items': [
        _faq('¿Los productos IPR tienen garantía oficial?', _faqGarantia),
        _faq('¿Hacen envíos a todo el país?', _faqEnvio),
        _faq('¿Manejan precios para contratistas y empresas?', _faqB2b),
      ],
    },
    {
      'type': 'cta',
      'title': '¿Buscas una referencia de la línea IPR?',
      'body':
          'Consulta con nuestros asesores comerciales para cotizar equipos, '
          'repuestos o herramientas IPR.',
      'ctaLabel': 'Hablar con un asesor',
      'target': {
        'kind': 'whatsapp',
        'ref': '¡Hola IPR! Quiero asesoría sobre productos de la marca IPR.',
      },
    },
  ],
};
