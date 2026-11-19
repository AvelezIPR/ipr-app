import 'package:meta/meta.dart';

/// Tipo de una dimensión de filtro (`openapi.yaml` → `FilterDimension.type`).
enum FilterDimensionType { multi, boolean }

@immutable
final class FilterOption {
  const new({required this.value, required this.label});

  final String value;
  final String label;

  @override
  bool operator ==(Object other) =>
      other is FilterOption && other.value == value && other.label == label;

  @override
  int get hashCode => Object.hash(value, label);
}

/// Dimensión de filtro entregada por `listFilters`. La app **nunca** inventa
/// dimensiones ni opciones (AC-014-4): solo muestra estas.
@immutable
final class FilterDimension {
  const new({
    required this.key,
    required this.label,
    required this.type,
    required this.options,
  });

  /// Nombre del parámetro de `/products` (`brand`, `tag`, `onSale` o
  /// `attr[pa_…]`).
  final String key;
  final String label;
  final FilterDimensionType type;
  final List<FilterOption> options;

  @override
  bool operator ==(Object other) =>
      other is FilterDimension &&
      other.key == key &&
      other.label == label &&
      other.type == type &&
      _sameOptions(other.options);

  bool _sameOptions(List<FilterOption> other) {
    if (other.length != options.length) return false;
    for (var i = 0; i < other.length; i++) {
      if (other[i] != options[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(key, label, type, options.length);
}

/// Claves de dimensión que `GET /products` acepta (contrato `listProducts`).
/// Cualquier otra se descarta: no se puede enviar un parámetro desconocido.
abstract final class FilterKeys {
  static const brand = 'brand';
  static const tag = 'tag';
  static const onSale = 'onSale';

  static final _attr = RegExp(r'^attr\[pa_[a-z0-9_-]{1,60}\]$');

  static bool isSupported(String key) =>
      key == brand || key == tag || key == onSale || _attr.hasMatch(key);

  static bool isAttribute(String key) => _attr.hasMatch(key);

  /// Máximos del contrato: 5 marcas, 5 etiquetas, 5 atributos.
  static const maxValuesPerKey = 5;
  static const maxAttributes = 5;
}
