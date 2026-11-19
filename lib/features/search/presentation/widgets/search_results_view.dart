import 'package:ipr_mobile/features/search/presentation/controllers/search_results_controller.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:ipr_mobile/shared/domain/product_summary.dart';
import 'package:ipr_mobile/shared/widgets/product_card.dart';
import 'package:material_ui/material_ui.dart';

/// Resultados con paginación infinita (AC-020-2, AC-011-2/3).
///
/// Dos columnas; una sola con texto de sistema grande (como la tarjeta, que
/// pasa a variante de lista). Al llegar al final se pide la página siguiente;
/// si falla, las anteriores se conservan y aparece "Reintentar".
class SearchResultsView extends StatelessWidget {
  const new({
    required this.listing,
    required this.onProductTap,
    required this.onLoadMore,
    super.key,
  });

  final SearchListing listing;
  final ValueChanged<ProductSummary> onProductTap;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final columns = scale >= ProductCard.listVariantScale ? 1 : 2;
    final items = listing.items;
    final rows = (items.length / columns).ceil();
    final hasFooter = listing.hasMore || listing.loadMoreFailure != null;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        IprSpace.s4,
        0,
        IprSpace.s4,
        IprSpace.s5,
      ),
      // Encabezado + filas + pie (carga de la página siguiente).
      itemCount: 1 + rows + (hasFooter ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: IprSpace.s2),
            child: Semantics(
              header: true,
              child: Text(
                l10n.searchResultsCount(listing.total),
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          );
        }
        if (index <= rows) {
          final start = (index - 1) * columns;
          return Padding(
            padding: const EdgeInsets.only(bottom: IprSpace.s3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var c = 0; c < columns; c++) ...[
                  if (c > 0) const SizedBox(width: IprSpace.s3),
                  Expanded(
                    child: start + c < items.length
                        ? ProductCard(
                            product: items[start + c],
                            onTap: () => onProductTap(items[start + c]),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          );
        }
        return _Footer(listing: listing, onLoadMore: onLoadMore);
      },
    );
  }
}

/// Pie de la lista: dispara la carga de la siguiente página cuando se
/// construye (es decir, cuando el usuario llega cerca del final).
class _Footer extends StatefulWidget {
  const new({required this.listing, required this.onLoadMore});

  final SearchListing listing;
  final VoidCallback onLoadMore;

  @override
  State<_Footer> createState() => _FooterState();
}

class _FooterState extends State<_Footer> {
  @override
  void initState() {
    super.initState();
    if (widget.listing.loadMoreFailure == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onLoadMore();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final failed = widget.listing.loadMoreFailure != null;
    if (failed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: IprSpace.s3),
        child: Column(
          children: [
            Semantics(
              liveRegion: true,
              child: Text(
                l10n.searchLoadMoreFailed,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: IprSpace.s2),
            FilledButton(
              onPressed: widget.onLoadMore,
              child: Text(l10n.actionRetry),
            ),
          ],
        ),
      );
    }
    final reduce = MediaQuery.of(context).disableAnimations;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: IprSpace.s4),
      child: Center(
        child: Semantics(
          liveRegion: true,
          label: l10n.searchLoadingMore,
          child: reduce
              ? const Icon(Icons.hourglass_empty)
              : const CircularProgressIndicator(),
        ),
      ),
    );
  }
}
