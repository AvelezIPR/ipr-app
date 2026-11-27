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

/// Nodo del árbol de subcategorías de demostración: un nombre, o un nombre
/// con hijos (`_Node('Mini splits')` / `_Node('Cobre', [_Node('Codos')])`).
final class _Node {
  const new(this.name, [this.children = const []]);

  final String name;
  final List<_Node> children;
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
  _Category(3, 'repuestos-aa', 'Eléctricos'),
  _Category(4, 'tuberia-accesorios-capilares', 'Materiales y Consumibles'),
  _Category(5, 'herramientas', 'Herramientas'),
  _Category(6, 'tableros-y-controles', 'Tableros y Controles'),
  _Category(7, 'ventilacion', 'Ventilación'),
  _Category(8, 'refrigerantes', 'Refrigerantes'),
];

/// Marcas con página propia (slug → nombre).
const _brands = {
  'daikin': 'Daikin',
  'danfoss': 'Danfoss',
  'copeland': 'Copeland',
  'samsung': 'Samsung',
  'midea': 'Midea',
  'gree': 'Gree',
  'hisense': 'Hisense',
  'embraco': 'Embraco',
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
  final String category;
  final String? brand;

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
    category: 'herramientas',
    brand: 'elitech',
  ),
  _Product(
    id: 105,
    slug: 'controlador-electronico-full-gauge-conservacion-mt512e-2hp-110-220v-full-gauge-3614',
    name: 'Controlador Mt512e-2hp Full Gauge 110/220v',
    sku: '180-0025',
    amount: 75800,
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

/// (slug, ciudad, nombre, dirección). Dirección vacía = por confirmar.
const _stores = <(String, String, String, String)>[
  (
    'medellin-sede-principal-guayabal',
    'Medellín',
    'Sede Principal Guayabal',
    'Calle 14 sur #51c-5',
  ),
  ('medellin-cundinamarca', 'Medellín', 'Cundinamarca', 'Cra. 53 #58-66'),
  ('medellin-carabobo', 'Medellín', 'Carabobo', 'Calle 59 #51d-71'),
  (
    'medellin-carabobo-industrial',
    'Medellín',
    'Carabobo Industrial',
    'Calle 59 No 52-18',
  ),
  ('medellin-la-america', 'Medellín', 'La América', 'Cl. 44 #79-105'),
  ('medellin-av-oriental', 'Medellín', 'Av Oriental', 'Carrera 46 #40-06'),
  ('medellin-itagui', 'Medellín', 'Itagüí', 'Calle 63 #44-70'),
  ('medellin-bello', 'Medellín', 'Bello', 'Carrera 50 #32-23'),
  ('medellin-cristo-rey', 'Medellín', 'Cristo Rey', 'Carrera 52 #2sur-44'),
  ('cali-sede-principal', 'Cali', 'Sede Principal', ''),
  ('cali-la-flora', 'Cali', 'La Flora', ''),
  ('cali-san-nicolas', 'Cali', 'San Nicolás', ''),
  ('cali-pasoancho', 'Cali', 'Pasoancho', ''),
  ('cali-la-quinta', 'Cali', 'La Quinta', ''),
  ('barranquilla-sede-principal', 'Barranquilla', 'Sede Principal Centro', ''),
  ('barranquilla-centro', 'Barranquilla', 'Centro', ''),
  ('barranquilla-industrial', 'Barranquilla', 'Barranquilla Industrial', ''),
  ('barranquilla-la-43', 'Barranquilla', 'La 43', ''),
  ('barranquilla-la-66-el-rosario', 'Barranquilla', 'La 66 El Rosario', ''),
  ('bucaramanga-sede-principal', 'Bucaramanga', 'Sede Principal', ''),
  ('bucaramanga-alarcon', 'Bucaramanga', 'Alarcón', ''),
  ('bucaramanga-industrial', 'Bucaramanga', 'Industrial', ''),
  ('bogota-sede-principal', 'Bogotá', 'Sede Principal', ''),
  ('bogota-av-19', 'Bogotá', 'Av 19', ''),
  ('bogota-chapinero', 'Bogotá', 'Chapinero', ''),
  ('monteria-sede-principal', 'Montería', 'Sede principal', ''),
  ('monteria-industrial', 'Montería', 'Industrial', ''),
  ('villavicencio-sede-principal', 'Villavicencio', 'Sede Villavicencio', ''),
  ('villavicencio-industrial', 'Villavicencio', 'Industrial', ''),
  ('rionegro', 'Rionegro', 'Sede Rionegro', ''),
  ('apartado', 'Apartadó', 'Apartadó', ''),
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
}) => switch (template) {
  '/config' => _config(example),
  '/categories' => {'data': _categoryJson()},
  '/brands' => {'data': _brandJson()},
  '/brands/{slug}' => _brandLanding(path),
  '/stores' => {'data': _storeJson()},
  '/products' => _productPage(query),
  '/search' => _productPage(query, searching: true),
  '/filters' => {'data': _filterJson(query)},
  '/products/{slug}' => _productDetail(path),
  _ => null,
};

/// `Capacidad BTU` → `capacidad-btu` (parte de la clave `attr[pa_…]`).
String _attrSlug(String name) => _fold(name).replaceAll(' ', '-');

/// Filtros disponibles para el listado: marca y los atributos que tienen los
/// productos de la categoría pedida (nada inventado: solo lo que hay).
List<Json> _filterJson(Map<String, String> query) {
  final category = query['category'];
  final scope = [
    for (final p in _products)
      if (category == null || category.isEmpty || p.category == category) p,
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
  if (contact is Json && contact['engineering'] is Json) {
    (contact['engineering']! as Json)['specialties'] =
        _engineeringSpecialties();
  }
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

  final activeBranches = _stores.length;
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
      },
      {
        'id': 'references',
        'value': '+10.000',
        'unit': null,
        'label':
            'Referencias para Aire Acondicionado, Refrigeración y '
            'Ventilación',
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
    ],
  };
}

List<Json> _categoryJson() {
  // Los hijos reciben ids desde 100, para no chocar con los de las raíces.
  var nextId = 100;
  List<Json> children(List<_Node> nodes, int parentId) => [
    for (final node in nodes)
      () {
        final id = nextId++;
        return {
          'id': id,
          'slug': _fold(node.name).replaceAll(RegExp('[^a-z0-9]+'), '-'),
          'name': node.name,
          'parentId': parentId,
          'children': children(node.children, id),
        };
      }(),
  ];
  return [
    for (final c in _categories)
      {
        'id': c.id,
        'slug': c.slug,
        'name': c.name,
        'parentId': null,
        'children': children(_subcategories[c.slug] ?? const [], c.id),
      },
  ];
}

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
  for (final (slug, city, name, address) in _stores)
    {
      'slug': slug,
      'city': city,
      'name': name,
      'address': address.isEmpty ? _pendingAddress : address,
      'upcoming': false,
      'phones': <Json>[],
      'whatsapp': null,
      'imageUrl': null,
      'mapsQuery': address.isEmpty ? null : '$address, $city, Colombia',
      'coordinates': null,
      'openingHours': null,
    },
  // Sede anunciada por la web como "próxima apertura".
  {
    'slug': 'cartagena',
    'city': 'Cartagena',
    'name': 'Próxima apertura',
    'address': _pendingAddress,
    'upcoming': true,
    'phones': <Json>[],
    'whatsapp': null,
    'imageUrl': null,
    'mapsQuery': null,
    'coordinates': null,
    'openingHours': null,
  },
];

Json _summary(_Product p) {
  final brand = p.brand;
  final image = p.image;
  return {
    'id': p.id,
    'slug': p.slug,
    'name': p.name,
    'sku': p.sku,
    'brand': brand == null ? null : {'name': _brands[brand], 'slug': brand},
    'price': {
      'status': 'priced',
      'amount': p.amount,
      'regularAmount': p.amount,
      'onSale': false,
      'discountPercent': null,
      'currency': 'COP',
      'taxIncluded': true,
    },
    'availability': 'in_stock',
    'purchasable': p.purchasable,
    'image': image == null
        ? null
        : {'url': '$_media/$image', 'alt': p.name, 'width': 600, 'height': 600},
    'categorySlugs': [p.category],
    if (p.variants.isNotEmpty) ...{
      'hasVariants': true,
      'priceFrom': p.variants.map((v) => v.amount).reduce(math.min),
    },
  };
}

Json _productPage(Map<String, String> query, {bool searching = false}) {
  var items = _products.toList();

  final category = query['category'];
  if (category != null && category.isNotEmpty) {
    items = items.where((p) => p.category == category).toList();
  }
  final brands = (query['brand'] ?? '')
      .split(',')
      .where((b) => b.isNotEmpty)
      .toSet();
  if (brands.isNotEmpty) {
    items = items.where((p) => brands.contains(p.brand)).toList();
  }
  if (query['onSale'] == 'true') items = const [];
  items = items.where((p) => _matchesAttributes(p, query)).toList();

  final text = _fold(query['q'] ?? '');
  if (searching && text.isNotEmpty) {
    final terms = text.split(' ').where((t) => t.isNotEmpty);
    items = items.where((p) {
      final haystack = _fold('${p.name} ${p.sku} ${_brands[p.brand] ?? ''}');
      return terms.every(haystack.contains);
    }).toList();
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
  final category = _categories.firstWhere((c) => c.slug == product.category);
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

/// Landings de marca de DEMOSTRACIÓN (W3-01): textos reales de las landings de
/// la web de IPR (Daikin, Samsung y Midea; 2026-11-26) adaptados a bloques.
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
};
