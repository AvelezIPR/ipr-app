import 'package:shared_preferences/shared_preferences.dart';

/// Preferencias NO sensibles (aviso visto, marca de primera ejecución).
/// Jamás tokens ni datos personales (ST-001).
abstract interface class PreferencesStore {
  bool? getBool(String key);
  Future<void> setBool(String key, {required bool value});
  String? getString(String key);
  Future<void> setString(String key, String value);
  Future<void> remove(String key);
}

abstract final class PreferenceKeys {
  /// Marca de que la app ya se ejecutó (para limpiar el Keychain tras
  /// reinstalar en iOS, SC-032).
  static const installMarker = 'install.marker';
}

final class SharedPreferencesStore implements PreferencesStore {
  new(this._prefs);

  final SharedPreferences _prefs;

  @override
  bool? getBool(String key) => _prefs.getBool(key);

  @override
  Future<void> setBool(String key, {required bool value}) =>
      _prefs.setBool(key, value);

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  @override
  Future<void> remove(String key) => _prefs.remove(key);
}
