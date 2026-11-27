import 'package:meta/meta.dart';

/// Rango de cantidad que se puede comprar por línea (W1-06): el que define
/// WordPress por producto o variación (`ipr_disponibilidad`, plugin de
/// cantidades de WooCommerce). Sin dato vale el rango general, 1 a 99
/// (`CartItem` del contrato).
///
/// Es información de **presentación**: el servidor revalida siempre y el
/// checkout de WooCommerce tiene la última palabra (P1).
@immutable
final class QuantityRange {
  const new({this.min = absoluteMin, this.max = absoluteMax});

  /// Lectura tolerante de `minQuantity` / `maxQuantity`: valores que no son
  /// enteros de 1 a 99 se ignoran, y un rango incoherente (máximo menor que
  /// el mínimo) se descarta entero y vuelve al general.
  factory fromContract({Object? min, Object? max}) {
    final lo = _limit(min) ?? absoluteMin;
    final hi = _limit(max) ?? absoluteMax;
    return hi < lo ? standard : QuantityRange(min: lo, max: hi);
  }

  /// Techo por línea (paridad con el esquema del checkout).
  static const absoluteMax = 99;
  static const absoluteMin = 1;

  /// Rango general, sin límites propios del producto.
  static const standard = QuantityRange();

  final int min;
  final int max;

  /// ¿Es el rango general (sin límites propios)?
  bool get isStandard => min == absoluteMin && max == absoluteMax;

  /// Lleva [value] al rango.
  int clamp(int value) => value < min ? min : (value > max ? max : value);

  /// ¿Ya no se puede subir más?
  bool isAtMax(int value) => value >= max;

  static int? _limit(Object? raw) {
    final value = raw is int
        ? raw
        : (raw is double && raw == raw.truncateToDouble() ? raw.toInt() : null);
    if (value == null || value < absoluteMin || value > absoluteMax) {
      return null;
    }
    return value;
  }

  @override
  bool operator ==(Object other) =>
      other is QuantityRange && other.min == min && other.max == max;

  @override
  int get hashCode => Object.hash(min, max);

  @override
  String toString() => 'QuantityRange($min..$max)';
}
