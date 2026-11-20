import 'package:ipr_mobile/features/cart/domain/entities/cart.dart';
import 'package:ipr_mobile/features/cart/domain/entities/cart_line.dart';
import 'package:ipr_mobile/features/cart/domain/entities/cart_validation.dart';
import 'package:ipr_mobile/shared/domain/image_ref.dart';
import 'package:ipr_mobile/shared/domain/money.dart';
import 'package:ipr_mobile/shared/domain/price_status.dart';
import 'package:ipr_mobile/shared/domain/stock_status.dart';
import 'package:meta/meta.dart';

/// Decisión pendiente aislada en un solo punto: ¿el usuario debe aceptar
/// explícitamente un cambio de precio antes de pagar? (AC-050-2 / TC-045
/// [A VALIDAR — propuesta de PA nueva]). Se asume que **sí** (falla cerrado):
/// el precio que ve es el que el servidor acaba de dar.
abstract final class CartChangePolicy {
  static const requireAcknowledgementOfPriceChange = true;
}

/// Qué cambió en una línea entre lo último que el usuario vio (instantánea) y
/// lo que dice el servidor ahora (RF-050, AC-050-2). Transitorio: no se
/// guarda en disco.
@immutable
final class CartLineChange {
  const new({
    required this.productId,
    this.previousPrice,
    this.currentPrice,
    this.previousAvailability,
    this.currentAvailability,
  });

  final int productId;
  final PriceStatus? previousPrice;
  final PriceStatus? currentPrice;
  final StockStatus? previousAvailability;
  final StockStatus? currentAvailability;

  bool get priceChanged =>
      previousPrice != null &&
      currentPrice != null &&
      previousPrice != currentPrice;

  bool get availabilityChanged =>
      previousAvailability != null &&
      currentAvailability != null &&
      previousAvailability != currentAvailability;

  bool get hasChange => priceChanged || availabilityChanged;

  /// El usuario debe aceptarlo antes de poder pagar.
  bool get requiresAcknowledgement =>
      CartChangePolicy.requireAcknowledgementOfPriceChange && priceChanged;

  @override
  bool operator ==(Object other) =>
      other is CartLineChange &&
      other.productId == productId &&
      other.previousPrice == previousPrice &&
      other.currentPrice == currentPrice &&
      other.previousAvailability == previousAvailability &&
      other.currentAvailability == currentAvailability;

  @override
  int get hashCode => Object.hash(
    productId,
    previousPrice,
    currentPrice,
    previousAvailability,
    currentAvailability,
  );
}

/// Subtotal **informativo** (precio público IVA incluido, RF-051).
///
/// Nunca incluye envío, descuentos ni impuestos calculados en el cliente, no
/// se envía al servidor y no es un total a pagar (IR-01, AC-051-4).
@immutable
final class CartSubtotal {
  const new({
    required this.amount,
    required this.verified,
    required this.excludedLines,
  });

  final Money amount;

  /// Los precios provienen de una revalidación del servidor y no hay un fallo
  /// posterior; `false` = datos guardados sin verificar.
  final bool verified;

  /// Líneas que no suman: sin precio o no disponibles (AC-051-3).
  final int excludedLines;
}

/// Una línea del carrito junto con lo que se sabe de ella para pintarla.
@immutable
final class CartLineView {
  const new({required this.line, this.validated, this.change});

  final CartLine line;

  /// Lo que dijo el servidor en la última revalidación exitosa, si esa
  /// respuesta incluyó esta línea.
  final ValidatedCartLine? validated;
  final CartLineChange? change;

  int get productId => line.productId;
  int get quantity => line.quantity;

  /// Datos de presentación: lo del servidor si se tiene; si no, la
  /// instantánea guardada.
  String? get name => validated?.product?.name ?? line.snapshot?.name;
  String? get sku => validated?.product?.sku ?? line.snapshot?.sku;
  String? get brandName =>
      validated?.product?.brandName ?? line.snapshot?.brandName;
  ImageRef? get image => validated?.product?.image ?? line.snapshot?.image;

  /// Precio unitario. Con revalidación es **el del servidor** (`null` si el
  /// producto ya no existe); sin ella, el guardado, solo informativo.
  PriceStatus? get unitPrice =>
      validated != null ? validated!.product?.price : line.snapshot?.price;

  StockStatus? get availability => validated != null
      ? validated!.product?.availability
      : line.snapshot?.availability;

  CartLineStatus? get status => validated?.status;

  /// Se sabe que no se puede comprar (agotado, bajo pedido, sin precio o ya
  /// no existe).
  bool get isBlocking => validated?.isBlocking ?? false;

  /// El servidor ya revisó esta línea.
  bool get isVerified => validated != null;

  /// Suma al subtotal: tiene precio con valor y no está bloqueada.
  bool get contributesToSubtotal => unitPrice is Priced && !isBlocking;

  Money? get lineSubtotal {
    final price = unitPrice;
    if (price is! Priced || isBlocking) return null;
    return price.amount * quantity;
  }

  bool get hasPendingChange => change?.hasChange ?? false;
}

/// Vista consolidada del carrito para la pantalla y para la puerta de pago.
@immutable
final class CartOverview {
  const new({
    required this.lines,
    required this.subtotal,
    required this.pendingAcknowledgements,
  });

  /// Combina el carrito local con la última validación del servidor.
  ///
  /// * [validatedFor]: `id → cantidad` que se envió en esa validación.
  /// * [validationFailed]: el último intento falló (red, 5xx...): se conservan
  ///   los datos anteriores pero ya no cuentan como verificados.
  factory build({
    required Cart cart,
    CartValidation? validation,
    Map<int, int>? validatedFor,
    bool validationFailed = false,
    Map<int, CartLineChange> changes = const {},
  }) {
    final views = [
      for (final line in cart.lines)
        CartLineView(
          line: line,
          validated: validation?.lineFor(line.productId),
          change: changes[line.productId],
        ),
    ];

    final excluded = views.where((v) => !v.contributesToSubtotal).length;
    final exactMatch =
        validation != null &&
        validatedFor != null &&
        validatedFor.length == cart.lineCount &&
        cart.lines.every((l) => validatedFor[l.productId] == l.quantity);

    final CartSubtotal subtotal;
    if (exactMatch) {
      // El carrito es el que se validó: manda el subtotal del servidor.
      subtotal = CartSubtotal(
        amount: validation.informativeSubtotal,
        verified: !validationFailed,
        excludedLines: excluded,
      );
    } else {
      var sum = Money.zero;
      for (final view in views) {
        final part = view.lineSubtotal;
        if (part != null) sum = sum + part;
      }
      subtotal = CartSubtotal(
        amount: sum,
        verified:
            validation != null &&
            !validationFailed &&
            views.every((v) => v.isVerified),
        excludedLines: excluded,
      );
    }

    return CartOverview(
      lines: views,
      subtotal: subtotal,
      pendingAcknowledgements: [
        for (final view in views)
          if (view.change?.requiresAcknowledgement ?? false) view.productId,
      ],
    );
  }

  final List<CartLineView> lines;
  final CartSubtotal subtotal;

  /// Líneas con un cambio de precio por aceptar (RF-050).
  final List<int> pendingAcknowledgements;

  /// Líneas que impiden pagar (agotadas, bajo pedido, sin precio, inexistentes).
  List<CartLineView> get blockingLines => [
    for (final view in lines)
      if (view.isBlocking) view,
  ];

  /// Líneas con algún cambio informado (precio o disponibilidad).
  List<CartLineView> get changedLines => [
    for (final view in lines)
      if (view.hasPendingChange) view,
  ];

  bool get hasBlockingLines => lines.any((v) => v.isBlocking);
}
