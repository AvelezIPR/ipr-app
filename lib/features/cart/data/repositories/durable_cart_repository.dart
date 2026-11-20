import 'package:ipr_mobile/core/storage/durable_store.dart';
import 'package:ipr_mobile/features/cart/data/mappers/cart_storage_codec.dart';
import 'package:ipr_mobile/features/cart/domain/entities/cart.dart';
import 'package:ipr_mobile/features/cart/domain/repositories/cart_repositories.dart';

/// Carrito en el almacén duradero local (sin caducidad, sin PII).
///
/// * Lectura tolerante: datos ausentes, corruptos o de otra versión → carrito
///   vacío, sin excepción (un archivo roto nunca debe tumbar la app).
/// * Escritura tras cada cambio; un carrito vacío borra la clave. Un fallo del
///   disco se traga: el carrito sigue en memoria y el usuario no pierde la
///   sesión de compra (no se registra nada del contenido).
final class DurableCartRepository implements CartLocalRepository {
  const new(this._store);

  final DurableStore _store;

  @override
  Future<Cart> load() async {
    try {
      return CartStorageCodec.decode(
        await _store.read(CartStorageCodec.storageKey),
      );
    } on Object {
      return Cart.empty;
    }
  }

  @override
  Future<void> save(Cart cart) async {
    try {
      if (cart.isEmpty) {
        await _store.remove(CartStorageCodec.storageKey);
      } else {
        await _store.write(
          CartStorageCodec.storageKey,
          CartStorageCodec.encode(cart),
        );
      }
    } on Object {
      // Ver la documentación de la clase.
    }
  }

  @override
  Future<void> clear() => save(Cart.empty);
}
