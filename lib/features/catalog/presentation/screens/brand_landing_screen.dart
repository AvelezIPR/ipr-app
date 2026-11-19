import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/brand.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/product_query.dart';
import 'package:ipr_mobile/features/catalog/presentation/controllers/product_list_controller.dart';
import 'package:ipr_mobile/features/catalog/presentation/controllers/taxonomy_controllers.dart';
import 'package:ipr_mobile/features/catalog/presentation/widgets/product_results.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:ipr_mobile/shared/navigation/routes.dart';
import 'package:ipr_mobile/shared/widgets/ui_state.dart';
import 'package:material_ui/material_ui.dart';

/// Landing de marca (`/catalog/brands/:slug`, RF-016): productos de la marca
/// con paginación, filtros, orden y **búsqueda interna** restringida a la
/// marca. El contenido editorial de la landing es de fase 2 (RF-017).
///
/// El término de búsqueda lo escribe el usuario: no se registra ni se guarda
/// en caché.
class BrandLandingScreen extends ConsumerStatefulWidget {
  const new({required this.slug, super.key});

  final String slug;

  @override
  ConsumerState<BrandLandingScreen> createState() => _BrandLandingScreenState();
}

class _BrandLandingScreenState extends ConsumerState<BrandLandingScreen> {
  final TextEditingController _search = TextEditingController();
  String? _committed;

  ListScope get _scope => ListScope.brand(widget.slug);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _submit(String value) {
    FocusScope.of(context).unfocus();
    unawaited(ref.read(productListProvider(_scope).notifier).search(value));
  }

  void _clear() {
    _search.clear();
    FocusScope.of(context).unfocus();
    unawaited(ref.read(productListProvider(_scope).notifier).search(null));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = productListProvider(_scope);

    // Mantiene el campo en sincronía cuando el filtro de búsqueda se quita
    // desde un chip o con "Limpiar filtros".
    ref.listen(provider, (previous, next) {
      if (next is! UiData<ProductListData>) return;
      final term = next.value.filters.searchTerm;
      if (term != _committed) {
        _committed = term;
        if (_search.text != (term ?? '')) _search.text = term ?? '';
      }
    });

    final brands = ref.watch(brandsProvider);
    final list = ref.watch(provider);
    final title = _title(l10n, brands, list);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: l10n.catalogSearchTooltip,
            icon: const Icon(Icons.search),
            onPressed: () => context.push(Routes.search),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              IprSpace.s4,
              IprSpace.s3,
              IprSpace.s4,
              IprSpace.s1,
            ),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              maxLength: 120,
              buildCounter: (
                context, {
                required currentLength,
                required isFocused,
                required maxLength,
              }) => null,
              onSubmitted: _submit,
              decoration: InputDecoration(
                labelText: l10n.catalogBrandSearchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _search,
                  builder: (context, value, _) => value.text.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          tooltip: l10n.catalogBrandSearchClear,
                          icon: const Icon(Icons.close),
                          onPressed: _clear,
                        ),
                ),
              ),
            ),
          ),
          Expanded(
            child: ProductResults(scope: _scope, mode: ResultsMode.brand),
          ),
        ],
      ),
    );
  }

  /// Nombre de la marca: el del directorio o, si no se pudo cargar, el de los
  /// productos listados.
  String _title(
    AppLocalizations l10n,
    UiState<List<Brand>> brands,
    UiState<ProductListData> list,
  ) {
    if (brands is UiData<List<Brand>>) {
      for (final brand in brands.value) {
        if (brand.slug == widget.slug) return brand.name;
      }
    }
    if (list is UiData<ProductListData>) {
      final name = list.value.items
          .map((p) => p.brandName)
          .firstWhere((n) => n != null && n.isNotEmpty, orElse: () => null);
      if (name != null) return name;
    }
    return l10n.catalogBrandTitleFallback;
  }
}
