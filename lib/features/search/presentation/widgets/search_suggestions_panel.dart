import 'package:ipr_mobile/features/search/domain/entities/search_suggestion.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
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
    super.key,
  });

  /// Texto normalizado que se está escribiendo.
  final String query;
  final List<SearchSuggestion> items;
  final ValueChanged<SearchSuggestion> onOpen;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.only(bottom: IprSpace.s5),
      children: [
        for (final s in items)
          Semantics(
            button: true,
            excludeSemantics: true,
            label: l10n.searchSuggestionSemantics(s.name, s.sku),
            onTap: () => onOpen(s),
            child: ListTile(
              minTileHeight: IprSpace.minTapTarget,
              leading: const Icon(Icons.search),
              title: Text(s.name, maxLines: 3, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                [
                  l10n.sharedProductSku(s.sku),
                  if (s.brandName != null) s.brandName!,
                ].join(' · '),
              ),
              onTap: () => onOpen(s),
            ),
          ),
        if (items.isNotEmpty) const Divider(height: 1),
        ListTile(
          minTileHeight: IprSpace.minTapTarget,
          leading: const Icon(Icons.manage_search),
          title: Text(
            l10n.searchSuggestionsSeeAll(query),
            style: theme.textTheme.titleSmall,
          ),
          onTap: onSeeAll,
        ),
      ],
    );
  }
}
