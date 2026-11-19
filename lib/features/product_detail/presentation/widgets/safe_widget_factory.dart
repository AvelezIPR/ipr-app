import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:ipr_mobile/core/external/media_host_policy.dart';
import 'package:material_ui/material_ui.dart';

/// Fábrica de widgets del HTML de la descripción con **defensa en
/// profundidad** (SC-043, RF-027): aunque el saneador ya haya quitado lo
/// peligroso, la fábrica solo resuelve imágenes `https` de la lista blanca de
/// hosts. `asset:`, `file:` y `data:` nunca se cargan, y tampoco las imágenes
/// de fondo de CSS.
class SafeWidgetFactory extends WidgetFactory {
  new(this.mediaHosts);

  final MediaHostPolicy mediaHosts;

  @override
  ImageProvider? imageProviderFromNetwork(String url) =>
      mediaHosts.isAllowed(url) ? NetworkImage(url) : null;

  @override
  ImageProvider? imageProviderFromAsset(String url) => null;

  @override
  ImageProvider? imageProviderFromDataUri(String dataUri) => null;

  @override
  ImageProvider? imageProviderFromFileUri(String url) => null;
}
