import 'package:meta/meta.dart';

/// Importe en pesos colombianos, **entero** y nunca `double` (RF-012,
/// RNF-107). Los importes que ve la app son informativos: el servidor decide
/// el precio final (P1).
@immutable
final class Money implements Comparable<Money> {
  const new(this.pesos);

  /// Interpreta un número JSON. Devuelve `null` si no es entero (p. ej.
  /// `1500.5`) o es negativo: la app nunca inventa ni redondea importes.
  static Money? tryFromJson(Object? value) {
    if (value is int) return value < 0 ? null : Money(value);
    if (value is double) {
      if (value.isNaN || value.isInfinite || value < 0) return null;
      if (value != value.truncateToDouble()) return null;
      return Money(value.toInt());
    }
    return null;
  }

  static const zero = Money(0);

  final int pesos;

  bool get isZero => pesos == 0;

  Money operator +(Money other) => Money(pesos + other.pesos);

  /// Multiplica por una cantidad entera (líneas del carrito, 1–99).
  Money operator *(int quantity) => Money(pesos * quantity);

  @override
  int compareTo(Money other) => pesos.compareTo(other.pesos);

  @override
  bool operator ==(Object other) => other is Money && other.pesos == pesos;

  @override
  int get hashCode => pesos.hashCode;

  @override
  String toString() => 'Money($pesos)';
}
