import 'package:ipr_mobile/features/catalog/domain/entities/product_sort.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';

/// Texto es-CO de un criterio de orden.
String sortLabelOf(AppLocalizations l10n, ProductSort sort) => switch (sort) {
  ProductSort.latest => l10n.catalogSortLatest,
  ProductSort.popularity => l10n.catalogSortPopularity,
  ProductSort.priceAsc => l10n.catalogSortPriceAsc,
  ProductSort.priceDesc => l10n.catalogSortPriceDesc,
  ProductSort.name => l10n.catalogSortName,
};
