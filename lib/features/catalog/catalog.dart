/// API pública de la feature de catálogo: solo las pantallas de nivel de ruta.
/// El orquestador declara los `GoRoute` en `lib/app/router/app_router.dart`:
///
/// * `Routes.catalog` → `CatalogScreen()` (pestaña)
/// * `Routes.catalogList` → `ProductListScreen(categorySlug: query['category'])`
/// * `Routes.brands` → `BrandsScreen()`
/// * `Routes.brandPrefix/:slug` → `BrandLandingScreen(slug: slug)`
/// * `Routes.sale` → `SaleScreen()`
library;

export 'presentation/screens/brand_landing_screen.dart' show BrandLandingScreen;
export 'presentation/screens/brands_screen.dart' show BrandsScreen;
export 'presentation/screens/catalog_screen.dart' show CatalogScreen;
export 'presentation/screens/product_list_screen.dart' show ProductListScreen;
export 'presentation/screens/sale_screen.dart' show SaleScreen;
