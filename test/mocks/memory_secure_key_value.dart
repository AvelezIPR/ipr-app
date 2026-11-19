import 'package:ipr_mobile/core/storage/secure_key_value.dart';

/// Almacén seguro en memoria para pruebas.
final class InMemorySecureKeyValue implements SecureKeyValue {
  new([Map<String, String>? initial]) : data = {...?initial};

  final Map<String, String> data;

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async => data[key] = value;

  @override
  Future<void> delete(String key) async => data.remove(key);

  @override
  Future<void> deleteAll() async => data.clear();
}
