import 'package:ipr_mobile/shared/domain/money.dart';
import 'package:ipr_mobile/shared/domain/price_status.dart';
import 'package:ipr_mobile/shared/domain/product_summary.dart';
import 'package:meta/meta.dart';

/// Estado de una línea según el servidor (`CartValidation.lines[].status`).
enum CartLineStatus {
  available,
  outOfStock,

  /// "Bajo pedido": NO comprable en el MVP (CR-017, PA-12 pendiente).
  onBackorder,

  /// Sin precio (precio 0 o vacío): "Más información", nunca "$0" (IR-02).
  priceOnRequest,

  /// Despublicado o inexistente: se trata como no disponible y la línea no se
  /// borra sola (AC-050-6).
  notFound;

  /// Lectura tolerante. Un valor que esta versión no conoce se trata como
  /// [notFound]: bloquea el pago (falla cerrado) y el usuario puede quitar la
  /// línea. `null` también.
  static CartLineStatus fromContract(String? value) => switch (value) {
    'available' => CartLineStatus.available,
    'out_of_stock' => CartLineStatus.outOfStock,
    'on_backorder' => CartLineStatus.onBackorder,
    'price_on_request' => CartLineStatus.priceOnRequest,
    _ => CartLineStatus.notFound,
  };
}

/// Una línea ya revalidada por el servidor.
@immutable
final class ValidatedCartLine {
  const new({
    required this.id,
    required this.quantity,
    required this.status,
    this.product,
    this.lineSubtotal,
  });

  /// Id del producto (`id` del contrato).
  final int id;
  final int quantity;
  final CartLineStatus status;

  /// Datos vigentes del producto; `null` si ya no existe (`not_found`).
  final ProductSummary? product;

  /// Subtotal informativo de la línea según el servidor; `null` sin precio.
  final Money? lineSubtotal;

  /// Precio unitario vigente: el del servidor, nunca el guardado en el
  /// dispositivo (AC-050-8). Sin producto o sin precio → [OnRequest].
  PriceStatus get unitPrice => product?.price ?? const OnRequest();

  /// Se puede comprar: el servidor la da por `available` **y** el producto
  /// trae precio con valor y "en stock" (IR-02, CR-017; defensa en
  /// profundidad).
  bool get isPurchasable =>
      status == CartLineStatus.available && (product?.canAddToCart ?? false);

  /// Impide pagar hasta que el usuario la quite o la ajuste (RF-050).
  bool get isBlocking => !isPurchasable;
}

/// Respuesta de `POST /cart/validate`.
@immutable
final class CartValidation {
  const new({
    required this.checkoutAllowed,
    required this.lines,
    required this.informativeSubtotal,
  });

  /// El servidor manda: si es `false` no se paga (RF-050).
  final bool checkoutAllowed;
  final List<ValidatedCartLine> lines;

  /// Subtotal informativo, precio público IVA incluido. **No** es un total a
  /// cobrar y nunca se envía al servidor (IR-01, AC-051-4).
  final Money informativeSubtotal;

  ValidatedCartLine? lineFor(int productId) {
    for (final line in lines) {
      if (line.id == productId) return line;
    }
    return null;
  }
}
