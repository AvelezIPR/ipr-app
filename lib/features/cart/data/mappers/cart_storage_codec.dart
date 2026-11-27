import 'dart:convert';

import 'package:ipr_mobile/features/cart/domain/entities/cart.dart';
import 'package:ipr_mobile/features/cart/domain/entities/cart_line.dart';
import 'package:ipr_mobile/shared/domain/image_ref.dart';
import 'package:ipr_mobile/shared/domain/money.dart';
import 'package:ipr_mobile/shared/domain/price_status.dart';
import 'package:ipr_mobile/shared/domain/quantity_range.dart';
import 'package:ipr_mobile/shared/domain/stock_status.dart';

/// Formato del carrito en disco: JSON versionado en **una** clave.
///
/// Solo identificadores, cantidades y datos de presentación (nombre, marca,
/// SKU, imagen, precio y disponibilidad mostrados por última vez): sin
/// tokens, sin datos del perfil, sin totales cobrables (AC-049-7, RNF-062).
///
/// ```json
/// {"v":1,"lines":[{"productId":4521,"quantity":2,
///   "snapshot":{"name":"...","sku":"...","brand":"...","imageUrl":"...",
///               "imageAlt":"...","price":1234567,"availability":"in_stock"}}]}
/// ```
abstract final class CartStorageCodec {
  /// Clave única y versionada en el almacén duradero.
  static const storageKey = 'cart.v1';
  static const version = 1;

  static String encode(Cart cart) => jsonEncode({
    'v': version,
    'lines': [for (final line in cart.lines) _encodeLine(line)],
  });

  /// Lectura tolerante: lo que no se entiende se descarta. Un documento
  /// ilegible, de otra versión o con otra forma → carrito vacío. Las líneas
  /// sueltas inválidas se omiten sin afectar a las demás.
  static Cart decode(String? raw) {
    if (raw == null || raw.isEmpty) return Cart.empty;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic> || json['v'] != version) {
        return Cart.empty;
      }
      final lines = json['lines'];
      if (lines is! List<Object?>) return Cart.empty;
      return Cart.sanitize([for (final item in lines) ?_decodeLine(item)]);
    } on Object {
      return Cart.empty;
    }
  }

  static Map<String, Object?> _encodeLine(CartLine line) {
    final snapshot = line.snapshot;
    return {
      'productId': line.productId,
      'quantity': line.quantity,
      if (snapshot != null)
        'snapshot': {
          'name': snapshot.name,
          'sku': snapshot.sku,
          'brand': ?snapshot.brandName,
          'imageUrl': ?snapshot.image?.url,
          'imageAlt': ?snapshot.image?.alt,
          'price': switch (snapshot.price) {
            Priced(:final amount) => amount.pesos,
            OnRequest() => null,
          },
          'availability': _availabilityToJson(snapshot.availability),
          // Solo si el producto tiene límites propios (W1-06).
          if (!snapshot.quantityRange.isStandard) ...{
            'minQuantity': snapshot.quantityRange.min,
            'maxQuantity': snapshot.quantityRange.max,
          },
        },
    };
  }

  static CartLine? _decodeLine(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final id = json['productId'];
    final quantity = json['quantity'];
    if (id is! int || quantity is! int) return null;
    return CartLine(
      productId: id,
      quantity: quantity,
      snapshot: _decodeSnapshot(json['snapshot']),
    );
  }

  static CartLineSnapshot? _decodeSnapshot(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final name = json['name'];
    if (name is! String || name.isEmpty) return null;
    final imageUrl = json['imageUrl'];
    final imageAlt = json['imageAlt'];
    final brand = json['brand'];
    final sku = json['sku'];
    return CartLineSnapshot(
      name: name,
      sku: sku is String ? sku : '',
      brandName: brand is String && brand.isNotEmpty ? brand : null,
      // Precio 0, negativo o ilegible → sin precio; nunca "$0" (IR-02).
      price: PriceStatus.fromContract(
        status: 'priced',
        amount: Money.tryFromJson(json['price'])?.pesos,
      ),
      availability: StockStatus.fromContract(
        json['availability'] is String ? json['availability']! as String : null,
      ),
      image: imageUrl is String && imageUrl.isNotEmpty
          ? ImageRef(url: imageUrl, alt: imageAlt is String ? imageAlt : '')
          : null,
      quantityRange: QuantityRange.fromContract(
        min: json['minQuantity'],
        max: json['maxQuantity'],
      ),
    );
  }

  static String _availabilityToJson(StockStatus status) => switch (status) {
    StockStatus.inStock => 'in_stock',
    StockStatus.outOfStock => 'out_of_stock',
    StockStatus.onBackorder => 'on_backorder',
    StockStatus.unknown => 'unknown',
  };
}
