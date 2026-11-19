/// Lista blanca de hosts de imágenes (SC-043). La app solo carga imágenes
/// `https` de los hosts declarados en `config/<flavor>.json` (`mediaHosts`):
/// un servidor comprometido no puede hacer que la app pida URL arbitrarias
/// (rastreo, SSRF desde el dispositivo, contenido ajeno).
final class MediaHostPolicy {
  const new({required this.allowedHosts});

  final Set<String> allowedHosts;

  /// Devuelve `true` solo para `https`, sin credenciales ni puerto distinto
  /// de 443 y con host en [allowedHosts] (sin distinguir mayúsculas).
  bool isAllowed(String? url) {
    if (url == null || url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    if (uri.scheme.toLowerCase() != 'https') return false;
    if (uri.userInfo.isNotEmpty) return false;
    if (uri.hasPort && uri.port != 443) return false;
    return allowedHosts
        .map((h) => h.toLowerCase())
        .contains(uri.host.toLowerCase());
  }
}
