import 'package:meta/meta.dart';

/// Referencia mínima de un producto: lo único que el carrito envía al
/// servidor junto con la cantidad (`items: [{id, quantity}]`).
@immutable
final class ProductRef {
  const new({required this.id, required this.slug});

  final int id;
  final String slug;

  static final _slugPattern = RegExp(r'^[a-z0-9][a-z0-9._-]{0,199}$');

  /// Un slug válido según el contrato (`openapi.yaml` → `Slug`).
  static bool isValidSlug(String value) => _slugPattern.hasMatch(value);

  @override
  bool operator ==(Object other) =>
      other is ProductRef && other.id == id && other.slug == slug;

  @override
  int get hashCode => Object.hash(id, slug);

  @override
  String toString() => 'ProductRef($id, $slug)';
}
