import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ipr_mobile/core/config/remote_config_controller.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/cart/cart_providers.dart';
import 'package:ipr_mobile/features/cart/domain/entities/cart.dart';
import 'package:ipr_mobile/features/cart/domain/entities/cart_line.dart';
import 'package:ipr_mobile/features/cart/domain/entities/cart_overview.dart';
import 'package:ipr_mobile/features/cart/domain/entities/cart_validation.dart';
import 'package:ipr_mobile/features/cart/domain/rules/cart_reconciler.dart';
import 'package:ipr_mobile/features/cart/domain/rules/checkout_gate.dart';
import 'package:ipr_mobile/shared/domain/money.dart';
import 'package:ipr_mobile/shared/domain/product_summary.dart';
import 'package:meta/meta.dart';

/// Estado del carrito (E37 + revalidación).
///
/// Los campos de `lines` y `validation` son el contrato con `checkout`; el
/// resto es de la propia feature. Todo lo transitorio (`validation`,
/// `changes`...) vive solo en memoria: en disco solo van las líneas.
@immutable
final class CartState {
  const new({
    this.lines = const [],
    this.validation,
    this.loaded = true,
    this.revalidating = false,
    this.validationFailure,
    this.changes = const {},
    this.validatedFor,
  });

  /// Líneas del carrito (fuente local de verdad hasta el pago).
  final List<CartLine> lines;

  /// Última respuesta **exitosa** de `/cart/validate`; `null` si nunca se
  /// validó. Si un intento posterior falla, se conserva (ver
  /// [validationFailure]) para poder mostrar algo, pero ya no autoriza pagar.
  final CartValidation? validation;

  /// Ya se leyó el almacén local.
  final bool loaded;

  /// Hay una revalidación en curso.
  final bool revalidating;

  /// Motivo del último intento fallido de revalidar; `null` si el último fue
  /// bien o aún no hubo.
  final AppFailure? validationFailure;

  /// Cambios de precio o disponibilidad por informar (id → cambio).
  final Map<int, CartLineChange> changes;

  /// `id → cantidad` enviada en la validación de [validation].
  final Map<int, int>? validatedFor;

  bool get isEmpty => lines.isEmpty;

  /// Unidades totales (insignia de la pestaña).
  int get unitCount => lines.fold(0, (sum, line) => sum + line.quantity);

  Cart get cart => Cart(lines);

  /// Vista consolidada (líneas + servidor + cambios + subtotal informativo).
  CartOverview get overview => CartOverview.build(
    cart: cart,
    validation: validation,
    validatedFor: validatedFor,
    validationFailed: validationFailure != null,
    changes: changes,
  );

  /// ¿Se puede pagar? Única fuente: [evaluateCartReadiness].
  CartReadiness readiness({required bool checkoutEnabled}) =>
      evaluateCartReadiness(
        cart: cart,
        checkoutEnabled: checkoutEnabled,
        validation: validation,
        validatedFor: validatedFor,
        validationFailed: validationFailure != null,
        overview: overview,
      );

  CartState copyWith({
    List<CartLine>? lines,
    CartValidation? validation,
    bool? loaded,
    bool? revalidating,
    AppFailure? validationFailure,
    Map<int, CartLineChange>? changes,
    Map<int, int>? validatedFor,
    bool clearValidation = false,
    bool clearFailure = false,
  }) => CartState(
    lines: lines ?? this.lines,
    validation: clearValidation ? null : (validation ?? this.validation),
    loaded: loaded ?? this.loaded,
    revalidating: revalidating ?? this.revalidating,
    validationFailure: clearFailure
        ? null
        : (validationFailure ?? this.validationFailure),
    changes: changes ?? this.changes,
    validatedFor: clearValidation ? null : (validatedFor ?? this.validatedFor),
  );
}

/// Resultado de tocar "Pagar" (revalida antes de ir al pago, RF-050).
enum CartCheckoutAttempt {
  /// Verificado por completo: se puede navegar al checkout.
  proceed,

  /// Se verificó, pero hay algo que resolver (líneas no disponibles, cambios
  /// de precio, el servidor no lo permite...).
  blocked,

  /// No se pudo verificar (sin red, 5xx, tiempo agotado): no se paga con
  /// datos sin verificar (AC-050-7).
  verificationFailed,
}

/// Carrito de la app. Se crea una vez (no se descarta) y lee el almacén local
/// al iniciar; toda operación espera a esa lectura.
///
/// * Cada cambio se guarda en el almacén duradero, en orden.
/// * Un fallo de red al revalidar **no** toca las líneas (P4).
/// * El carrito nunca se sincroniza con el servidor (AC-049-9): solo
///   `POST /cart/validate`, con ids y cantidades.
/// * Cerrar sesión no lo borra (H-07 / CR-040: ver `CartRetentionPolicy`).
final cartProvider = NotifierProvider<CartController, CartState>(
  CartController.new,
);

/// Unidades totales del carrito, para la insignia de la pestaña.
final cartUnitCountProvider = Provider<int>(
  (ref) => ref.watch(cartProvider.select((state) => state.unitCount)),
);

/// Vista consolidada (líneas + servidor + cambios + subtotal informativo).
final cartOverviewProvider = Provider<CartOverview>(
  (ref) => ref.watch(cartProvider.select((state) => state.overview)),
);

/// ¿Se puede pagar? Única fuente: [evaluateCartReadiness] con el interruptor
/// `checkoutEnabled` de `/config` (apagado → no se paga, falla cerrado).
final cartReadinessProvider = Provider<CartReadiness>((ref) {
  final state = ref.watch(cartProvider);
  final enabled = ref.watch(
    remoteConfigProvider.select((s) => s.config.checkoutEnabled),
  );
  return state.readiness(checkoutEnabled: enabled);
});

class CartController extends Notifier<CartState> {
  Future<void> _ready = Future<void>.value();
  Future<void> _writes = Future<void>.value();
  Future<Result<CartValidation>>? _inFlight;

  /// Se incrementa al vaciar: una respuesta de una revalidación anterior a
  /// `clear()` no resucita datos.
  int _epoch = 0;

  @override
  CartState build() {
    _ready = _load();
    return const CartState(loaded: false);
  }

  Future<void> _load() async {
    final cart = await ref.read(cartLocalRepositoryProvider).load();
    if (!ref.mounted) return;
    state = state.copyWith(lines: cart.lines, loaded: true);
  }

  /// Guarda en orden (cada escritura espera a la anterior).
  Future<void> _persist(Cart cart) {
    final repository = ref.read(cartLocalRepositoryProvider);
    return _writes = _writes.then((_) => repository.save(cart));
  }

  /// Añade [quantity] unidades de [productId] (suma si ya existe; 1–99;
  /// ≤ 100 líneas). [snapshot] es el producto tal como lo vio el usuario, para
  /// pintar la línea sin red; sin él la línea se muestra por referencia hasta
  /// la primera revalidación. Devuelve el detalle (fusión, cantidad acotada).
  Future<CartAddResult> addLine(
    int productId,
    int quantity, {
    ProductSummary? snapshot,
  }) async {
    await _ready;
    final result = state.cart.add(
      productId: productId,
      quantity: quantity,
      snapshot: snapshot == null
          ? null
          : CartLineSnapshot.fromProduct(snapshot),
    );
    if (result is CartAdded) {
      _apply(result.cart);
      await _persist(result.cart);
    }
    return result;
  }

  /// Costura con la ficha: `Ok` si quedó en el carrito. Un rechazo es
  /// `Err(Validation)` con un código `cart_*` (ver [cartRejectionCode]).
  Future<Result<void>> add(
    int productId,
    int quantity, {
    ProductSummary? snapshot,
  }) async {
    final result = await addLine(productId, quantity, snapshot: snapshot);
    return switch (result) {
      CartAdded() => const Ok(null),
      CartAddRejected(:final reason) => Err(
        Validation(code: cartRejectionCode(reason)),
      ),
    };
  }

  /// Fija la cantidad (llevada a 1–99; bajar de 1 no quita la línea).
  Future<void> setQuantity(int productId, int quantity) async {
    await _ready;
    final next = state.cart.setQuantity(productId, quantity);
    if (next == state.cart) return;
    _apply(next);
    await _persist(next);
  }

  /// Quita la línea (acción explícita).
  Future<void> remove(int productId) async {
    await _ready;
    final next = state.cart.remove(productId);
    if (next == state.cart) return;
    _apply(next);
    await _persist(next);
    _refreshAfterRemoval();
  }

  /// Quita todas las líneas que se sabe que no se pueden comprar (agotadas,
  /// bajo pedido, sin precio, inexistentes).
  Future<void> removeUnavailable() async {
    await _ready;
    final ids = {
      for (final view in state.overview.blockingLines) view.productId,
    };
    final next = state.cart.removeAll(ids);
    if (next == state.cart) return;
    _apply(next);
    await _persist(next);
    _refreshAfterRemoval();
  }

  /// Devuelve [line] a su posición tras "Deshacer".
  Future<void> restoreLine(CartLine line, int index) async {
    await _ready;
    final next = state.cart.restore(line, index);
    if (next == state.cart) return;
    _apply(next);
    await _persist(next);
  }

  /// El usuario acepta los cambios mostrados ("Ajustar"): el precio vigente
  /// pasa a ser su referencia. Sin [productId] acepta todos. Los cambios de
  /// disponibilidad que bloquean el pago no se resuelven así: se quitan las
  /// líneas.
  void acceptChanges([int? productId]) {
    state = state.copyWith(
      changes: {
        if (productId != null)
          for (final entry in state.changes.entries)
            if (entry.key != productId) entry.key: entry.value,
      },
    );
  }

  /// Vacía el carrito. **Solo** lo llama `checkout` cuando el servidor confirma
  /// `paid` (RF-057, IR-16), el usuario, o la eliminación de la cuenta
  /// (CR-040).
  Future<void> clear() async {
    await _ready;
    _epoch++;
    state = const CartState();
    await _persist(Cart.empty);
  }

  /// Revalida precio y disponibilidad con el servidor (RF-050). Solo viaja
  /// `{id, quantity}`. Éxito → se reemplazan las instantáneas y se informan
  /// los cambios. Fallo → **no** se toca ninguna línea ni se marca nada como
  /// cambiado. Dos llamadas simultáneas comparten una sola petición.
  Future<Result<CartValidation>> revalidate() {
    final running = _inFlight;
    if (running != null) return running;
    final future = _revalidate().whenComplete(() => _inFlight = null);
    return _inFlight = future;
  }

  /// Revalida y dice si se puede ir al checkout. Es lo que hace "Pagar":
  /// nunca se paga con datos sin verificar (AC-050-7).
  Future<CartCheckoutAttempt> attemptCheckout() async {
    final result = await revalidate();
    if (result.isErr) return CartCheckoutAttempt.verificationFailed;
    final enabled = ref.read(remoteConfigProvider).config.checkoutEnabled;
    return state.readiness(checkoutEnabled: enabled) == CartReadiness.ready
        ? CartCheckoutAttempt.proceed
        : CartCheckoutAttempt.blocked;
  }

  Future<Result<CartValidation>> _revalidate() async {
    await _ready;
    final sent = state.cart;
    if (sent.isEmpty) {
      return const Ok(
        CartValidation(
          checkoutAllowed: false,
          lines: [],
          informativeSubtotal: Money.zero,
        ),
      );
    }

    final epoch = _epoch;
    state = state.copyWith(revalidating: true);
    final result = await ref
        .read(cartValidationRepositoryProvider)
        .validate(sent);
    if (!ref.mounted || epoch != _epoch) return result;

    switch (result) {
      case Err<CartValidation>(:final failure):
        state = state.copyWith(revalidating: false, validationFailure: failure);
      case Ok<CartValidation>(:final value):
        // Se aplica al carrito actual (pudo cambiar durante la espera).
        final reconciled = reconcileCart(
          cart: state.cart,
          validation: value,
          pending: state.changes,
        );
        state = state.copyWith(
          lines: reconciled.cart.lines,
          validation: value,
          validatedFor: {
            for (final line in sent.lines) line.productId: line.quantity,
          },
          changes: reconciled.changes,
          revalidating: false,
          clearFailure: true,
        );
        await _persist(reconciled.cart);
    }
    return result;
  }

  /// Si el servidor había dicho "no se puede pagar" y el usuario quitó líneas,
  /// el motivo pudo desaparecer: se vuelve a preguntar (AC-050-4).
  void _refreshAfterRemoval() {
    final validation = state.validation;
    if (validation != null && !validation.checkoutAllowed && !state.isEmpty) {
      unawaited(revalidate());
    }
  }

  void _apply(Cart cart) {
    final ids = {for (final line in cart.lines) line.productId};
    state = state.copyWith(
      lines: cart.lines,
      changes: {
        for (final entry in state.changes.entries)
          if (ids.contains(entry.key)) entry.key: entry.value,
      },
    );
  }
}

/// Código estable (`Validation.code`) de un rechazo al añadir, para que quien
/// llama muestre el texto adecuado.
String cartRejectionCode(CartRejection reason) => switch (reason) {
  CartRejection.invalidProduct => 'cart_invalid_product',
  CartRejection.invalidQuantity => 'cart_invalid_quantity',
  CartRejection.lineLimit => 'cart_line_limit',
  CartRejection.notPurchasable => 'cart_not_purchasable',
};
