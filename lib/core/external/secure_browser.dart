import 'package:url_launcher/url_launcher.dart';

/// Valida la URL del checkout devuelta por el BFF (CR-016, SC-020).
///
/// Debe ser `https`, sin credenciales ni puerto distinto de 443, y su host
/// debe estar en la **intersección** de la lista local por flavor
/// (`checkoutAllowedHosts`) y la remota (`/config` → `allowedHosts`): un
/// servidor comprometido no puede añadir hosts.
final class CheckoutUrlPolicy {
  const new({required this.localHosts});

  final Set<String> localHosts;

  bool isAllowed(Uri url, {required Set<String> remoteHosts}) {
    if (url.scheme.toLowerCase() != 'https') return false;
    if (url.userInfo.isNotEmpty) return false;
    if (url.hasPort && url.port != 443) return false;
    final host = url.host.toLowerCase();
    if (host.isEmpty) return false;
    final local = localHosts.map((h) => h.toLowerCase()).toSet();
    final remote = remoteHosts.map((h) => h.toLowerCase()).toSet();
    return local.contains(host) && remote.contains(host);
  }
}

/// Navegador seguro del sistema para el pago. **Jamás un WebView propio**
/// (RNF-045d) y nunca se precarga el ticket (`mayLaunchUrl`, SC-023).
abstract interface class SecureBrowser {
  Future<bool> open(Uri url);
}

/// Implementación con `url_launcher`: Custom Tabs en Android y
/// SFSafariViewController en iOS; si no hay Custom Tabs, cae al navegador
/// predeterminado (CR-004).
///
/// Brecha conocida (SPK-01): CR-004 pide `ASWebAuthenticationSession`
/// efímera en iOS, que `url_launcher` no ofrece; se decide tras el spike.
final class UrlLauncherSecureBrowser implements SecureBrowser {
  const new();

  @override
  Future<bool> open(Uri url) async {
    try {
      if (await launchUrl(url, mode: LaunchMode.inAppBrowserView)) return true;
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    } on Object {
      return false;
    }
  }
}
