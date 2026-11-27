import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:ipr_mobile/shared/widgets/whatsapp_button.dart';
import 'package:material_ui/material_ui.dart';

/// Aviso al llegar al máximo por producto (W1-06): «Máximo 3 unidades por
/// producto. Para más, habla con un asesor.» con el WhatsApp del asesor
/// prellenado con el producto, como el de la web. Lo usan la ficha y el
/// carrito.
///
/// El aviso es una región viva (se anuncia al aparecer) y el botón mide al
/// menos 48 dp.
class MaxQuantityNotice extends ConsumerWidget {
  const new({
    required this.max,
    required this.productName,
    required this.whatsAppMessage,
    super.key,
  });

  /// Máximo que se alcanzó.
  final int max;

  /// Nombre del producto (incluye la opción elegida si es variable), para la
  /// etiqueta del botón.
  final String productName;

  /// Mensaje prellenado de WhatsApp (nombre, opción y SKU).
  final String whatsAppMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: IprSpace.s1),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: IprSpace.s1,
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              l10n.sharedMaxQuantityNotice(max),
              style: theme.textTheme.bodySmall,
            ),
          ),
          Semantics(
            button: true,
            excludeSemantics: true,
            label: l10n.sharedMaxQuantityAdvisorSemantics(productName),
            onTap: () => _open(context, ref),
            child: TextButton.icon(
              onPressed: () => _open(context, ref),
              icon: const Icon(Icons.chat_outlined, size: 18),
              label: Text(l10n.sharedMaxQuantityAdvisor),
            ),
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context, WidgetRef ref) =>
      openWhatsApp(context, ref, message: whatsAppMessage);
}
