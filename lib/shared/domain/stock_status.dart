import 'package:ipr_mobile/shared/domain/price_status.dart';

/// Disponibilidad genérica; nunca cantidades exactas (WCA §4.1).
enum StockStatus {
  inStock,
  outOfStock,

  /// "Bajo pedido": NO comprable en el MVP (CR-017, PA-12 pendiente).
  onBackorder,

  /// Valor desconocido enviado por una versión futura del servidor.
  unknown;

  /// Lectura tolerante: lo que no se reconoce es [unknown].
  static StockStatus fromContract(String? value) => switch (value) {
    'in_stock' => StockStatus.inStock,
    'out_of_stock' => StockStatus.outOfStock,
    'on_backorder' => StockStatus.onBackorder,
    _ => StockStatus.unknown,
  };
}

/// Regla de elegibilidad de compra: solo "en stock" con precio. `onBackorder`
/// y `unknown` no son comprables (CR-017). El servidor revalida de todos
/// modos (P1).
bool canAddToCart({required PriceStatus price, required StockStatus stock}) =>
    price.hasPrice && stock == StockStatus.inStock;
