import 'package:ipr_mobile/features/cart/domain/entities/cart_validation.dart';
import 'package:ipr_mobile/shared/domain/image_ref.dart';
import 'package:ipr_mobile/shared/domain/money.dart';
import 'package:ipr_mobile/shared/domain/price_status.dart';
import 'package:ipr_mobile/shared/domain/product_summary.dart';
import 'package:ipr_mobile/shared/domain/stock_status.dart';

/// `POST /cart/validate` → [CartValidation]. Mapeo tolerante:
///
/// * Estructura irreconocible (sin `data`, sin `lines`, línea sin `id`, sin
///   `informativeSubtotal` legible) → [FormatException] (el repositorio la
///   convierte en `ContractFailure` y el carrito NO se modifica).
/// * `checkoutAllowed` ausente o no booleano → `false` (falla cerrado).
/// * `status` desconocido → [CartLineStatus.notFound] (bloquea, falla cerrado).
/// * Precio 0, ausente o ilegible → [OnRequest]; nunca "$0" (IR-02).
CartValidation mapCartValidation(Object? body) {
  if (body is! Map<String, dynamic>) {
    throw const FormatException('se esperaba {data: {...}}');
  }
  final data = body['data'];
  if (data is! Map<String, dynamic>) {
    throw const FormatException('falta data');
  }
  final rawLines = data['lines'];
  if (rawLines is! List<Object?>) throw const FormatException('falta lines');

  final subtotal = data['informativeSubtotal'];
  final amount = subtotal is Map<String, dynamic>
      ? Money.tryFromJson(subtotal['amount'])
      : null;
  if (amount == null) {
    throw const FormatException('informativeSubtotal ilegible');
  }

  return CartValidation(
    checkoutAllowed: data['checkoutAllowed'] == true,
    informativeSubtotal: amount,
    lines: [for (final item in rawLines) _line(item)],
  );
}

ValidatedCartLine _line(Object? json) {
  if (json is! Map<String, dynamic>) {
    throw const FormatException('línea ilegible');
  }
  final id = json['id'];
  if (id is! int || id < 1) throw const FormatException('línea sin id');
  final quantity = json['quantity'];
  return ValidatedCartLine(
    id: id,
    quantity: quantity is int ? quantity : 0,
    status: CartLineStatus.fromContract(
      json['status'] is String ? json['status']! as String : null,
    ),
    product: _product(json['product']),
    lineSubtotal: Money.tryFromJson(json['lineSubtotal']),
  );
}

String? _string(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

ProductSummary? _product(Object? json) {
  if (json is! Map<String, dynamic>) return null;
  final id = json['id'];
  final name = _string(json['name']);
  if (id is! int || id < 1 || name == null) return null;

  final price = json['price'];
  final priceMap = price is Map<String, dynamic>
      ? price
      : const <String, Object?>{};
  final brand = json['brand'];
  return ProductSummary(
    id: id,
    slug: _string(json['slug']) ?? '',
    name: name,
    sku: json['sku'] is String ? json['sku']! as String : '',
    brandName: brand is Map<String, dynamic> ? _string(brand['name']) : null,
    brandSlug: brand is Map<String, dynamic> ? _string(brand['slug']) : null,
    price: PriceStatus.fromContract(
      status: priceMap['status'] is String
          ? priceMap['status']! as String
          : null,
      amount: priceMap['amount'],
    ),
    regularPrice: Money.tryFromJson(priceMap['regularAmount']),
    onSale: priceMap['onSale'] == true,
    availability: StockStatus.fromContract(
      json['availability'] is String ? json['availability']! as String : null,
    ),
    image: ImageRef.tryFromJson(json['image']),
  );
}
