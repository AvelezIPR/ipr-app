import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ipr_mobile/core/config/remote_config_controller.dart';
import 'package:ipr_mobile/core/providers.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/brand_landing.dart';
import 'package:ipr_mobile/shared/design_system/tokens/color_tokens.dart';
import 'package:ipr_mobile/shared/design_system/tokens/effect_tokens.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:ipr_mobile/shared/domain/image_ref.dart';
import 'package:ipr_mobile/shared/navigation/target_opener.dart';
import 'package:ipr_mobile/shared/widgets/gradient_panel.dart';
import 'package:ipr_mobile/shared/widgets/ipr_card.dart';
import 'package:ipr_mobile/shared/widgets/product_image.dart';
import 'package:material_ui/material_ui.dart';

/// Contenido editorial de la landing de una marca (W3-01): portada, texto,
/// destacados, preguntas frecuentes y llamado a la acción, en este orden y
/// con los componentes de la app (la misma plantilla para todas las marcas;
/// solo cambian los textos y el color de la portada).
///
/// Solo texto plano: el servidor no envía HTML, así que no hay nada que
/// sanear ni ejecutar. Un destino que hoy no se puede ofrecer (p. ej. la
/// calculadora apagada) oculta su bloque de acción.
class BrandLandingBlocks extends ConsumerWidget {
  const new({required this.landing, super.key});

  final BrandLanding landing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final btuEnabled = ref.watch(
      remoteConfigProvider.select((s) => s.config.btuCalculatorEnabled),
    );
    final blocks = [
      for (final block in landing.blocks)
        if (block.target == null ||
            isHomeTargetAvailable(block.target!, btuEnabled: btuEnabled))
          block,
    ];
    if (blocks.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        IprSpace.s4,
        IprSpace.s3,
        IprSpace.s4,
        IprSpace.s2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final block in blocks) ...[
            switch (block.type) {
              BrandBlockType.hero => _HeroBlock(block: block),
              BrandBlockType.text => _TextBlock(block: block),
              BrandBlockType.highlights => _HighlightsBlock(block: block),
              BrandBlockType.faq => _FaqBlock(block: block),
              BrandBlockType.cta => _CtaBlock(block: block),
            },
            const SizedBox(height: IprSpace.s4),
          ],
        ],
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const new(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: IprSpace.s3),
    child: Semantics(
      header: true,
      child: Text(text, style: Theme.of(context).textTheme.titleLarge),
    ),
  );
}

class _HeroBlock extends ConsumerWidget {
  const new({required this.block});

  final BrandBlock block;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = block.accentArgb;
    final gradient = accent == null
        ? IprGradients.hero
        : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(accent),
              Color.lerp(Color(accent), IprPalette.blue900, 0.6)!,
            ],
          );
    final imageUrl = block.imageUrl;
    final showImage =
        imageUrl != null &&
        ref.watch(mediaHostPolicyProvider).isAllowed(imageUrl);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showImage) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(IprRadius.xxl),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: ProductImage(
                image: ImageRef(url: imageUrl, alt: ''),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: IprSpace.s3),
        ],
        IprGradientPanel(
          gradient: gradient,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  block.title!,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: scheme.onPrimary,
                  ),
                ),
              ),
              if (block.subtitle != null) ...[
                const SizedBox(height: IprSpace.s2),
                Text(
                  block.subtitle!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onPrimary,
                  ),
                ),
              ],
              if (block.hasCta) ...[
                const SizedBox(height: IprSpace.s4),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.surface,
                    foregroundColor: scheme.primary,
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () =>
                      unawaited(openHomeTarget(context, ref, block.target!)),
                  iconAlignment: IconAlignment.end,
                  icon: const ExcludeSemantics(
                    child: Icon(Icons.arrow_forward),
                  ),
                  label: Text(block.ctaLabel!),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TextBlock extends StatelessWidget {
  const new({required this.block});

  final BrandBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paragraphs = block.body!
        .split(RegExp(r'\n{2,}'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (block.title != null) _Title(block.title!),
        for (final (i, paragraph) in paragraphs.indexed) ...[
          if (i > 0) const SizedBox(height: IprSpace.s2),
          Text(paragraph, style: theme.textTheme.bodyMedium),
        ],
      ],
    );
  }
}

class _HighlightsBlock extends StatelessWidget {
  const new({required this.block});

  final BrandBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (block.title != null) _Title(block.title!),
        for (final (i, item) in block.items.indexed) ...[
          if (i > 0) const SizedBox(height: IprSpace.s2),
          IprCard(
            child: Padding(
              padding: const EdgeInsets.all(IprSpace.s4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      Icons.check_circle_outline,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(width: IprSpace.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title, style: theme.textTheme.titleSmall),
                        const SizedBox(height: IprSpace.s1),
                        Text(item.body, style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Preguntas frecuentes como acordeón: cada pregunta es un botón de al menos
/// 48 dp que anuncia si está abierta.
class _FaqBlock extends StatelessWidget {
  const new({required this.block});

  final BrandBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (block.title != null) _Title(block.title!),
        for (final (i, item) in block.items.indexed) ...[
          if (i > 0) const SizedBox(height: IprSpace.s2),
          IprCard(
            child: Theme(
              // Sin las líneas divisorias propias del ExpansionTile.
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: IprSpace.s4,
                ),
                childrenPadding: const EdgeInsets.fromLTRB(
                  IprSpace.s4,
                  0,
                  IprSpace.s4,
                  IprSpace.s4,
                ),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                title: Text(item.title, style: theme.textTheme.titleSmall),
                children: [Text(item.body, style: theme.textTheme.bodyMedium)],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _CtaBlock extends ConsumerWidget {
  const new({required this.block});

  final BrandBlock block;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(IprRadius.xl),
      ),
      child: Padding(
        padding: const EdgeInsets.all(IprSpace.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(block.title!, style: theme.textTheme.titleLarge),
            ),
            if (block.body != null) ...[
              const SizedBox(height: IprSpace.s2),
              Text(block.body!, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: IprSpace.s3),
            FilledButton(
              onPressed: () =>
                  unawaited(openHomeTarget(context, ref, block.target!)),
              child: Text(block.ctaLabel!),
            ),
          ],
        ),
      ),
    );
  }
}
