import 'dart:math' as math;

import 'package:ipr_mobile/features/technical_tools/domain/entities/btu_models.dart';

/// Reglas locales y puras de la calculadora BTU (RF-085..089; COD §6).
///
/// Sigue condicionada a la validación oficial de Ingeniería IPR (**D-08**):
/// la pantalla que la expone permanece detrás de `btuCalculatorEnabled` (`false`
/// por defecto).
abstract final class BtuCalculator {
  static const double minLengthMeters = 1;
  static const double maxLengthMeters = 15;
  static const double minWidthMeters = 1;
  static const double maxWidthMeters = 15;
  static const double minHeightMeters = 2;
  static const double maxHeightMeters = 4;
  static const int minOccupants = 1;
  static const int maxOccupants = 10;
  static const int minEquipment = 0;
  static const int maxEquipment = 10;

  static const double baseBtuPerSqm = 600;
  static const double baseHeightMeters = 2.5;
  static const double heightStepMeters = 0.5;
  static const double heightSurchargePerStep = 0.10;
  static const int includedOccupants = 2;
  static const double occupantBtu = 600;
  static const double equipmentBtu = 600;

  /// Capacidades comerciales ordenadas de menor a mayor (RF-086, RF-089).
  static const List<int> commercialCapacities = [
    9000,
    12000,
    18000,
    24000,
    36000,
  ];

  static final RegExp _decimalPattern = RegExp(r'^[+-]?\d+(?:[.,]\d+)?$');
  static final RegExp _integerPattern = RegExp(r'^[+-]?\d+$');

  /// Parsea un decimal admitiendo coma o punto de manera idéntica (AC-085-5).
  static double? parseDecimal(String raw) {
    final trimmed = raw.trim();
    if (!_decimalPattern.hasMatch(trimmed)) return null;
    final normalized = trimmed.replaceAll(',', '.');
    final value = double.tryParse(normalized);
    if (value == null || !value.isFinite) return null;
    return value;
  }

  /// Parsea un entero estricto: rechaza decimales como `2.5` o `2,5` (AC-085-4).
  static int? parseStrictInt(String raw) {
    final trimmed = raw.trim();
    if (!_integerPattern.hasMatch(trimmed)) return null;
    return int.tryParse(trimmed);
  }

  /// Valida las cadenas ingresadas en los cinco campos numéricos (AC-085-2..4).
  static BtuValidationResult validateFields({
    required String lengthText,
    required String widthText,
    required String heightText,
    required String occupantsText,
    required String equipmentText,
    required ClimateZone climate,
  }) {
    final errors = <BtuInputField, BtuFieldError>{};

    final length = _validateDoubleField(
      lengthText,
      field: BtuInputField.length,
      min: minLengthMeters,
      max: maxLengthMeters,
      errors: errors,
    );
    final width = _validateDoubleField(
      widthText,
      field: BtuInputField.width,
      min: minWidthMeters,
      max: maxWidthMeters,
      errors: errors,
    );
    final height = _validateDoubleField(
      heightText,
      field: BtuInputField.height,
      min: minHeightMeters,
      max: maxHeightMeters,
      errors: errors,
    );
    final occupants = _validateIntField(
      occupantsText,
      field: BtuInputField.occupants,
      min: minOccupants,
      max: maxOccupants,
      errors: errors,
    );
    final equipment = _validateIntField(
      equipmentText,
      field: BtuInputField.equipment,
      min: minEquipment,
      max: maxEquipment,
      errors: errors,
    );

    if (errors.isNotEmpty ||
        length == null ||
        width == null ||
        height == null ||
        occupants == null ||
        equipment == null) {
      return BtuValidationResult.invalid(Map.unmodifiable(errors));
    }

    return BtuValidationResult.valid(
      BtuInput(
        lengthMeters: length,
        widthMeters: width,
        heightMeters: height,
        occupants: occupants,
        equipmentCount: equipment,
        climate: climate,
      ),
    );
  }

  static double? _validateDoubleField(
    String raw, {
    required BtuInputField field,
    required double min,
    required double max,
    required Map<BtuInputField, BtuFieldError> errors,
  }) {
    final parsed = parseDecimal(raw);
    if (parsed == null) {
      errors[field] = BtuFieldError.emptyOrInvalid;
      return null;
    }
    if (parsed < min || parsed > max) {
      errors[field] = BtuFieldError.outOfRange;
      return null;
    }
    return parsed;
  }

  static int? _validateIntField(
    String raw, {
    required BtuInputField field,
    required int min,
    required int max,
    required Map<BtuInputField, BtuFieldError> errors,
  }) {
    final trimmed = raw.trim();
    final intValue = parseStrictInt(trimmed);
    if (intValue == null) {
      // Si es un decimal válido sintácticamente (ej. "2,5"), distinguir el motivo.
      errors[field] = parseDecimal(trimmed) != null
          ? BtuFieldError.notInteger
          : BtuFieldError.emptyOrInvalid;
      return null;
    }
    if (intValue < min || intValue > max) {
      errors[field] = BtuFieldError.outOfRange;
      return null;
    }
    return intValue;
  }

  /// Calcula el requerimiento térmico y la capacidad comercial sugerida (COD §6).
  static BtuResult calculate(BtuInput input) {
    final area = input.lengthMeters * input.widthMeters;
    var required = area * baseBtuPerSqm;

    if (input.heightMeters > baseHeightMeters) {
      final extraSteps =
          ((input.heightMeters - baseHeightMeters) / heightStepMeters).ceil();
      required *= 1 + extraSteps * heightSurchargePerStep;
    }

    final extraOccupants = math.max(0, input.occupants - includedOccupants);
    required += extraOccupants * occupantBtu;
    required *= input.climate.factor;
    required += input.equipmentCount * equipmentBtu;

    final requiredBtu = required.round();
    final suggested = suggestCapacity(requiredBtu);
    final slug = suggested == null ? null : catalogFilterSlugFor(suggested);
    return BtuResult(
      requiredBtu: requiredBtu,
      suggestedCapacity: suggested,
      filterSlug: slug,
    );
  }

  /// Menor capacidad comercial >= [requiredBtu], o `null` si supera 36.000 BTU.
  static int? suggestCapacity(int requiredBtu) {
    for (final capacity in commercialCapacities) {
      if (capacity >= requiredBtu) return capacity;
    }
    return null;
  }

  /// Slug del atributo `attr[pa_capacidad-btu]` para [capacityBtu] (RF-089).
  static String? catalogFilterSlugFor(int capacityBtu) {
    if (!commercialCapacities.contains(capacityBtu)) return null;
    final thousands = capacityBtu ~/ 1000;
    return '$thousands-000-btu';
  }

  /// Da formato con separador de miles (ej. `21555` → `21.555`).
  static String formatThousands(int value) {
    final negative = value < 0;
    final digits = value.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(digits[i]);
    }
    return negative ? '-$buffer' : buffer.toString();
  }
}
