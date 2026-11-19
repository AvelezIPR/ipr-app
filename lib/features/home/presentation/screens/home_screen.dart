import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ipr_mobile/core/config/remote_config_controller.dart';
import 'package:ipr_mobile/core/providers.dart';
import 'package:ipr_mobile/features/home/presentation/controllers/home_controllers.dart';
import 'package:ipr_mobile/features/home/presentation/widgets/home_blocks.dart';
import 'package:ipr_mobile/features/home/presentation/widgets/home_section.dart';
import 'package:ipr_mobile/features/home/presentation/widgets/tile_grid.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:ipr_mobile/shared/navigation/routes.dart';
import 'package:ipr_mobile/shared/widgets/product_card.dart';
import 'package:ipr_mobile/shared/widgets/state_widgets.dart';
import 'package:ipr_mobile/shared/widgets/ui_state.dart';
import 'package:ipr_mobile/shared/widgets/whatsapp_button.dart';
import 'package:material_ui/material_ui.dart';

/// Cuántas tarjetas del bloque "más vendidos" se pintan. Presentación
/// provisional (el inventario de la web muestra 8): el criterio de selección
/// y la cantidad reales son DESCONOCIDOS (PA-05); la app pinta lo que entrega
/// el servidor hasta este tope.
const homeFeaturedShown = 8;

bool _isStale<T>(UiState<T> state) => state is UiData<T> && state.stale;

/// Pestaña Inicio (PT-01, RF-001..005, 007, 064).
///
/// El buscador y los botones de WhatsApp no dependen de la red: son operativos
/// desde el primer cuadro. Categorías, más vendidos y marcas cargan por
/// separado, cada una con su propio estado y su propio "Reintentar"
/// (AC-003-4); `pull-to-refresh` recarga las tres.
class HomeScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final categories = ref.watch(homeCategoriesProvider);
    final featured = ref.watch(homeFeaturedProvider);
    final brands = ref.watch(homeBrandsProvider);
    final anyStale =
        _isStale(categories) || _isStale(featured) || _isStale(brands);
    final dial = ref.watch(
      remoteConfigProvider.select((s) => s.config.phoneDial),
    );
    final display = ref.watch(
      remoteConfigProvider.select((s) => s.config.phoneDisplay),
    );

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () => refreshHome(ref),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            IprSpace.s4,
            IprSpace.s3,
            IprSpace.s4,
            IprSpace.s6,
          ),
          children: [
            Semantics(
              header: true,
              child: Text(l10n.appTitle, style: theme.textTheme.headlineSmall),
            ),
            if (anyStale) ...[
              const SizedBox(height: IprSpace.s3),
              const StaleBanner(),
            ],
            const SizedBox(height: IprSpace.s3),
            SearchEntry(
              onTap: () => unawaited(context.push(Routes.searchFor(''))),
            ),
            const SizedBox(height: IprSpace.s3),
            WhatsAppButton(
              label: l10n.sharedWhatsappAdvice,
              message: l10n.sharedWhatsappMsgAdvice,
            ),
            HomeSection(
              title: l10n.homeCategoriesTitle,
              state: categories,
              onRetry: () => unawaited(
                ref
                    .read(homeCategoriesProvider.notifier)
                    .load(forceRefresh: true),
              ),
              emptyBuilder: (context) => EmptyState(
                title: l10n.homeCategoriesEmptyTitle,
                body: l10n.homeCategoriesEmptyBody,
              ),
              builder: (context, items) => TileGrid(
                children: [
                  for (final category in items)
                    CategoryTile(
                      category: category,
                      onTap: () => unawaited(
                        context.push(Routes.categoryList(category.slug)),
                      ),
                    ),
                ],
              ),
            ),
            HomeSection(
              title: l10n.homeFeaturedTitle,
              state: featured,
              skeletonHeight: 220,
              onRetry: () => unawaited(
                ref
                    .read(homeFeaturedProvider.notifier)
                    .load(forceRefresh: true),
              ),
              builder: (context, items) => TileGrid(
                children: [
                  for (final product in items.take(homeFeaturedShown))
                    ProductCard(
                      product: product,
                      onTap: () =>
                          unawaited(context.push(Routes.product(product.slug))),
                    ),
                ],
              ),
            ),
            const SizedBox(height: IprSpace.s5),
            Semantics(
              header: true,
              child: Text(
                l10n.homeQuoteTitle,
                style: theme.textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: IprSpace.s3),
            WhatsAppButton(
              label: l10n.sharedWhatsappQuote,
              message: l10n.sharedWhatsappMsgQuote,
              filled: false,
            ),
            HomeSection(
              title: l10n.homeBrandsTitle,
              state: brands,
              skeletonHeight: 56,
              onRetry: () => unawaited(
                ref.read(homeBrandsProvider.notifier).load(forceRefresh: true),
              ),
              builder: (context, items) => BrandChips(
                brands: items,
                onTap: (brand) =>
                    unawaited(context.push(Routes.brand(brand.slug))),
              ),
            ),
            const SizedBox(height: IprSpace.s5),
            Semantics(
              header: true,
              child: Text(
                l10n.homeShortcutsTitle,
                style: theme.textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: IprSpace.s3),
            ShortcutTile(
              icon: Icons.sell_outlined,
              label: l10n.homeBrandsSeeAll,
              onTap: () => unawaited(context.push(Routes.brands)),
            ),
            const SizedBox(height: IprSpace.s2),
            ShortcutTile(
              icon: Icons.local_offer_outlined,
              label: l10n.homeShortcutSale,
              onTap: () => unawaited(context.push(Routes.sale)),
            ),
            const SizedBox(height: IprSpace.s2),
            ShortcutTile(
              icon: Icons.storefront_outlined,
              label: l10n.homeShortcutBranches,
              onTap: () => unawaited(context.push(Routes.branches)),
            ),
            if (dial != null && dial.isNotEmpty) ...[
              const SizedBox(height: IprSpace.s2),
              ShortcutTile(
                icon: Icons.phone_outlined,
                label: l10n.homeShortcutCall,
                subtitle: display,
                onTap: () => unawaited(_call(context, ref, dial)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _call(BuildContext context, WidgetRef ref, String dial) async {
    final opened = await ref
        .read(externalLauncherProvider)
        .open(Uri(scheme: 'tel', path: dial));
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).homeCallFailed)),
    );
  }
}
