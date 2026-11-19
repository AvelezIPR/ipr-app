import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:ipr_mobile/core/external/external_launcher.dart';
import 'package:ipr_mobile/core/providers.dart';
import 'package:ipr_mobile/features/product_detail/domain/rules/html_sanitizer.dart';
import 'package:ipr_mobile/features/product_detail/presentation/widgets/safe_widget_factory.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Abre un enlace de la descripción con el [launcher] de `core/` (lista blanca
/// de destinos, jamás un webview). Devuelve `false` si no se pudo abrir.
Future<bool> openDescriptionLink(ExternalLauncher launcher, String url) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || uri.scheme.toLowerCase() != 'https') return false;
  final opened = await launcher.open(uri);
  return opened;
}

/// Descripción corta (texto plano) y descripción larga (HTML saneado) en
/// secciones distintas (RF-027, AC-027-5/-6): una sección vacía se omite sin
/// dejar encabezados.
class ProductDescription extends ConsumerWidget {
  const new({
    required this.shortDescription,
    required this.descriptionHtml,
    super.key,
  });

  final String shortDescription;
  final String descriptionHtml;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final policy = ref.watch(mediaHostPolicyProvider);
    final short = shortDescription.trim();
    final sanitized = HtmlSanitizer(isImageUrlAllowed: policy.isAllowed)
        .sanitize(descriptionHtml);
    final hasLong = HtmlSanitizer.hasVisibleContent(sanitized);
    if (short.isEmpty && !hasLong) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (short.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: IprSpace.s4),
            child: Text(short, style: theme.textTheme.bodyLarge),
          ),
        if (hasLong) ...[
          Semantics(
            header: true,
            child: Text(
              l10n.productDetailDescriptionTitle,
              style: theme.textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: IprSpace.s2),
          HtmlWidget(
            sanitized,
            textStyle: theme.textTheme.bodyMedium,
            factoryBuilder: () => SafeWidgetFactory(policy),
            customStylesBuilder: (element) => element.localName == 'a'
                ? {'color': _hex(theme.colorScheme.secondary)}
                : null,
            onTapUrl: (url) async {
              final opened = await openDescriptionLink(
                ref.read(externalLauncherProvider),
                url,
              );
              if (!opened && context.mounted) {
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  SnackBar(content: Text(l10n.productDetailLinkOpenFailed)),
                );
              }
              return true;
            },
          ),
        ],
      ],
    );
  }
}

String _hex(Color color) {
  String two(double channel) =>
      (channel * 255).round().toRadixString(16).padLeft(2, '0');
  return '#${two(color.r)}${two(color.g)}${two(color.b)}';
}
