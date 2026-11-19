import 'package:ipr_mobile/core/external/external_url_policy.dart';
import 'package:url_launcher/url_launcher.dart';

/// Abre `https` permitidos, `tel`, WhatsApp y mapas. Es el único punto del
/// código que llama a `url_launcher` para contacto (D6).
abstract interface class ExternalLauncher {
  /// Devuelve `false` si la política lo bloquea o el sistema no puede abrirlo.
  Future<bool> open(Uri uri);
}

final class UrlLauncherExternalLauncher implements ExternalLauncher {
  const new(this.policy);

  final ExternalUrlPolicy policy;

  @override
  Future<bool> open(Uri uri) async {
    if (!policy.isAllowed(uri)) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      return false;
    }
  }
}

/// Construye el enlace de WhatsApp (`wa.me`) con un texto opcional.
Uri whatsAppUri(String number, {String? text}) {
  final digits = number.replaceAll(RegExp('[^0-9]'), '');
  return Uri.https(
    'wa.me',
    '/$digits',
    (text == null || text.isEmpty) ? null : {'text': text},
  );
}
