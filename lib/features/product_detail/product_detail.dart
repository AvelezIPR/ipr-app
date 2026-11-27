// API pública de la feature `product_detail`: pantallas de ruta y el cableado
// con el carrito.
//
// El orquestador declara `GoRoute('/product/:slug')` y construye
// `ProductDetailScreen(slug: state.pathParameters['slug']!)`, y añade
// [productDetailCartOverrides] a los overrides de la app para que "Agregar al
// carrito" use el carrito real.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:ipr_mobile/features/cart/cart.dart';
import 'package:ipr_mobile/features/product_detail/data/cart_backed_add_to_cart_action.dart';
import 'package:ipr_mobile/features/product_detail/presentation/controllers/add_to_cart_provider.dart';

export 'package:ipr_mobile/features/product_detail/presentation/screens/product_detail_screen.dart'
    show ProductDetailScreen;

/// Conecta la costura de la ficha con `features/cart`.
final List<Override> productDetailCartOverrides = [
  addToCartActionProvider.overrideWith(CartBackedAddToCartAction.new),
  cartQuantityForProductProvider.overrideWith((ref, productId) {
    final lines = ref.watch(cartProvider.select((s) => s.lines));
    return lines
        .where((l) => l.productId == productId)
        .fold<int>(0, (sum, l) => sum + l.quantity);
  }),
];
