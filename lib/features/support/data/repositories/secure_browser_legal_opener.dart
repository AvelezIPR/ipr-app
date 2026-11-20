import 'package:ipr_mobile/core/external/external_url_policy.dart';
import 'package:ipr_mobile/core/external/secure_browser.dart';
import 'package:ipr_mobile/features/support/domain/entities/legal_document.dart';
import 'package:ipr_mobile/features/support/domain/repositories/legal_opener.dart';

/// Abre los documentos con el navegador seguro del sistema (Custom Tabs /
/// SFSafariViewController), jamás con un WebView (AC-099-7, RNF-045d).
///
/// Solo abre direcciones `https` que pasen la política de URLs de `core`
/// (SC-036): una URL ausente, malformada o de un host no autorizado no se
/// abre y se informa, no se ignora en silencio.
final class SecureBrowserLegalOpener implements LegalOpener {
  const new({required this.browser, required this.policy});

  final SecureBrowser browser;
  final ExternalUrlPolicy policy;

  @override
  Future<LegalOpenResult> open(LegalDocument document) async {
    final raw = document.url;
    if (raw == null) return LegalOpenResult.unavailable;
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return LegalOpenResult.unavailable;
    }
    if (uri.scheme.toLowerCase() != 'https' || !policy.isAllowed(uri)) {
      return LegalOpenResult.blocked;
    }
    final opened = await browser.open(uri);
    return opened ? LegalOpenResult.opened : LegalOpenResult.failed;
  }
}
