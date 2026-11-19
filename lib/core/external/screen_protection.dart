import 'package:flutter/services.dart';

/// Oculta el contenido en capturas y en el selector de aplicaciones en las
/// pantallas sensibles (SC-035): `FLAG_SECURE` en Android y vista de
/// privacidad al pasar a segundo plano en iOS.
abstract interface class ScreenProtection {
  Future<void> enable();
  Future<void> disable();
}

/// Implementación por `MethodChannel`; el código nativo está en
/// `MainActivity.kt` y `AppDelegate.swift`.
final class MethodChannelScreenProtection implements ScreenProtection {
  const new();

  static const _channel = MethodChannel('co.ipr.app/screen_protection');

  @override
  Future<void> enable() => _invoke('enable');

  @override
  Future<void> disable() => _invoke('disable');

  Future<void> _invoke(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } on MissingPluginException {
      // Plataformas sin implementación nativa (pruebas, escritorio).
    } on PlatformException {
      // No se bloquea la UI por un fallo de protección de pantalla.
    }
  }
}
