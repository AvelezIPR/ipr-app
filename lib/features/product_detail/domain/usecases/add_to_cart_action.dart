import 'package:ipr_mobile/core/network/result.dart';

/// Costura hacia el carrito (M3). La ficha **no** conoce el carrito: pide
/// añadir un producto y una cantidad a través de esta interfaz. En M1 no hay
/// implementación registrada y el botón "Agregar al carrito" no se muestra.
///
/// La implementación (en `features/cart`) valida el tope de 100 líneas, la
/// fusión de cantidades y la persistencia local; aquí solo se conoce el
/// resultado.
abstract interface class AddToCartAction {
  /// Añade [quantity] unidades del producto [productId]. `Ok` si quedó en el
  /// carrito; `Err` con el motivo si no.
  Future<Result<void>> add({required int productId, required int quantity});
}
