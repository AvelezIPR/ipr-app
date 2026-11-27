import 'package:ipr_mobile/features/search/domain/entities/search_suggestion.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:ipr_mobile/shared/domain/price_status.dart';
import 'package:ipr_mobile/shared/formatting/cop_format.dart';
import 'package:ipr_mobile/shared/widgets/price_widgets.dart';
import 'package:ipr_mobile/shared/widgets/product_image.dart';
import 'package:material_ui/material_ui.dart';

/// Sugerencias bajo el campo (PT-06). Tocar una sugerencia abre la ficha del
/// producto; "Ver todos los resultados" lanza la búsqueda completa.
///
/// Siempre muestra el renglón "Ver todos…": si el servicio de sugerencias
/// falla, la búsqueda por texto sigue disponible (AC-021-4).
class SearchSuggestionsPanel extends StatelessWidget {
  const new({
    required this.query,
    required this.items,
    required this.onOpen,
    required this.onSeeAll,
    this.total,
    super.key,
  });

  /// Texto normalizado que se está escribiendo.
  final String query;
  final List<SearchSuggestion> items;
  final ValueChanged<SearchSuggestion> onOpen;
  final VoidCallback onSeeAll;
  final int? total;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final totalCount = total;
    return ListView(
      padding: const EdgeInsets.only(bottom: IprSpace.s5),
      children: [
        for (final s in items)
          Semantics(
            button: true,
            excludeSemantics: true,
            label: _suggestionSemantics(l10n, s),
            onTap: () => onOpen(s),
            child: ListTile(
              minTileHeight: IprSpace.minTapTarget,
              leading: s.image != null
                  ? SizedBox.square(
                      dimension: 40,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(IprRadius.sm),
                        child: ProductImage(image: s.image),
                      ),
                    )
                  : const Icon(Icons.search),
              title: Text(s.name, maxLines: 3, overflow: TextOverflow.ellipsis),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    [
                      l10n.sharedProductSku(s.sku),
                      if (s.brandName != null) s.brandName!,
                    ].join(' · '),
                  ),
                  if (s.price != null) ...[
                    const SizedBox(height: IprSpace.s1),
                    PriceText(
                      price: s.price!,
                      style: theme.textTheme.labelLarge,
                    ),
                  ],
                ],
              ),
              onTap: () => onOpen(s),
            ),
          ),
        if (items.isNotEmpty) const Divider(height: 1),
        ListTile(
          minTileHeight: IprSpace.minTapTarget,
          leading: const Icon(Icons.manage_search),
          title: Text(
            totalCount != null && totalCount > 0
                ? l10n.searchSuggestionsSeeAllWithTotal(query, totalCount)
                : l10n.searchSuggestionsSeeAll(query),
            style: theme.textTheme.titleSmall,
          ),
          onTap: onSeeAll,
        ),
      ],
    );
  }

  String _suggestionSemantics(AppLocalizations l10n, SearchSuggestion s) {
    final base = l10n.searchSuggestionSemantics(s.name, s.sku);
    final price = s.price;
    if (price == null) return base;
    final priceLabel = switch (price) {
      Priced(:final amount) => l10n.priceSemantics(copSemanticsAmount(amount)),
      OnRequest() => l10n.priceOnRequestSemantics,
    };
    return '$base $priceLabel.';
  }
}
