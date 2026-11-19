import 'package:ipr_mobile/core/network/uuid_v4.dart';
import 'package:ipr_mobile/core/storage/secure_key_value.dart';

/// Persistencia de los secretos de sesión (solo el almacén seguro).
///
/// El *access token* y los datos personales **nunca** pasan por aquí: viven
/// en memoria (CR-019, CR-065).
final class TokenStore {
  new(this._secure, {String Function()? newDeviceId})
    : _newDeviceId = newDeviceId ?? uuidV4;

  final SecureKeyValue _secure;
  final String Function() _newDeviceId;

  Future<String?> readRefreshToken() => _secure.read(SecureKeys.refreshToken);

  Future<void> writeRefreshToken(String token) =>
      _secure.write(SecureKeys.refreshToken, token);

  Future<void> clearRefreshToken() => _secure.delete(SecureKeys.refreshToken);

  /// Refresh token pendiente de revocar en el servidor cuando hubo cierre de
  /// sesión sin red (CR-039).
  Future<String?> readPendingRevocation() =>
      _secure.read(SecureKeys.pendingRevocation);

  Future<void> writePendingRevocation(String refreshToken) =>
      _secure.write(SecureKeys.pendingRevocation, refreshToken);

  Future<void> clearPendingRevocation() =>
      _secure.delete(SecureKeys.pendingRevocation);

  /// Identificador de instalación: UUID v4 aleatorio, sin datos de hardware
  /// (SC-031). Se crea una vez y se conserva al cerrar sesión.
  Future<String> deviceId() async {
    final existing = await _secure.read(SecureKeys.deviceId);
    if (existing != null && isUuidV4(existing)) return existing;
    return await regenerateDeviceId();
  }

  /// Genera un identificador nuevo (al eliminar la cuenta, CR-040).
  Future<String> regenerateDeviceId() async {
    final id = _newDeviceId();
    await _secure.write(SecureKeys.deviceId, id);
    return id;
  }
}
