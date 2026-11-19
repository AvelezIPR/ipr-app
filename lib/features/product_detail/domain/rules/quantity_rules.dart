import 'package:meta/meta.dart';

/// Resultado de interpretar una cantidad escrita a mano.
@immutable
final class QuantityInput {
  const new({required this.value, required this.corrected});

  /// Cantidad válida resultante (siempre dentro del rango).
  final int value;

  /// `true` si lo escrito no era válido o estaba fuera de rango y se corrigió
  /// (se muestra el mensaje de rango, AC-029-3).
  final bool corrected;

  @override
  bool operator ==(Object other) =>
      other is QuantityInput &&
      other.value == value &&
      other.corrected == corrected;

  @override
  int get hashCode => Object.hash(value, corrected);
}

/// Reglas del selector de cantidad (RF-029, AC-029-2/-3): de 1 a 99. El
/// contrato no entrega existencias, así que el máximo es 99 salvo que quien
/// llama conozca otro tope.
abstract final class QuantityRules {
  static const min = 1;
  static const max = 99;

  /// Lleva [value] al rango `[min, maxQuantity]`.
  static int clamp(int value, {int maxQuantity = max}) {
    final upper = maxQuantity < min
        ? min
        : (maxQuantity > max ? max : maxQuantity);
    if (value < min) return min;
    if (value > upper) return upper;
    return value;
  }

  /// Interpreta texto escrito por el usuario. Solo dígitos enteros: `abc`,
  /// `1.5`, vacío o negativos se corrigen a [min]; `0` → [min]; `100` → tope.
  static QuantityInput parse(String raw, {int maxQuantity = max}) {
    final text = raw.trim();
    if (RegExp(r'^[0-9]{7,}$').hasMatch(text)) {
      // Un número gigantesco se lleva al tope, no a 1.
      return QuantityInput(
        value: clamp(max, maxQuantity: maxQuantity),
        corrected: true,
      );
    }
    final parsed = RegExp(r'^[0-9]{1,6}$').hasMatch(text)
        ? int.tryParse(text)
        : null;
    if (parsed == null) return const QuantityInput(value: min, corrected: true);
    final value = clamp(parsed, maxQuantity: maxQuantity);
    return QuantityInput(value: value, corrected: value != parsed);
  }
}
