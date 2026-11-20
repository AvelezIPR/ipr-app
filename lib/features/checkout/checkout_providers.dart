import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ipr_mobile/core/network/uuid_v4.dart';
import 'package:ipr_mobile/core/providers.dart';
import 'package:ipr_mobile/core/session/session_controller.dart';
import 'package:ipr_mobile/features/cart/cart.dart';
import 'package:ipr_mobile/features/checkout/data/datasources/checkout_remote_datasource.dart';
import 'package:ipr_mobile/features/checkout/data/repositories/api_checkout_repository.dart';
import 'package:ipr_mobile/features/checkout/data/repositories/cache_pending_checkout_store.dart';
import 'package:ipr_mobile/features/checkout/data/repositories/cart_checkout_adapter.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/checkout_line.dart';
import 'package:ipr_mobile/features/checkout/domain/repositories/checkout_cart.dart';
import 'package:ipr_mobile/features/checkout/domain/repositories/checkout_repository.dart';
import 'package:ipr_mobile/features/checkout/domain/repositories/pending_checkout_store.dart';

/// Repositorio del checkout. Las pruebas lo sustituyen con un doble de la
/// interfaz de dominio. Vive en la raíz de la feature porque los controladores
/// (presentation) no pueden importar `data/` (D4).
final checkoutRepositoryProvider = Provider<CheckoutRepository>(
  (ref) => ApiCheckoutRepository(
    CheckoutRemoteDataSource(ref.watch(apiClientProvider)),
  ),
);

/// Registro sin PII del intento en curso (se reanuda tras un cierre forzado).
final pendingCheckoutStoreProvider = Provider<PendingCheckoutStore>(
  (ref) => CachePendingCheckoutStore(
    ref.watch(cacheStoreProvider),
    now: ref.watch(checkoutNowProvider),
  ),
);

/// Puente con la feature `cart` (ver `CheckoutCart`). Sobrescribible en
/// pruebas con un doble. Se reconstruye cuando cambian las líneas del carrito
/// para que el resumen de solo lectura se mantenga al día.
final checkoutCartProvider = Provider<CheckoutCart>((ref) {
  ref.watch(cartProvider.select((state) => state.lines));
  return CartCheckoutAdapter(ref);
});

/// Líneas del carrito para el resumen de solo lectura.
final checkoutLinesProvider = Provider<List<CheckoutLine>>(
  (ref) => ref.watch(checkoutCartProvider).lines,
);

/// Reloj inyectable (pruebas).
final checkoutNowProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Espera inyectable del sondeo (pruebas con `fakeAsync`).
final checkoutSleepProvider = Provider<Future<void> Function(Duration)>(
  (ref) => Future<void>.delayed,
);

/// Generador de UUID v4 para ids de intento y claves de idempotencia.
final checkoutUuidProvider = Provider<String Function()>((ref) => uuidV4);

/// Gancho de sesión: al cerrar sesión o eliminar la cuenta borra el registro
/// del intento en curso (sin PII, pero no debe sobrevivir a la persona).
/// El orquestador lo puede añadir a `sessionHooksProvider`.
final checkoutSessionHookProvider = Provider<SessionHook>(
  (ref) => _CheckoutSessionHook(ref.watch(pendingCheckoutStoreProvider)),
);

final class _CheckoutSessionHook implements SessionHook {
  const new(this._store);

  final PendingCheckoutStore _store;

  @override
  Future<void> onLogout() => _store.clear();

  @override
  Future<void> onAccountDeleted() => _store.clear();
}
