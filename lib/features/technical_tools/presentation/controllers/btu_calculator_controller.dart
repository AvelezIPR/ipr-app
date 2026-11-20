import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ipr_mobile/features/technical_tools/domain/entities/btu_models.dart';
import 'package:ipr_mobile/features/technical_tools/domain/rules/btu_calculator.dart';
import 'package:meta/meta.dart';

/// Estado del formulario y resultado de la calculadora BTU.
@immutable
final class BtuCalculatorState {
  const new({
    this.lengthText = '',
    this.widthText = '',
    this.heightText = '',
    this.occupantsText = '',
    this.equipmentText = '',
    this.climate = ClimateZone.temperate,
    this.errors = const {},
    this.result,
  });

  final String lengthText;
  final String widthText;
  final String heightText;
  final String occupantsText;
  final String equipmentText;

  /// Valor inicial definido para clima (AC-085-6: Templado).
  final ClimateZone climate;
  final Map<BtuInputField, BtuFieldError> errors;
  final BtuResult? result;

  BtuCalculatorState copyWith({
    String? lengthText,
    String? widthText,
    String? heightText,
    String? occupantsText,
    String? equipmentText,
    ClimateZone? climate,
    Map<BtuInputField, BtuFieldError>? errors,
    BtuResult? result,
    bool clearResult = false,
  }) => BtuCalculatorState(
    lengthText: lengthText ?? this.lengthText,
    widthText: widthText ?? this.widthText,
    heightText: heightText ?? this.heightText,
    occupantsText: occupantsText ?? this.occupantsText,
    equipmentText: equipmentText ?? this.equipmentText,
    climate: climate ?? this.climate,
    errors: errors ?? this.errors,
    result: clearResult ? null : (result ?? this.result),
  );
}

final NotifierProvider<BtuCalculatorController, BtuCalculatorState>
btuCalculatorProvider =
    NotifierProvider.autoDispose<BtuCalculatorController, BtuCalculatorState>(
      BtuCalculatorController.new,
    );

/// Controlador local de la calculadora BTU (RF-085..089): sin sesión ni red.
class BtuCalculatorController extends Notifier<BtuCalculatorState> {
  @override
  BtuCalculatorState build() => const BtuCalculatorState();

  void setLength(String value) => state = state.copyWith(
    lengthText: value,
    errors: _withoutError(BtuInputField.length),
  );

  void setWidth(String value) => state = state.copyWith(
    widthText: value,
    errors: _withoutError(BtuInputField.width),
  );

  void setHeight(String value) => state = state.copyWith(
    heightText: value,
    errors: _withoutError(BtuInputField.height),
  );

  void setOccupants(String value) => state = state.copyWith(
    occupantsText: value,
    errors: _withoutError(BtuInputField.occupants),
  );

  void setEquipment(String value) => state = state.copyWith(
    equipmentText: value,
    errors: _withoutError(BtuInputField.equipment),
  );

  void setClimate(ClimateZone climate) =>
      state = state.copyWith(climate: climate);

  /// Valida entradas y, si son válidas, calcula requerimiento y sugerencia.
  BtuResult? calculate() {
    final validation = BtuCalculator.validateFields(
      lengthText: state.lengthText,
      widthText: state.widthText,
      heightText: state.heightText,
      occupantsText: state.occupantsText,
      equipmentText: state.equipmentText,
      climate: state.climate,
    );
    if (!validation.isValid) {
      state = state.copyWith(errors: validation.errors, clearResult: true);
      return null;
    }
    final computed = BtuCalculator.calculate(validation.input!);
    state = state.copyWith(errors: const {}, result: computed);
    return computed;
  }

  Map<BtuInputField, BtuFieldError> _withoutError(BtuInputField field) {
    if (!state.errors.containsKey(field)) return state.errors;
    return Map.unmodifiable({...state.errors}..remove(field));
  }
}
