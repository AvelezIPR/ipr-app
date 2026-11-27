import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ipr_mobile/core/config/home_content.dart';
import 'package:ipr_mobile/core/providers.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:ipr_mobile/shared/domain/image_ref.dart';
import 'package:ipr_mobile/shared/widgets/ipr_card.dart';
import 'package:ipr_mobile/shared/widgets/product_image.dart';
import 'package:material_ui/material_ui.dart';

/// Bloque destacado de la portada (ingeniería, formación…; W2-04): imagen
/// opcional, título, texto y un llamado a la acción. Toda la tarjeta es un
/// solo botón; los textos vienen del servidor (D-07), la app no los fija.
///
/// La imagen solo se pinta si su host está permitido (SC-043): un adorno que
/// no carga no debe dejar un marcador gris en la portada.
class HomeHighlightCard extends ConsumerWidget {
  const new({required this.highlight, required this.onTap, super.key});

  final HomeHighlight highlight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final imageUrl = highlight.imageUrl;
    final showImage =
        imageUrl != null &&
        ref.watch(mediaHostPolicyProvider).isAllowed(imageUrl);

    return Semantics(
      button: true,
      excludeSemantics: true,
      label: '${highlight.title}. ${highlight.body}. ${highlight.cta}',
      onTap: onTap,
      child: IprCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showImage)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: ProductImage(
                  image: ImageRef(url: imageUrl, alt: ''),
                  fit: BoxFit.cover,
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(IprSpace.s4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (highlight.eyebrow != null) ...[
                    Text(
                      highlight.eyebrow!.toUpperCase(),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(height: IprSpace.s1),
                  ],
                  Text(highlight.title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: IprSpace.s2),
                  Text(highlight.body, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: IprSpace.s3),
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: IprSpace.minTapTarget - IprSpace.s4,
                    ),
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            highlight.cta,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: scheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: IprSpace.s1),
                        Icon(
                          Icons.arrow_forward,
                          size: 18,
                          color: scheme.primary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
