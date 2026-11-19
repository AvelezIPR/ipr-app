import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/category_node.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/filter_dimension.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/product_filters.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/product_query.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/product_sort.dart';
import 'package:ipr_mobile/features/catalog/presentation/controllers/taxonomy_controllers.dart';
import 'package:ipr_mobile/features/catalog/presentation/widgets/sort_labels.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:ipr_mobile/shared/widgets/state_widgets.dart';
import 'package:ipr_mobile/shared/widgets/ui_state.dart';
import 'package:material_ui/material_ui.dart';

/// Abre la hoja de filtros (PT-04) y devuelve los filtros elegidos, o `null`
/// si se cierra sin aplicar (los cambios pendientes se descartan, sin
/// confirmación).
Future<ProductFilters?> showCatalogFilterSheet(
  BuildContext context, {
  required ListScope scope,
  required ProductFilters current,
}) => showModalBottomSheet<ProductFilters>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (context) => _FilterSheet(scope: scope, current: current),
);

/// Abre la hoja de orden y devuelve el criterio elegido (o `null`).
Future<ProductSort?> showCatalogSortSheet(
  BuildContext context, {
  required ProductSort current,
}) => showModalBottomSheet<ProductSort>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (context) => _SortSheet(current: current),
);

class _SortSheet extends StatelessWidget {
  const new({required this.current});

  final ProductSort current;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              IprSpace.s4,
              0,
              IprSpace.s4,
              IprSpace.s2,
            ),
            child: Semantics(
              header: true,
              child: Text(
                l10n.catalogSortTitle,
                style: theme.textTheme.titleLarge,
              ),
            ),
          ),
          for (final sort in ProductSort.values)
            _SingleChoiceTile(
              label: sortLabelOf(l10n, sort),
              selected: sort == current,
              onTap: () => Navigator.of(context).pop(sort),
            ),
          const SizedBox(height: IprSpace.s4),
        ],
      ),
    );
  }
}

/// Opción excluyente con texto + ícono (nunca solo color).
class _SingleChoiceTile extends StatelessWidget {
  const new({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    inMutuallyExclusiveGroup: true,
    checked: selected,
    button: true,
    excludeSemantics: true,
    label: label,
    onTap: onTap,
    child: ListTile(
      minTileHeight: IprSpace.minTapTarget,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
      ),
      title: Text(label),
      selected: selected,
      onTap: onTap,
    ),
  );
}

class _FilterSheet extends ConsumerStatefulWidget {
  const new({required this.scope, required this.current});

  final ListScope scope;
  final ProductFilters current;

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late ProductFilters _draft = widget.current;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final dimensions = ref.watch(
      filterDimensionsProvider(widget.scope.categorySlug),
    );
    final categories = ref.watch(categoriesProvider);
    final childCategories = _childCategories(categories);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: IprSpace.s4),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    l10n.catalogFilterSheetTitle,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.catalogFilterClose),
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (childCategories.isNotEmpty)
                  _CategorySection(
                    categories: childCategories,
                    selected: _draft.category?.slug,
                    onSelect: (node) => setState(
                      () => _draft = _draft.withCategory(
                        node == null
                            ? null
                            : CategoryChoice(slug: node.slug, name: node.name),
                      ),
                    ),
                  ),
                ..._dimensionSections(context, dimensions),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(IprSpace.s4),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _draft = _draft.cleared()),
                  child: Text(l10n.catalogFilterClear),
                ),
              ),
              const SizedBox(width: IprSpace.s3),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(_draft),
                  child: Text(l10n.catalogFilterApply),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Subcategorías directas de la categoría del listado (o las raíces si no
  /// hay categoría), tal como las entrega el servidor.
  List<CategoryNode> _childCategories(UiState<List<CategoryNode>> state) {
    if (state is! UiData<List<CategoryNode>>) return const [];
    final slug = widget.scope.categorySlug;
    if (slug == null) return state.value;
    return findCategory(state.value, slug)?.children ?? const [];
  }

  List<Widget> _dimensionSections(
    BuildContext context,
    UiState<List<FilterDimension>> state,
  ) {
    final l10n = AppLocalizations.of(context);
    switch (state) {
      case UiLoading<List<FilterDimension>>():
        return const [SizedBox(height: 96, child: LoadingState())];
      case UiFailure<List<FilterDimension>>(:final failure):
        // Los filtros no cargaron: el resto de la hoja sigue siendo usable.
        return [
          ErrorState(
            failure: failure,
            onRetry: () => ref
                .read(
                  filterDimensionsProvider(widget.scope.categorySlug).notifier,
                )
                .retry(),
          ),
        ];
      case UiEmpty<List<FilterDimension>>():
        return [_NoFilters(text: l10n.catalogFilterNone)];
      case UiData<List<FilterDimension>>(:final value):
        final dimensions = [
          for (final d in value)
            // En la landing de marca, la marca ya está fijada.
            if (!(widget.scope.kind == ListKind.brand &&
                d.key == FilterKeys.brand))
              d,
        ];
        if (dimensions.isEmpty) {
          return [_NoFilters(text: l10n.catalogFilterNone)];
        }
        return [
          for (final d in dimensions)
            _DimensionSection(
              dimension: d,
              filters: _draft,
              onToggle: (choice) =>
                  setState(() => _draft = _draft.toggled(choice)),
            ),
        ];
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const new(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      IprSpace.s4,
      IprSpace.s4,
      IprSpace.s4,
      IprSpace.s1,
    ),
    child: Semantics(
      header: true,
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    ),
  );
}

class _NoFilters extends StatelessWidget {
  const new({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(IprSpace.s4),
    child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
  );
}

class _CategorySection extends StatelessWidget {
  const new({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  final List<CategoryNode> categories;
  final String? selected;
  final void Function(CategoryNode? node) onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(l10n.catalogFilterCategorySection),
        _SingleChoiceTile(
          label: l10n.catalogFilterCategoryAll,
          selected: selected == null,
          onTap: () => onSelect(null),
        ),
        for (final node in categories)
          _SingleChoiceTile(
            label: node.name,
            selected: selected == node.slug,
            onTap: () => onSelect(node),
          ),
      ],
    );
  }
}

class _DimensionSection extends StatelessWidget {
  const new({
    required this.dimension,
    required this.filters,
    required this.onToggle,
  });

  final FilterDimension dimension;
  final ProductFilters filters;
  final void Function(FilterChoice choice) onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final canAdd = filters.canAdd(dimension.key);
    final isBoolean = dimension.type == FilterDimensionType.boolean;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(dimension.label),
        for (final option in dimension.options)
          Builder(
            builder: (context) {
              final selected = filters.contains(dimension.key, option.value);
              return CheckboxListTile(
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: IprSpace.s4,
                ),
                title: Text(option.label),
                value: selected,
                // Con el máximo del contrato alcanzado solo se pueden quitar.
                onChanged: (selected || canAdd)
                    ? (_) => onToggle(
                        FilterChoice(
                          key: dimension.key,
                          value: option.value,
                          keyLabel: dimension.label,
                          valueLabel: option.label,
                          boolean: isBoolean,
                        ),
                      )
                    : null,
              );
            },
          ),
        if (!isBoolean && !canAdd)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: IprSpace.s4,
              vertical: IprSpace.s1,
            ),
            child: Text(
              l10n.catalogFilterLimitHint(FilterKeys.maxValuesPerKey),
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}
