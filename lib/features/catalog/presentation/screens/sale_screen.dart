import 'package:ipr_mobile/features/catalog/domain/entities/product_query.dart';
import 'package:ipr_mobile/features/catalog/presentation/widgets/product_results.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:ipr_mobile/shared/widgets/ipr_card.dart';
import 'package:ipr_mobile/shared/widgets/whatsapp_button.dart';
import 'package:material_ui/material_ui.dart';

/// Liquidaciones (`/catalog/sale`, RF-018): productos en oferta con precio
/// regular tachado y precio especial, orden y carga progresiva. Pública.
///
/// El precio mostrado es informativo: el vigente lo decide el servidor al
/// validar el carrito (AC-018-5).
class SaleScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.catalogSaleTitle)),
      body: const ProductResults(
        scope: ListScope.sale(),
        mode: ResultsMode.sale,
        showHeaderWhenEmpty: false,
        header: _SaleIntroBanner(),
      ),
    );
  }
}

class _SaleIntroBanner extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        IprSpace.s4,
        IprSpace.s3,
        IprSpace.s4,
        IprSpace.s1,
      ),
      child: IprCard(
        color: scheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(IprSpace.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      Icons.local_offer_outlined,
                      size: 20,
                      color: scheme.error,
                    ),
                  ),
                  const SizedBox(width: IprSpace.s2),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        l10n.catalogSaleBannerTitle,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: scheme.onErrorContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: IprSpace.s1),
              Text(
                l10n.catalogSaleBannerBody,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onErrorContainer,
                ),
              ),
              const SizedBox(height: IprSpace.s3),
              WhatsAppButton(
                label: l10n.catalogSaleWhatsappLabel,
                message: l10n.catalogSaleWhatsappMsg,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
