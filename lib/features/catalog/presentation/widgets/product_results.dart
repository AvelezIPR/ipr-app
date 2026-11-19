import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/product_query.dart';
import 'package:ipr_mobile/features/catalog/presentation/controllers/product_list_controller.dart';
import 'package:ipr_mobile/features/catalog/presentation/widgets/filter_sheet.dart';
import 'package:ipr_mobile/features/catalog/presentation/widgets/sort_labels.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:ipr_mobile/shared/domain/product_summary.dart';
import 'package:ipr_mobile/shared/navigation/routes.dart';
import 'package:ipr_mobile/shared/widgets/failure_messages.dart';
import 'package:ipr_mobile/shared/widgets/product_card.dart';
import 'package:ipr_mobile/shared/widgets/state_widgets.dart';
import 'package:ipr_mobile/shared/widgets/ui_state.dart';
import 'package:material_ui/material_ui.dart';

/// Qué controles y textos de vacío lleva un listado.
enum ResultsMode {
  /// Categoría (o listado general): filtros + orden.
  category,

  /// Landing de marca: filtros + orden + búsqueda interna.
  brand,

  /// Liquidaciones: solo orden y paginación (el contrato no ofrece filtros).
  sale,
}

/// Listado paginado de productos (PT-03): barra de filtros y orden, chips de
/// filtros activos, contador de resultados, rejilla de [ProductCard]
/// (una columna a texto grande), carga progresiva y los estados de carga,
/// vacío, error y datos obsoletos.
///
/// Un **error** nunca se presenta como "sin resultados" (AC-009-7); un fallo en
/// la página N conserva las anteriores (AC-009-5); un fallo al aplicar filtros
/// conserva el listado y los filtros previos (AC-013-5).
class ProductResults extends ConsumerStatefulWidget {
  const new({required this.scope, required this.mode, super.key});

  final ListScope scope;
  final ResultsMode mode;

  @override
  ConsumerState<ProductResults> createState() => _ProductResultsState();
}

class _ProductResultsState extends ConsumerState<ProductResults> {
  final ScrollController _scroll = ScrollController();

  /// Distancia al final (en dp) a partir de la cual se pide la página
  /// siguiente.
  static const _loadMoreExtent = 600.0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  ProductListController get _controller =>
      ref.read(productListProvider(widget.scope).notifier);

  void _maybeLoadMore() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.extentAfter < _loadMoreExtent) {
      unawaited(_controller.loadMore());
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = productListProvider(widget.scope);
    final state = ref.watch(provider);
    ref.listen(provider, (previous, next) {
      // Al cambiar los filtros el listado vuelve al inicio.
      if (previous is UiData<ProductListData> &&
          next is UiData<ProductListData> &&
          previous.value.filters != next.value.filters &&
          _scroll.hasClients) {
        _scroll.jumpTo(0);
      }
    });

    return AsyncView<ProductListData>(
      state: state,
      onRetry: _controller.reload,
      builder: (context, data) {
        // Lista corta (no llena la pantalla): se pide la siguiente página.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _maybeLoadMore();
        });
        return RefreshIndicator(
          onRefresh: _controller.refresh,
          child: CustomScrollView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _Toolbar(
                  data: data,
                  scope: widget.scope,
                  mode: widget.mode,
                  controller: _controller,
                ),
              ),
              if (data.items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyResults(
                    data: data,
                    mode: widget.mode,
                    controller: _controller,
                  ),
                )
              else
                _ProductSliver(
                  items: data.items,
                  showOfferBadge: widget.mode == ResultsMode.sale,
                ),
              SliverToBoxAdapter(
                child: _Footer(data: data, controller: _controller),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Filtros, orden, chips de filtros activos, contador y avisos.
class _Toolbar extends StatelessWidget {
  const new({
    required this.data,
    required this.scope,
    required this.mode,
    required this.controller,
  });

  final ProductListData data;
  final ListScope scope;
  final ResultsMode mode;
  final ProductListController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final filters = data.filters;
    final searching = filters.isSearching;
    final showFilters = mode != ResultsMode.sale && !searching;
    final showSort = !searching;
    final count = data.resultCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        IprSpace.s4,
        IprSpace.s2,
        IprSpace.s4,
        IprSpace.s2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showFilters || showSort)
            Wrap(
              spacing: IprSpace.s2,
              runSpacing: IprSpace.s2,
              children: [
                if (showFilters)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.tune),
                    label: Text(
                      filters.selectionCount > 0
                          ? l10n.catalogFiltersWithCount(filters.selectionCount)
                          : l10n.catalogFilters,
                    ),
                    onPressed: () => _openFilters(context),
                  ),
                if (showSort)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.swap_vert),
                    label: Text(
                      l10n.catalogSortButton(sortLabelOf(l10n, filters.sort)),
                    ),
                    onPressed: () => _openSort(context),
                  ),
              ],
            ),
          if (filters.hasActive) ...[
            const SizedBox(height: IprSpace.s2),
            Semantics(
              container: true,
              label: l10n.catalogActiveFilters,
              child: Wrap(
                spacing: IprSpace.s2,
                runSpacing: IprSpace.s1,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final choice in filters.choices)
                    _RemovableChip(
                      label: choice.boolean
                          ? choice.keyLabel
                          : l10n.catalogChipLabel(
                              choice.keyLabel,
                              choice.valueLabel,
                            ),
                      onRemove: () => controller.removeChoice(choice),
                    ),
                  if (filters.category != null)
                    _RemovableChip(
                      label: l10n.catalogChipCategory(filters.category!.name),
                      onRemove: controller.removeCategory,
                    ),
                  if (filters.searchTerm != null)
                    _RemovableChip(
                      label: l10n.catalogChipSearch(filters.searchTerm!),
                      onRemove: () => controller.search(null),
                    ),
                  TextButton(
                    onPressed: controller.clearFilters,
                    child: Text(l10n.catalogClearFilters),
                  ),
                ],
              ),
            ),
          ],
          if (count != null)
            Padding(
              padding: const EdgeInsets.only(top: IprSpace.s2),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  l10n.catalogResultCount(count),
                  style: theme.textTheme.labelLarge,
                ),
              ),
            ),
          if (data.refreshing)
            Padding(
              padding: const EdgeInsets.only(top: IprSpace.s2),
              child: Semantics(
                liveRegion: true,
                label: l10n.catalogRefreshing,
                child: const LinearProgressIndicator(),
              ),
            ),
          if (data.applyFailure != null)
            _ApplyFailureBanner(
              failure: data.applyFailure!,
              onRetry: controller.retryApply,
            ),
        ],
      ),
    );
  }

  Future<void> _openFilters(BuildContext context) async {
    final result = await showCatalogFilterSheet(
      context,
      scope: scope,
      current: data.filters,
    );
    if (result != null && result != data.filters) {
      await controller.applyFilters(result);
    }
  }

  Future<void> _openSort(BuildContext context) async {
    final result = await showCatalogSortSheet(
      context,
      current: data.filters.sort,
    );
    if (result != null && result != data.filters.sort) {
      await controller.setSort(result);
    }
  }
}

/// Chip de filtro activo: todo el chip lo quita (objetivo táctil de 48 dp) y
/// lleva ícono además del texto.
class _RemovableChip extends StatelessWidget {
  const new({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      container: true,
      button: true,
      excludeSemantics: true,
      label: l10n.catalogRemoveFilter(label),
      onTap: onRemove,
      child: ActionChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(label)),
            const SizedBox(width: IprSpace.s1),
            const Icon(Icons.close, size: 18),
          ],
        ),
        onPressed: onRemove,
      ),
    );
  }
}

/// Falló aplicar filtros u orden: el listado previo sigue visible.
class _ApplyFailureBanner extends StatelessWidget {
  const new({required this.failure, required this.onRetry});

  final AppFailure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: IprSpace.s2),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(IprRadius.md),
        ),
        child: Padding(
          padding: const EdgeInsets.all(IprSpace.s3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Icon(
                      Icons.error_outline,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(width: IprSpace.s2),
                  Expanded(
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        failureText(l10n, failure),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (failure.retryable)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    onPressed: onRetry,
                    child: Text(l10n.actionRetry),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 200 con lista vacía (vacío real, no un error).
class _EmptyResults extends StatelessWidget {
  const new({required this.data, required this.mode, required this.controller});

  final ProductListData data;
  final ResultsMode mode;
  final ProductListController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final filters = data.filters;

    if (filters.isSearching) {
      return EmptyState(
        title: l10n.catalogEmptyBrandSearchTitle,
        body: l10n.catalogEmptyBrandSearchBody,
        action: OutlinedButton(
          onPressed: controller.clearFilters,
          child: Text(l10n.catalogClearFilters),
        ),
      );
    }
    if (filters.hasActive) {
      return EmptyState(
        title: l10n.catalogEmptyFilteredTitle,
        body: l10n.catalogEmptyFilteredBody,
        action: FilledButton(
          onPressed: controller.clearFilters,
          child: Text(l10n.catalogClearFilters),
        ),
      );
    }
    return switch (mode) {
      ResultsMode.category => EmptyState(
        title: l10n.catalogEmptyCategoryTitle,
        body: l10n.catalogEmptyCategoryBody,
        action: OutlinedButton(
          onPressed: () => context.push(Routes.search),
          child: Text(l10n.catalogEmptySearchAction),
        ),
      ),
      ResultsMode.brand => EmptyState(
        title: l10n.catalogEmptyBrandTitle,
        body: l10n.catalogEmptyBrandBody,
      ),
      ResultsMode.sale => EmptyState(
        title: l10n.catalogEmptySaleTitle,
        body: l10n.catalogEmptySaleBody,
      ),
    };
  }
}

/// Pie de la lista: cargando, fallo de la página N con reintento, o el final.
class _Footer extends StatelessWidget {
  const new({required this.data, required this.controller});

  final ProductListData data;
  final ProductListController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final Widget child;
    if (data.pageFailure != null) {
      child = Column(
        children: [
          Semantics(
            liveRegion: true,
            child: Text(
              failureText(l10n, data.pageFailure!),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          if (data.pageFailure!.retryable)
            Padding(
              padding: const EdgeInsets.only(top: IprSpace.s2),
              child: FilledButton.tonal(
                onPressed: () => controller.loadMore(retry: true),
                child: Text(l10n.actionRetry),
              ),
            ),
        ],
      );
    } else if (data.loadingMore) {
      child = Semantics(
        liveRegion: true,
        label: l10n.catalogLoadingMore,
        child: const Center(child: CircularProgressIndicator()),
      );
    } else if (!data.hasMore && data.items.isNotEmpty) {
      child = Text(
        l10n.catalogListEnd,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium,
      );
    } else {
      child = const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: IprSpace.s4,
        vertical: IprSpace.s4,
      ),
      child: child,
    );
  }
}

/// Rejilla de tarjetas (2 columnas; 3 en pantallas anchas) con texto normal, o
/// lista de una columna cuando el texto del sistema es ≥ 1,2× (y la propia
/// `ProductCard` adopta su variante horizontal a partir de 1,5×, RNF-068).
class _ProductSliver extends StatelessWidget {
  const new({required this.items, required this.showOfferBadge});

  final List<ProductSummary> items;
  final bool showOfferBadge;

  static const double _gap = IprSpace.s3;

  /// A partir de esta escala de texto la rejilla de altura fija ya no cabe
  /// sin recortes (el nombre y el precio se parten): se pasa a una columna.
  static const double _gridMaxScale = 1.2;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final asList = scale >= _gridMaxScale;

    Widget card(ProductSummary product) {
      final child = ProductCard(
        product: product,
        onTap: () => context.push(Routes.product(product.slug)),
      );
      return showOfferBadge
          ? _OfferOverlay(visible: product.onSale, child: child)
          : child;
    }

    if (asList) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: IprSpace.s4),
        sliver: SliverList.separated(
          itemCount: items.length,
          itemBuilder: (context, index) => card(items[index]),
          separatorBuilder: (_, _) => const SizedBox(height: _gap),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: IprSpace.s4),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.crossAxisExtent;
          final columns = width >= 600 ? 3 : 2;
          final cell = (width - _gap * (columns - 1)) / columns;
          // Alto de la tarjeta: imagen cuadrada + relleno + detalle (medido
          // con nombre largo y precio en oferta: 436 dp a 1,0× con celda de
          // 158 dp), que crece con el texto del sistema.
          final extent = cell + 32 + 280 * scale;
          return SliverGrid.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: _gap,
              crossAxisSpacing: _gap,
              mainAxisExtent: extent,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) => card(items[index]),
          );
        },
      ),
    );
  }
}

/// Insignia "Oferta" (texto + ícono, no solo color) sobre la tarjeta de una
/// liquidación; el precio regular tachado y el especial los pinta la tarjeta.
class _OfferOverlay extends StatelessWidget {
  const new({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!visible) return child;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Stack(
      children: [
        child,
        PositionedDirectional(
          top: IprSpace.s3,
          start: IprSpace.s3,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(IprRadius.sm),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: IprSpace.s2,
                  vertical: IprSpace.s1,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ExcludeSemantics(
                      child: Icon(
                        Icons.local_offer,
                        size: 14,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                    const SizedBox(width: IprSpace.s1),
                    Text(
                      l10n.sharedProductOnSale,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
