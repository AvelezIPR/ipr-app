import 'package:ipr_mobile/core/storage/preferences_store.dart';

/// Preferencias en memoria para pruebas.
final class InMemoryPreferencesStore implements PreferencesStore {
  final Map<String, Object> data = {};

  @override
  bool? getBool(String key) => data[key] as bool?;

  @override
  Future<void> setBool(String key, {required bool value}) async =>
      data[key] = value;

  @override
  String? getString(String key) => data[key] as String?;

  @override
  Future<void> setString(String key, String value) async => data[key] = value;

  @override
  Future<void> remove(String key) async => data.remove(key);
}
