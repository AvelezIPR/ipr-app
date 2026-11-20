import 'package:meta/meta.dart';

/// Zonas climáticas contempladas por la fórmula de cálculo (COD §6, D-08).
enum ClimateZone {
  cold(factor: 1),
  temperate(factor: 1.05),
  warm(factor: 1.15);

  new({required this.factor});

  final double factor;
}

/// Campos de entrada de la calculadora BTU.
enum BtuInputField { length, width, height, occupants, equipment }

/// Motivo de rechazo al validar un campo de la calculadora BTU.
enum BtuFieldError { emptyOrInvalid, outOfRange, notInteger }

/// Entradas validadas de la calculadora BTU (RF-085).
@immutable
final class BtuInput {
  const new({
    required this.lengthMeters,
    required this.widthMeters,
    required this.heightMeters,
    required this.occupants,
    required this.equipmentCount,
    required this.climate,
  });

  final double lengthMeters;
  final double widthMeters;
  final double heightMeters;
  final int occupants;
  final int equipmentCount;
  final ClimateZone climate;
}

/// Resultado de validación de los textos ingresados por el usuario.
@immutable
final class BtuValidationResult {
  const new valid(BtuInput this.input) : errors = const {};

  const new invalid(this.errors) : input = null;

  final BtuInput? input;
  final Map<BtuInputField, BtuFieldError> errors;

  bool get isValid => input != null && errors.isEmpty;
}

/// Resultado de la estimación térmica en BTU/h (RF-086..089, D-08).
@immutable
final class BtuResult {
  const new({
    required this.requiredBtu,
    required this.suggestedCapacity,
    required this.filterSlug,
  });

  final int requiredBtu;

  /// Menor capacidad comercial >= [requiredBtu], o `null` si supera 36.000 BTU.
  final int? suggestedCapacity;

  /// Slug del atributo `attr[pa_capacidad-btu]` para filtrar el catálogo
  /// (RF-089), o `null` si supera la capacidad máxima sugerible.
  final String? filterSlug;

  bool get exceedsMaxCapacity => suggestedCapacity == null;

  @override
  bool operator ==(Object other) =>
      other is BtuResult &&
      other.requiredBtu == requiredBtu &&
      other.suggestedCapacity == suggestedCapacity &&
      other.filterSlug == filterSlug;

  @override
  int get hashCode => Object.hash(requiredBtu, suggestedCapacity, filterSlug);
}
