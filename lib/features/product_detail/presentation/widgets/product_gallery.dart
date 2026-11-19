import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ipr_mobile/core/providers.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:ipr_mobile/shared/domain/image_ref.dart';
import 'package:ipr_mobile/shared/widgets/product_image.dart';
import 'package:material_ui/material_ui.dart';

/// Galería de la ficha (RF-026, AC-026-2/-3, RNF-072): imágenes **solo** con
/// [ProductImage] (lista blanca de hosts), deslizar **y** botones
/// anterior/siguiente de 48 dp, indicador textual "Imagen 2 de 4", sin
/// autoavance, toque para ampliar a pantalla completa. Sin imágenes
/// permitidas: marcador de posición, sin error.
class ProductGallery extends ConsumerStatefulWidget {
  const new({required this.images, required this.productName, super.key});

  final List<ImageRef> images;
  final String productName;

  @override
  ConsumerState<ProductGallery> createState() => _ProductGalleryState();
}

class _ProductGalleryState extends ConsumerState<ProductGallery> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<ImageRef> _allowed() {
    final policy = ref.read(mediaHostPolicyProvider);
    return [
      for (final image in widget.images)
        if (policy.isAllowed(image.url)) image,
    ];
  }

  void _go(int page, int total) {
    final target = page.clamp(0, total - 1);
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToPage(target);
    } else {
      _controller.animateToPage(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  String _alt(AppLocalizations l10n, ImageRef image) => image.alt.isNotEmpty
      ? image.alt
      : l10n.productDetailImageFallbackAlt(widget.productName);

  void _openFullScreen(List<ImageRef> images) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullScreenGallery(
          images: images,
          initialIndex: _index,
          productName: widget.productName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final images = _allowed();
    final total = images.length;

    if (total == 0) {
      return const AspectRatio(
        aspectRatio: 1,
        child: ProductImage(image: null),
      );
    }

    final current = _index.clamp(0, total - 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          label: l10n.productDetailGallerySemantics(current + 1, total),
          child: AspectRatio(
            aspectRatio: 1,
            child: Stack(
              children: [
                Positioned.fill(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: total,
                    onPageChanged: (page) => setState(() => _index = page),
                    itemBuilder: (context, page) {
                      final image = images[page];
                      return Semantics(
                        button: true,
                        excludeSemantics: true,
                        label:
                            '${_alt(l10n, image)}. '
                            '${l10n.productDetailGalleryZoom}',
                        onTap: () => _openFullScreen(images),
                        child: InkWell(
                          onTap: () => _openFullScreen(images),
                          child: ProductImage(image: image),
                        ),
                      );
                    },
                  ),
                ),
                if (total > 1) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _NavButton(
                      icon: Icons.chevron_left,
                      tooltip: l10n.productDetailGalleryPrevious,
                      onPressed: current > 0
                          ? () => _go(current - 1, total)
                          : null,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _NavButton(
                      icon: Icons.chevron_right,
                      tooltip: l10n.productDetailGalleryNext,
                      onPressed: current < total - 1
                          ? () => _go(current + 1, total)
                          : null,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (total > 1)
          Padding(
            padding: const EdgeInsets.only(top: IprSpace.s2),
            child: Text(
              l10n.productDetailGalleryPosition(current + 1, total),
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  const new({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton.filledTonal(
      tooltip: tooltip,
      constraints: const BoxConstraints(
        minWidth: IprSpace.minTapTarget,
        minHeight: IprSpace.minTapTarget,
      ),
      style: IconButton.styleFrom(
        backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.85),
      ),
      onPressed: onPressed,
      icon: Icon(icon),
    );
  }
}

/// Galería a pantalla completa (PT-09): modal con cierre explícito.
class _FullScreenGallery extends ConsumerStatefulWidget {
  const new({
    required this.images,
    required this.initialIndex,
    required this.productName,
  });

  final List<ImageRef> images;
  final int initialIndex;
  final String productName;

  @override
  ConsumerState<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends ConsumerState<_FullScreenGallery> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final total = widget.images.length;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l10n.productDetailGalleryClose,
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          total > 1
              ? l10n.productDetailGalleryPosition(_index + 1, total)
              : l10n.productDetailGalleryFullTitle,
        ),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: total,
        onPageChanged: (page) => setState(() => _index = page),
        itemBuilder: (context, page) => InteractiveViewer(
          maxScale: 4,
          child: Center(
            child: ProductImage(
              image: widget.images[page],
              semanticLabel: widget.images[page].alt.isNotEmpty
                  ? widget.images[page].alt
                  : l10n.productDetailImageFallbackAlt(widget.productName),
            ),
          ),
        ),
      ),
    );
  }
}
