/// Lista blanca cerrada de destinos que la app puede abrir fuera de sí misma
/// (SC-036). Bloquea `intent:`, `javascript:`, `file:`, `content:` y todo lo
/// que no esté listado.
final class ExternalUrlPolicy {
  const new({this.extraHttpsHosts = const {}});

  /// Hosts https adicionales (p. ej. el dominio del flavor).
  final Set<String> extraHttpsHosts;

  static const _httpsHosts = {
    'wa.me',
    'api.whatsapp.com',
    'maps.google.com',
    'maps.apple.com',
  };

  static final _phone = RegExp(r'^\+?[0-9]{6,15}$');
  static final _geo = RegExp(r'^-?\d{1,3}(\.\d+)?,-?\d{1,3}(\.\d+)?(\?.*)?$');

  bool isAllowed(Uri uri) {
    if (uri.userInfo.isNotEmpty) return false;
    final scheme = uri.scheme.toLowerCase();
    switch (scheme) {
      case 'https':
        final host = uri.host.toLowerCase();
        if (uri.hasPort && uri.port != 443) return false;
        if (host == 'www.google.com') return uri.path.startsWith('/maps');
        return _httpsHosts.contains(host) || extraHttpsHosts.contains(host);
      case 'tel':
        return _phone.hasMatch(uri.path);
      case 'whatsapp':
        return uri.host == 'send';
      case 'geo':
        return _geo.hasMatch(uri.toString().substring('geo:'.length));
      default:
        return false;
    }
  }
}
