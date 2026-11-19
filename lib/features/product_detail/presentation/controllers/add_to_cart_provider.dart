import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ipr_mobile/features/product_detail/domain/usecases/add_to_cart_action.dart';

/// Costura hacia el carrito (M3). `null` en M1: sin acción registrada la ficha
/// **no** muestra "Agregar al carrito". En M3, `features/cart` registra aquí
/// su implementación con un `override`.
final addToCartActionProvider = Provider<AddToCartAction?>((ref) => null);
