import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/brand.dart';
import 'package:ipr_mobile/features/catalog/presentation/controllers/taxonomy_controllers.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:ipr_mobile/shared/domain/image_ref.dart';
import 'package:ipr_mobile/shared/navigation/routes.dart';
import 'package:ipr_mobile/shared/widgets/product_image.dart';
import 'package:ipr_mobile/shared/widgets/state_widgets.dart';
import 'package:material_ui/material_ui.dart';

/// Directorio de marcas (`/catalog/brands`, PT-05, RF-016): todas las marcas
/// que devuelve el servidor, con su cantidad; tocar una abre su landing.
/// Pública: sin sesión.
class BrandsScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.catalogBrandsTitle)),
      body: AsyncView(
        state: ref.watch(brandsProvider),
        onRetry: () => ref.read(brandsProvider.notifier).retry(),
        empty: EmptyState(body: l10n.catalogBrandsEmpty),
        builder: (context, brands) => ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                IprSpace.s4,
                IprSpace.s3,
                IprSpace.s4,
                IprSpace.s1,
              ),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  l10n.catalogBrandsCount(brands.length),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ),
            for (final brand in brands) _BrandTile(brand: brand),
          ],
        ),
      ),
    );
  }
}

class _BrandTile extends StatelessWidget {
  const new({required this.brand});

  final Brand brand;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    void open() => context.push(Routes.brand(brand.slug));
    final logo = brand.logoUrl;
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: l10n.catalogBrandItemSemantics(brand.name),
      onTap: open,
      child: ListTile(
        minTileHeight: IprSpace.minTapTarget + IprSpace.s2,
        leading: SizedBox(
          width: IprSpace.s7,
          height: IprSpace.s7,
          child: ProductImage(
            image: logo == null ? null : ImageRef(url: logo, alt: brand.name),
          ),
        ),
        title: Text(brand.name),
        trailing: const Icon(Icons.chevron_right),
        onTap: open,
      ),
    );
  }
}
