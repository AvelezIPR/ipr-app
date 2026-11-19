import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Almacén de secretos de sesión (Keychain en iOS, Keystore en Android).
///
/// Solo para: refresh token, id de instalación, intento de checkout en curso
/// y revocación pendiente (SC-030..SC-034). Nada de PII.
abstract interface class SecureKeyValue {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<void> deleteAll();
}

/// Claves usadas en el almacén seguro.
abstract final class SecureKeys {
  static const refreshToken = 'session.refresh_token';
  static const deviceId = 'session.device_id';
  static const pendingRevocation = 'session.pending_revocation';
  static const checkoutAttempt = 'checkout.attempt';
}

/// Implementación con `flutter_secure_storage`.
///
/// iOS: accesibilidad "después del primer desbloqueo, solo este dispositivo"
/// y sin sincronización con iCloud (SC-030). Android: Keystore.
final class FlutterSecureKeyValue implements SecureKeyValue {
  new([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<void> deleteAll() => _storage.deleteAll();
}
