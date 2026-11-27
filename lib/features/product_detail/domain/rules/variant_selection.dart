import 'package:ipr_mobile/features/product_detail/domain/entities/product_variant.dart';
import 'package:ipr_mobile/shared/domain/money.dart';
import 'package:ipr_mobile/shared/domain/price_status.dart';
import 'package:meta/meta.dart';

/// Elección de opciones de un producto variable (W1-01), con las mismas
/// reglas que la ficha de la web (`VariantProvider.tsx`):
///
/// * Si existe exactamente 1 variación total o exactamente 1 variación con
///   precio, se preselecciona automáticamente.
/// * Sin elegir todos los ejes no hay variación: precio "Desde" y botón
///   "Selecciona una opción" desactivado.
/// * Una opción que existe en otra combinación queda **habilitada** y, al
///   tocarla, limpia únicamente los ejes incompatibles. Solo se deshabilita una
///   opción que no existe en ninguna variación.
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

  /// Selección inicial: preselecciona automáticamente cuando existe exactamente
  /// una variación total o exactamente una variación con precio.
  factory initial({
    required List<ProductVariantAxis> axes,
    required List<ProductVariant> variants,
  }) {
    final priced = variants.where((v) => v.price is Priced).toList();
    final ProductVariant? autoTarget;
    if (variants.length == 1) {
      autoTarget = variants.single;
    } else if (priced.length == 1) {
      autoTarget = priced.single;
    } else {
      autoTarget = null;
    }
    if (autoTarget == null) {
      return VariantSelection(axes: axes, variants: variants);
    }
    final chosen = <String, String>{};
    for (final axis in axes) {
      final value = autoTarget.selection[axis.slug];
      if (value != null) {
        chosen[axis.slug] = value;
      } else if (axis.options.length == 1) {
        chosen[axis.slug] = axis.options.single.value;
      }
    }
    return VariantSelection(
      axes: axes,
      variants: variants,
      chosen: Map.unmodifiable(chosen),
    );
  }

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

  /// ¿Existe al menos una variación con [value] en [axisSlug] (incluyendo
  /// variaciones donde ese eje sea comodín)?
  bool hasAnyVariantFor(String axisSlug, String value) => variants.any((v) {
    final own = v.selection[axisSlug];
    return own == null || own == value;
  });

  /// ¿Existe alguna variación con [value] en [axisSlug] compatible con lo ya
  /// elegido en los demás ejes?
  bool isOptionAvailable(String axisSlug, String value) {
    final choice = {...chosen}
      ..remove(axisSlug)
      ..[axisSlug] = value;
    return variants.any((candidate) => _matches(candidate, choice));
  }

  /// Elige [value] en [axisSlug]; si ya estaba elegida la quita. Si [value]
  /// no es compatible con lo ya elegido pero existe en otra variación, conserva
  /// únicamente los ejes compatibles y limpia los incompatibles; si no existe
  /// en ninguna variación no cambia nada.
  VariantSelection toggle(String axisSlug, String value) {
    if (chosen[axisSlug] == value) {
      return VariantSelection(
        axes: axes,
        variants: variants,
        chosen: {...chosen}..remove(axisSlug),
      );
    }
    if (isOptionAvailable(axisSlug, value)) {
      return VariantSelection(
        axes: axes,
        variants: variants,
        chosen: {...chosen, axisSlug: value},
      );
    }
    if (!hasAnyVariantFor(axisSlug, value)) return this;
    final nextChosen = <String, String>{axisSlug: value};
    for (final entry in chosen.entries) {
      if (entry.key == axisSlug) continue;
      final candidate = {...nextChosen, entry.key: entry.value};
      if (variants.any((v) => _matches(v, candidate))) {
        nextChosen[entry.key] = entry.value;
      }
    }
    return VariantSelection(axes: axes, variants: variants, chosen: nextChosen);
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
