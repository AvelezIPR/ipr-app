// API pública de la feature `product_detail`: solo pantallas de ruta.
// El orquestador declara `GoRoute('/product/:slug')` y construye
// `ProductDetailScreen(slug: state.pathParameters['slug']!)`.
export 'package:ipr_mobile/features/product_detail/presentation/screens/product_detail_screen.dart'
    show ProductDetailScreen;
