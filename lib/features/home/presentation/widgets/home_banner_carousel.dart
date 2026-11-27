import 'package:ipr_mobile/core/config/home_content.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/effect_tokens.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:ipr_mobile/shared/domain/image_ref.dart';
import 'package:ipr_mobile/shared/widgets/product_image.dart';
import 'package:material_ui/material_ui.dart';

/// Carrusel de campañas de la portada (W2-01), como el de la web pero sin
/// sus problemas de accesibilidad:
///
/// * **Sin avance automático** (WCAG 2.2.2): la persona decide cuándo cambiar.
/// * Se cambia deslizando **o** con los botones "anterior" y "siguiente"
///   (WCAG 2.5.1: hay una alternativa al gesto), de 48 dp.
/// * La posición ("Campaña 2 de 5") se anuncia al cambiar.
/// * Cada campaña es un solo botón con su texto alternativo.
class HomeBannerCarousel extends StatefulWidget {
  const new({required this.banners, required this.onOpen, super.key});

  final List<HomeBanner> banners;
  final void Function(HomeBanner banner) onOpen;

  /// Proporción de las imágenes de móvil de la web (1600 × 1191).
  static const double aspectRatio = 4 / 3;

  @override
  State<HomeBannerCarousel> createState() => _HomeBannerCarouselState();
}

class _HomeBannerCarouselState extends State<HomeBannerCarousel> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    final count = widget.banners.length;
    final target = (index % count + count) % count;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToPage(target);
    } else {
      _controller.animateToPage(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final banners = widget.banners;
    final many = banners.length > 1;
    final current = _index.clamp(0, banners.length - 1);

    return Semantics(
      container: true,
      // Cada campaña y el indicador de posición siguen siendo nodos propios:
      // el grupo solo les pone nombre.
      explicitChildNodes: true,
      label: l10n.homeBannersLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(IprRadius.xxl),
              boxShadow: IprShadows.card,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(IprRadius.xxl),
              child: AspectRatio(
                aspectRatio: HomeBannerCarousel.aspectRatio,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PageView.builder(
                      controller: _controller,
                      itemCount: banners.length,
                      onPageChanged: (i) => setState(() => _index = i),
                      itemBuilder: (context, i) => _BannerSlide(
                        banner: banners[i],
                        onTap: () => widget.onOpen(banners[i]),
                      ),
                    ),
                    if (many) ...[
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: _ArrowButton(
                          icon: Icons.chevron_left,
                          tooltip: l10n.homeBannerPrevious,
                          onPressed: () => _goTo(current - 1),
                        ),
                      ),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: _ArrowButton(
                          icon: Icons.chevron_right,
                          tooltip: l10n.homeBannerNext,
                          onPressed: () => _goTo(current + 1),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (many) ...[
            const SizedBox(height: IprSpace.s2),
            Semantics(
              liveRegion: true,
              label: l10n.homeBannerPosition(current + 1, banners.length),
              excludeSemantics: true,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < banners.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: AnimatedContainer(
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 200),
                        width: i == current ? 20 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == current
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(IprRadius.full),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BannerSlide extends StatelessWidget {
  const new({required this.banner, required this.onTap});

  final HomeBanner banner;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: banner.alt,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: ProductImage(
          image: ImageRef(url: banner.imageUrl, alt: banner.alt),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

/// Botón circular sobre la imagen: fondo opaco y borde para que se vea sobre
/// cualquier campaña (contraste ≥ 3:1 del componente).
class _ArrowButton extends StatelessWidget {
  const new({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(IprSpace.s2),
      child: IconButton.filled(
        tooltip: tooltip,
        constraints: const BoxConstraints(
          minWidth: IprSpace.minTapTarget,
          minHeight: IprSpace.minTapTarget,
        ),
        style: IconButton.styleFrom(
          backgroundColor: scheme.surface,
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.primary),
        ),
        onPressed: onPressed,
        icon: Icon(icon),
      ),
    );
  }
}
