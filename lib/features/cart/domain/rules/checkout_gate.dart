import 'package:ipr_mobile/features/cart/domain/entities/cart.dart';
import 'package:ipr_mobile/features/cart/domain/entities/cart_overview.dart';
import 'package:ipr_mobile/features/cart/domain/entities/cart_validation.dart';

/// Por qué se puede o no pasar a pagar (RF-050, RF-052, AC-052-7).
enum CartReadiness {
  /// Se puede ir al pago.
  ready,

  /// Carrito vacío: no hay "Pagar" (AC-049-6).
  empty,

  /// `remoteConfig.checkoutEnabled` apagado: falla cerrado.
  checkoutDisabled,

  /// No hay una validación vigente del servidor para este carrito (nunca se
  /// validó, el último intento falló, o las cantidades/líneas cambiaron
  /// después). El pago exige volver a verificar (AC-050-7, RNF-020).
  unverified,

  /// Hay líneas agotadas, bajo pedido, sin precio o inexistentes (AC-050-3,
  /// -5, -6).
  blockedLines,

  /// Hay cambios de precio por aceptar (AC-050-2, ver [CartChangePolicy]).
  pendingChanges,

  /// El servidor dijo `checkoutAllowed = false`: manda el servidor.
  serverDenied,
}

/// Evalúa si el carrito puede pasar al pago. Es la **única** regla: la pantalla
/// y el controlador la consultan; nada más decide.
///
/// * [validatedFor]: `id → cantidad` que se envió en la última validación
///   exitosa. Las líneas ya quitadas no invalidan la verificación; una línea
///   nueva o con otra cantidad, sí.
/// * [validationFailed]: el último intento de revalidar falló.
CartReadiness evaluateCartReadiness({
  required Cart cart,
  required bool checkoutEnabled,
  required CartValidation? validation,
  required Map<int, int>? validatedFor,
  required bool validationFailed,
  required CartOverview overview,
}) {
  if (cart.isEmpty) return CartReadiness.empty;
  if (!checkoutEnabled) return CartReadiness.checkoutDisabled;

  if (validation == null || validatedFor == null || validationFailed) {
    return CartReadiness.unverified;
  }
  final covered = cart.lines.every(
    (line) =>
        validatedFor[line.productId] == line.quantity &&
        validation.lineFor(line.productId) != null,
  );
  if (!covered) return CartReadiness.unverified;

  if (overview.hasBlockingLines) return CartReadiness.blockedLines;
  if (overview.pendingAcknowledgements.isNotEmpty) {
    return CartReadiness.pendingChanges;
  }
  if (!validation.checkoutAllowed) {
    // Si se quitaron líneas desde esa validación (p. ej. la agotada), el
    // "no" del servidor pudo deberse a ellas: hay que volver a preguntar
    // (AC-050-4) en vez de quedar bloqueado con un dato viejo.
    return validatedFor.length > cart.lineCount
        ? CartReadiness.unverified
        : CartReadiness.serverDenied;
  }
  return CartReadiness.ready;
}
