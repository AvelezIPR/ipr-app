import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/category_node.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/product_query.dart';
import 'package:ipr_mobile/features/catalog/presentation/controllers/taxonomy_controllers.dart';
import 'package:ipr_mobile/features/catalog/presentation/widgets/product_results.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/navigation/routes.dart';
import 'package:ipr_mobile/shared/widgets/ui_state.dart';
import 'package:material_ui/material_ui.dart';

/// Listado de productos de una categoría (`/catalog/list?category=…`, PT-03,
/// RF-011, RF-013 a RF-015). Sin [categorySlug] lista todo el catálogo.
///
/// El título es el nombre de la categoría (de la caché de taxonomía) y mientras
/// no se conoce, "Productos". Un 404 se muestra como "ya no está disponible",
/// distinto de un 503 (RF-009).
class ProductListScreen extends ConsumerWidget {
  const new({super.key, this.categorySlug});

  final String? categorySlug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final slug = categorySlug;
    final categories = ref.watch(categoriesProvider);
    final name = slug != null && categories is UiData<List<CategoryNode>>
        ? findCategory(categories.value, slug)?.name
        : null;
    return Scaffold(
      appBar: AppBar(
        title: Text(name ?? l10n.catalogListFallbackTitle),
        actions: [
          IconButton(
            tooltip: l10n.catalogSearchTooltip,
            icon: const Icon(Icons.search),
            onPressed: () => context.push(Routes.search),
          ),
        ],
      ),
      body: ProductResults(
        scope: slug == null ? const ListScope.all() : ListScope.category(slug),
        mode: ResultsMode.category,
      ),
    );
  }
}
