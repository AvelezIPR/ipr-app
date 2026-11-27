import 'package:ipr_mobile/features/product_detail/domain/entities/product_variant.dart';
import 'package:ipr_mobile/shared/domain/money.dart';
import 'package:ipr_mobile/shared/domain/price_status.dart';
import 'package:meta/meta.dart';

/// Elección de opciones de un producto variable (W1-01), con las mismas
/// reglas que la ficha de la web:
///
/// * Sin elegir todos los ejes no hay variación: precio "Desde" y botón
///   "Selecciona una opción" desactivado.
/// * Una opción que no existe combinada con lo ya elegido queda
///   **deshabilitada** (p. ej. 440 V + 3/4" si esa variación no existe).
/// * Tocar la opción ya elegida la **quita**.
/// * Una variación con un eje vacío vale para cualquier opción de ese eje.
///
/// Inmutable: cada cambio devuelve una selección nueva.
@immutable
final class VariantSelection {
  const new({
    required this.axes,
    required this.variants,
    this.chosen = const {},
  });

  final List<ProductVariantAxis> axes;
  final List<ProductVariant> variants;

  /// Opción elegida por eje (eje → valor).
  final Map<String, String> chosen;

  /// ¿Se eligió una opción en cada eje?
  bool get isComplete =>
      axes.isNotEmpty && axes.every((axis) => chosen.containsKey(axis.slug));

  /// La variación que corresponde a lo elegido, o `null` si falta elegir o no
  /// existe. Si varias valen (por ejes "cualquiera"), gana la más específica.
  ProductVariant? get variant {
    if (!isComplete) return null;
    ProductVariant? best;
    var bestScore = -1;
    for (final candidate in variants) {
      if (!_matches(candidate, chosen)) continue;
      final score = chosen.entries
          .where((e) => candidate.selection[e.key] == e.value)
          .length;
      if (score > bestScore) {
        best = candidate;
        bestScore = score;
      }
    }
    return best;
  }

  /// Etiqueta legible de una variación ("1 galón", "220 V / 3/4″"): las
  /// etiquetas de sus opciones en el orden de los ejes.
  String labelOf(ProductVariant variant) {
    final parts = <String>[];
    for (final axis in axes) {
      final value = variant.selection[axis.slug];
      if (value != null) parts.add(axis.labelOf(value));
    }
    return parts.join(' / ');
  }

  /// ¿Existe alguna variación con [value] en [axisSlug] compatible con lo ya
  /// elegido en los demás ejes?
  bool isOptionAvailable(String axisSlug, String value) {
    final choice = {...chosen}
      ..remove(axisSlug)
      ..[axisSlug] = value;
    return variants.any((candidate) => _matches(candidate, choice));
  }

  /// Elige [value] en [axisSlug]; si ya estaba elegida la quita; si la opción
  /// no está disponible no cambia nada.
  VariantSelection toggle(String axisSlug, String value) {
    if (chosen[axisSlug] == value) {
      return VariantSelection(
        axes: axes,
        variants: variants,
        chosen: {...chosen}..remove(axisSlug),
      );
    }
    if (!isOptionAvailable(axisSlug, value)) return this;
    return VariantSelection(
      axes: axes,
      variants: variants,
      chosen: {...chosen, axisSlug: value},
    );
  }

  /// Precio mínimo entre las variaciones con precio ("Desde $X"), o `null` si
  /// ninguna lo tiene (nunca se muestra "$0").
  Money? get fromPrice {
    Money? lowest;
    for (final candidate in variants) {
      final price = candidate.price;
      if (price is! Priced) continue;
      if (lowest == null || price.amount.compareTo(lowest) < 0) {
        lowest = price.amount;
      }
    }
    return lowest;
  }

  static bool _matches(ProductVariant candidate, Map<String, String> choice) {
    for (final entry in choice.entries) {
      final own = candidate.selection[entry.key];
      if (own != null && own != entry.value) return false;
    }
    return true;
  }
}
