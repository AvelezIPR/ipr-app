// Raíz de composición de la feature: cablea el repositorio concreto (`data/`)
// con las dependencias del núcleo. Vive en la raíz de la feature (ni en
// `presentation/` ni en `data/`) para que `presentation/controllers` pueda
// leer el provider sin importar `data/` (D4), y las pruebas lo sustituyen con
// `overrides`.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ipr_mobile/core/providers.dart';
import 'package:ipr_mobile/features/product_detail/data/repositories/api_product_detail_repository.dart';
import 'package:ipr_mobile/features/product_detail/domain/repositories/product_detail_repository.dart';

final productDetailRepositoryProvider = Provider<ProductDetailRepository>(
  (ref) => ApiProductDetailRepository(
    client: ref.watch(apiClientProvider),
    cache: ref.watch(cacheStoreProvider),
  ),
);
