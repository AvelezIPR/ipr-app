import 'package:ipr_mobile/core/storage/preferences_store.dart';
import 'package:ipr_mobile/core/storage/secure_key_value.dart';

/// En iOS el Keychain puede sobrevivir a una reinstalación: si la marca de
/// primera ejecución no existe en las preferencias, se limpia el almacén
/// seguro antes de usarlo (SC-032, `flutter_app_architecture.md` §8).
Future<bool> clearSecureStorageOnFirstLaunch({
  required PreferencesStore preferences,
  required SecureKeyValue secure,
}) async {
  if (preferences.getBool(PreferenceKeys.installMarker) ?? false) {
    return false;
  }
  await secure.deleteAll();
  await preferences.setBool(PreferenceKeys.installMarker, value: true);
  return true;
}
