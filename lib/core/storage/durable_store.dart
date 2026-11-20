import 'package:hive_ce/hive.dart';

/// Almacén local **duradero** de documentos pequeños sin PII, p. ej. el
/// carrito (`flutter_app_architecture.md` §8, RF-049).
///
/// A diferencia de `CacheStore` no caduca ni expulsa por LRU: lo guardado
/// permanece hasta que la feature lo borra. Se usa solo para datos que son
/// fuente local de verdad. Los datos personales no van aquí (CR-065).
abstract interface class DurableStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> remove(String key);
}

/// Implementación con `hive_ce` (caja `cart`, sin cifrar porque no guarda PII).
final class HiveDurableStore implements DurableStore {
  const new(this._box);

  final Box<String> _box;

  @override
  Future<String?> read(String key) async => _box.get(key);

  @override
  Future<void> write(String key, String value) => _box.put(key, value);

  @override
  Future<void> remove(String key) => _box.delete(key);
}

/// Implementación en memoria para pruebas.
final class MemoryDurableStore implements DurableStore {
  new([Map<String, String>? initial]) : data = {...?initial};

  final Map<String, String> data;

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async => data[key] = value;

  @override
  Future<void> remove(String key) async => data.remove(key);
}
