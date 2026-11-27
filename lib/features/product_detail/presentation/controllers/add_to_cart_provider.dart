import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderFamily;
import 'package:ipr_mobile/features/product_detail/domain/usecases/add_to_cart_action.dart';

/// Costura hacia el carrito. Es `null` por defecto: sin acción registrada la
/// ficha **no** muestra "Agregar al carrito". La app la conecta al carrito
/// real con `productDetailCartOverrides` (ver `product_detail.dart`); las
/// pruebas de la ficha registran un doble.
final addToCartActionProvider = Provider<AddToCartAction?>((ref) => null);

/// Cantidad de un producto ya presente en el carrito (`productId`). Por
/// defecto es `0`; la app la conecta al carrito real con
/// `productDetailCartOverrides` y las pruebas aisladas pueden sobrescribirla.
final ProviderFamily<int, int> cartQuantityForProductProvider =
    Provider.family<int, int>((ref, productId) => 0);
