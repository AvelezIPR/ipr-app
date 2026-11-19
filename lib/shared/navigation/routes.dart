/// Única fuente de rutas (`flutter_app_architecture.md` §6.1).
abstract final class Routes {
  // Pestañas.
  static const home = '/';
  static const catalog = '/catalog';
  static const cart = '/cart';
  static const account = '/account';

  // Autenticación.
  static const login = '/login';
  static const register = '/register';
  static const passwordRecovery = '/password-recovery';

  // Catálogo y búsqueda.
  static const catalogList = '/catalog/list';
  static const brands = '/catalog/brands';
  static const brandPrefix = '/catalog/brands';
  static const sale = '/catalog/sale';
  static const search = '/search';
  static const productPrefix = '/product';

  // Compra.
  static const checkout = '/checkout';
  static const checkoutResult = '/checkout/result';

  // Cuenta.
  static const orders = '/orders';
  static const profile = '/account/profile';
  static const addresses = '/account/addresses';
  static const deleteAccount = '/account/delete';

  // Resto.
  static const branches = '/branches';
  static const btu = '/tools/btu';
  static const support = '/support';
  static const pqrs = '/support/pqrs';
  static const legal = '/support/legal';
  static const engineering = '/support/engineering';
  static const updateRequired = '/update-required';

  // ── Constructores de rutas (las features navegan por aquí, nunca con
  //    cadenas sueltas) ────────────────────────────────────────────────────

  /// Ficha de un producto: `/product/<slug>`.
  static String product(String slug) =>
      '$productPrefix/${Uri.encodeComponent(slug)}';

  /// Landing de una marca: `/catalog/brands/<slug>`.
  static String brand(String slug) =>
      '$brandPrefix/${Uri.encodeComponent(slug)}';

  /// Listado de una categoría: `/catalog/list?category=<slug>`.
  static String categoryList(String slug) =>
      Uri(path: catalogList, queryParameters: {'category': slug}).toString();

  /// Resultados de búsqueda: `/search?q=<texto>`.
  static String searchFor(String query) =>
      Uri(path: search, queryParameters: {'q': query}).toString();

  /// Rutas que exigen sesión (guarda del router).
  static const protectedPrefixes = <String>[
    checkout,
    orders,
    profile,
    addresses,
    deleteAccount,
  ];

  /// Prefijos internos válidos para el parámetro `from` del login.
  static const knownPrefixes = <String>[
    catalog,
    cart,
    account,
    search,
    productPrefix,
    checkout,
    orders,
    branches,
    btu,
    support,
  ];

  static bool isProtected(String path) =>
      protectedPrefixes.any((p) => path == p || path.startsWith('$p/'));

  /// Ruta interna segura para volver tras el login. Cualquier cosa que no sea
  /// una ruta interna conocida (URL externa, `//host`, esquemas) → inicio.
  static String safeInternal(String? from) {
    if (from == null || from.isEmpty) return home;
    if (!from.startsWith('/') || from.startsWith('//')) return home;
    if (from.contains(r'\') || from.contains('://')) return home;
    final path = Uri.tryParse(from)?.path;
    if (path == null) return home;
    if (path == home) return home;
    final known = knownPrefixes.any((p) => path == p || path.startsWith('$p/'));
    return known ? from : home;
  }
}
