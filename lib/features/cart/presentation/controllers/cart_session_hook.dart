import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ipr_mobile/core/session/session_controller.dart';
import 'package:ipr_mobile/features/cart/domain/rules/cart_retention_policy.dart';
import 'package:ipr_mobile/features/cart/presentation/controllers/cart_controller.dart';

/// Engancha el carrito a los eventos de la cuenta según
/// [CartRetentionPolicy]: hoy, **conserva** al cerrar sesión (H-07 pendiente)
/// y **borra** al eliminar la cuenta (CR-040). El carrito no se toca al
/// expirar la sesión (RF-044): no hay gancho para ese caso a propósito.
final class CartSessionHook implements SessionHook {
  const new({required this.clear, this.policy = CartRetentionPolicy.current});

  final Future<void> Function() clear;
  final CartRetentionPolicy policy;

  @override
  Future<void> onLogout() async {
    if (policy.clearOnLogout) await clear();
  }

  @override
  Future<void> onAccountDeleted() async {
    if (policy.clearOnAccountDeleted) await clear();
  }
}

/// Gancho listo para registrar en `sessionHooksProvider` (lo cablea el
/// orquestador en `app/`).
final cartSessionHookProvider = Provider<SessionHook>(
  (ref) =>
      CartSessionHook(clear: () => ref.read(cartProvider.notifier).clear()),
);
