import 'package:ipr_mobile/features/catalog/domain/entities/product_query.dart';
import 'package:ipr_mobile/features/catalog/presentation/widgets/product_results.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
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
      ),
    );
  }
}
