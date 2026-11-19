import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ipr_mobile/core/config/remote_config_controller.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:ipr_mobile/shared/domain/price_status.dart';
import 'package:material_ui/material_ui.dart';

/// Avisos de la ficha (RF-032): envío y garantía en fichas con precio; el de
/// "precio bajo consulta" en fichas sin precio. **Todos los textos llegan de
/// `/config`** (`notices`): no se inventa texto legal (D-12). Si vienen nulos
/// o vacíos no se muestra nada.
class ProductNotices extends ConsumerWidget {
  const new({required this.price, super.key});

  final PriceStatus price;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(remoteConfigProvider.select((s) => s.config));
    final notices = <String>[
      if (price.hasPrice) ...[?config.shippingNotice, ?config.warrantyNotice],
      if (!price.hasPrice) ?config.priceOnRequestNotice,
    ].map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
    if (notices.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final notice in notices)
          Padding(
            padding: const EdgeInsets.only(bottom: IprSpace.s2),
            child: Semantics(
              container: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      Icons.info_outline,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: IprSpace.s2),
                  Expanded(
                    child: Text(notice, style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
