import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ipr_mobile/core/providers.dart';
import 'package:ipr_mobile/shared/domain/image_ref.dart';
import 'package:material_ui/material_ui.dart';

/// Imagen de producto con caché en disco acotada y **lista blanca de hosts**
/// (SC-043): una URL fuera de `mediaHosts` (o no https) NO se pide; se muestra
/// el marcador de posición. Sin imagen, también marcador.
///
/// La imagen es decorativa para el lector de pantalla salvo que traiga `alt`;
/// el nombre del producto ya lo anuncia la tarjeta o la ficha.
class ProductImage extends ConsumerWidget {
  const new({
    required this.image,
    super.key,
    this.fit = BoxFit.contain,
    this.semanticLabel,
  });

  final ImageRef? image;
  final BoxFit fit;

  /// Etiqueta cuando se quiere anunciar la imagen (galería de la ficha).
  final String? semanticLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ref0 = image;
    final policy = ref.watch(mediaHostPolicyProvider);
    final theme = Theme.of(context);
    Widget placeholder() => ColoredBox(
      color: theme.colorScheme.surfaceContainer,
      child: Center(
        child: ExcludeSemantics(
          child: Icon(
            Icons.image_not_supported_outlined,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );

    if (ref0 == null || !policy.isAllowed(ref0.url)) return placeholder();

    final dpr = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // Decodifica al tamaño real de pantalla (RNF-009/010): no la foto
        // original completa.
        final width = constraints.hasBoundedWidth
            ? (constraints.maxWidth * dpr).round()
            : null;
        return Semantics(
          image: true,
          label: semanticLabel,
          excludeSemantics: semanticLabel == null,
          child: CachedNetworkImage(
            imageUrl: ref0.url,
            fit: fit,
            memCacheWidth: width,
            placeholder: (_, _) =>
                ColoredBox(color: theme.colorScheme.surfaceContainer),
            errorWidget: (_, _, _) => placeholder(),
            fadeInDuration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 150),
          ),
        );
      },
    );
  }
}
