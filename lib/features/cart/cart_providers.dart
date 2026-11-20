// Raíz de composición de la feature: cablea los repositorios concretos
// (`data/`) con el núcleo. Vive en la raíz de la feature para que
// `presentation/controllers` lea los providers sin importar `data/` (D4) y las
// pruebas los sustituyan con `overrides`.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ipr_mobile/core/providers.dart';
import 'package:ipr_mobile/features/cart/data/repositories/api_cart_validation_repository.dart';
import 'package:ipr_mobile/features/cart/data/repositories/durable_cart_repository.dart';
import 'package:ipr_mobile/features/cart/domain/repositories/cart_repositories.dart';

/// Carrito local en el almacén duradero (sin PII, sin caducidad).
final cartLocalRepositoryProvider = Provider<CartLocalRepository>(
  (ref) => DurableCartRepository(ref.watch(durableStoreProvider)),
);

/// Revalidación `POST /cart/validate`.
final cartValidationRepositoryProvider = Provider<CartValidationRepository>(
  (ref) => ApiCartValidationRepository(ref.watch(apiClientProvider)),
);
