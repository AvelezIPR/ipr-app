import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/features/technical_tools/domain/entities/btu_models.dart';
import 'package:ipr_mobile/features/technical_tools/domain/rules/btu_calculator.dart';
import 'package:ipr_mobile/features/technical_tools/presentation/controllers/btu_calculator_controller.dart';

void main() {
  group(
    'TC-127 · AC-086 · fórmula T1..T10, monotonía, altura y capacidades',
    () {
      test('TC-127 · AC-086-1 · tabla de referencia T1 a T10 (COD §6)', () {
        final cases =
            <
              ({
                String id,
                BtuInput input,
                int expectedRequired,
                int? expectedSuggested,
              })
            >[
              (
                id: 'T1',
                input: const BtuInput(
                  lengthMeters: 3,
                  widthMeters: 4,
                  heightMeters: 2.5,
                  occupants: 2,
                  equipmentCount: 0,
                  climate: ClimateZone.cold,
                ),
                expectedRequired: 7200,
                expectedSuggested: 9000,
              ),
              (
                id: 'T2',
                input: const BtuInput(
                  lengthMeters: 3,
                  widthMeters: 5,
                  heightMeters: 2.5,
                  occupants: 2,
                  equipmentCount: 0,
                  climate: ClimateZone.cold,
                ),
                expectedRequired: 9000,
                expectedSuggested: 9000,
              ),
              (
                id: 'T3',
                input: const BtuInput(
                  lengthMeters: 4,
                  widthMeters: 5,
                  heightMeters: 2.5,
                  occupants: 2,
                  equipmentCount: 0,
                  climate: ClimateZone.temperate,
                ),
                expectedRequired: 12600,
                expectedSuggested: 18000,
              ),
              (
                id: 'T4',
                input: const BtuInput(
                  lengthMeters: 5,
                  widthMeters: 5,
                  heightMeters: 3,
                  occupants: 4,
                  equipmentCount: 2,
                  climate: ClimateZone.warm,
                ),
                expectedRequired: 21555,
                expectedSuggested: 24000,
              ),
              (
                id: 'T5',
                input: const BtuInput(
                  lengthMeters: 3,
                  widthMeters: 4,
                  heightMeters: 3.2,
                  occupants: 2,
                  equipmentCount: 0,
                  climate: ClimateZone.cold,
                ),
                expectedRequired: 8640,
                expectedSuggested: 9000,
              ),
              (
                id: 'T6',
                input: const BtuInput(
                  lengthMeters: 3,
                  widthMeters: 4,
                  heightMeters: 4,
                  occupants: 2,
                  equipmentCount: 0,
                  climate: ClimateZone.cold,
                ),
                expectedRequired: 9360,
                expectedSuggested: 12000,
              ),
              (
                id: 'T7',
                input: const BtuInput(
                  lengthMeters: 3,
                  widthMeters: 4,
                  heightMeters: 2.5,
                  occupants: 1,
                  equipmentCount: 0,
                  climate: ClimateZone.cold,
                ),
                expectedRequired: 7200,
                expectedSuggested: 9000,
              ),
              (
                id: 'T8',
                input: const BtuInput(
                  lengthMeters: 12,
                  widthMeters: 5,
                  heightMeters: 2.5,
                  occupants: 2,
                  equipmentCount: 0,
                  climate: ClimateZone.cold,
                ),
                expectedRequired: 36000,
                expectedSuggested: 36000,
              ),
              (
                id: 'T9',
                input: const BtuInput(
                  lengthMeters: 12,
                  widthMeters: 5,
                  heightMeters: 2.5,
                  occupants: 2,
                  equipmentCount: 1,
                  climate: ClimateZone.cold,
                ),
                expectedRequired: 36600,
                expectedSuggested: null,
              ),
            ];

        for (final c in cases) {
          final result = BtuCalculator.calculate(c.input);
          expect(
            result.requiredBtu,
            closeTo(c.expectedRequired, 1),
            reason: c.id,
          );
          expect(result.suggestedCapacity, c.expectedSuggested, reason: c.id);
          expect(
            result.exceedsMaxCapacity,
            c.expectedSuggested == null,
            reason: c.id,
          );
        }

        // T10: máximo absoluto.
        final t10 = BtuCalculator.calculate(
          const BtuInput(
            lengthMeters: 15,
            widthMeters: 15,
            heightMeters: 4,
            occupants: 10,
            equipmentCount: 10,
            climate: ClimateZone.warm,
          ),
        );
        expect(t10.requiredBtu, greaterThan(36000));
        expect(t10.suggestedCapacity, isNull);
        expect(t10.filterSlug, isNull);
      });

      test(
        'TC-127 · AC-086-4 · recargo de altura exacto en 2,5 m vs 2,51 m',
        () {
          final at250 = BtuCalculator.calculate(
            const BtuInput(
              lengthMeters: 4,
              widthMeters: 4,
              heightMeters: 2.5,
              occupants: 2,
              equipmentCount: 0,
              climate: ClimateZone.cold,
            ),
          );
          final at251 = BtuCalculator.calculate(
            const BtuInput(
              lengthMeters: 4,
              widthMeters: 4,
              heightMeters: 2.51,
              occupants: 2,
              equipmentCount: 0,
              climate: ClimateZone.cold,
            ),
          );
          expect(at250.requiredBtu, 9600);
          expect(at251.requiredBtu, (9600 * 1.10).round());
        },
      );

      test('TC-141 · AC-086-3/5 · monotonía y 20 vectores con semilla fija (RNF-092)', () {
        final rng = math.Random(42);
        for (var i = 0; i < 20; i++) {
          final length = 1 + rng.nextDouble() * 13;
          final width = 1 + rng.nextDouble() * 13;
          final height = 2 + rng.nextDouble() * 2;
          final occupants = 1 + rng.nextInt(10);
          final equipment = rng.nextInt(11);
          final climate = ClimateZone.values[rng.nextInt(3)];

          final small = BtuCalculator.calculate(
            BtuInput(
              lengthMeters: length,
              widthMeters: width,
              heightMeters: height,
              occupants: occupants,
              equipmentCount: equipment,
              climate: climate,
            ),
          );
          final larger = BtuCalculator.calculate(
            BtuInput(
              lengthMeters: length + 0.5,
              widthMeters: width,
              heightMeters: height,
              occupants: occupants,
              equipmentCount: equipment,
              climate: climate,
            ),
          );
          expect(larger.requiredBtu, greaterThanOrEqualTo(small.requiredBtu));
          if (small.suggestedCapacity != null &&
              larger.suggestedCapacity != null) {
            expect(
              larger.suggestedCapacity,
              greaterThanOrEqualTo(small.suggestedCapacity!),
            );
          }
        }
      });

      test(
        'TC-128 · AC-089-5 · construye slugs correctos para las 5 capacidades',
        () {
          expect(BtuCalculator.catalogFilterSlugFor(9000), '9-000-btu');
          expect(BtuCalculator.catalogFilterSlugFor(12000), '12-000-btu');
          expect(BtuCalculator.catalogFilterSlugFor(18000), '18-000-btu');
          expect(BtuCalculator.catalogFilterSlugFor(24000), '24-000-btu');
          expect(BtuCalculator.catalogFilterSlugFor(36000), '36-000-btu');
          expect(BtuCalculator.catalogFilterSlugFor(48000), isNull);
          expect(BtuCalculator.formatThousands(21555), '21.555');
          expect(BtuCalculator.formatThousands(-7200), '-7.200');
        },
      );
    },
  );

  group('TC-127 · AC-085 · límites de entrada, enteros, coma y punto', () {
    test('TC-127 · AC-085-2 · acepta extremos válidos', () {
      final minCase = BtuCalculator.validateFields(
        lengthText: '1',
        widthText: '1',
        heightText: '2',
        occupantsText: '1',
        equipmentText: '0',
        climate: ClimateZone.cold,
      );
      expect(minCase.isValid, isTrue);

      final maxCase = BtuCalculator.validateFields(
        lengthText: '15',
        widthText: '15',
        heightText: '4',
        occupantsText: '10',
        equipmentText: '10',
        climate: ClimateZone.warm,
      );
      expect(maxCase.isValid, isTrue);
    });

    test('TC-127 · AC-085-2/3/4 · rechaza fuera de rango, vacío, texto y decimales en enteros', () {
      final low = BtuCalculator.validateFields(
        lengthText: '0.9',
        widthText: '0,9',
        heightText: '1.9',
        occupantsText: '0',
        equipmentText: '-1',
        climate: ClimateZone.cold,
      );
      expect(low.isValid, isFalse);
      expect(low.errors.keys, containsAll(BtuInputField.values));
      expect(low.errors[BtuInputField.length], BtuFieldError.outOfRange);

      final high = BtuCalculator.validateFields(
        lengthText: '15.1',
        widthText: '15,1',
        heightText: '4.1',
        occupantsText: '11',
        equipmentText: '11',
        climate: ClimateZone.cold,
      );
      expect(high.isValid, isFalse);
      expect(high.errors.keys, containsAll(BtuInputField.values));

      final nonIntAndText = BtuCalculator.validateFields(
        lengthText: '',
        widthText: 'abc',
        heightText: '2.5.1',
        occupantsText: '2.5',
        equipmentText: '1,5',
        climate: ClimateZone.cold,
      );
      expect(nonIntAndText.isValid, isFalse);
      expect(
        nonIntAndText.errors[BtuInputField.length],
        BtuFieldError.emptyOrInvalid,
      );
      expect(
        nonIntAndText.errors[BtuInputField.occupants],
        BtuFieldError.notInteger,
      );
      expect(
        nonIntAndText.errors[BtuInputField.equipment],
        BtuFieldError.notInteger,
      );
    });

    test('TC-140 · AC-085-5 · coma y punto producen el mismo resultado', () {
      final dot = BtuCalculator.validateFields(
        lengthText: '3.5',
        widthText: '4.25',
        heightText: '2.75',
        occupantsText: '3',
        equipmentText: '1',
        climate: ClimateZone.temperate,
      );
      final comma = BtuCalculator.validateFields(
        lengthText: '3,5',
        widthText: '4,25',
        heightText: '2,75',
        occupantsText: '3',
        equipmentText: '1',
        climate: ClimateZone.temperate,
      );
      expect(dot.isValid, isTrue);
      expect(comma.isValid, isTrue);
      expect(
        BtuCalculator.calculate(dot.input!),
        equals(BtuCalculator.calculate(comma.input!)),
      );
    });

    test('M5 · controller actualiza campos, calcula y limpia errores', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(btuCalculatorProvider.notifier);
      expect(
        container.read(btuCalculatorProvider).climate,
        ClimateZone.temperate,
      );

      expect(notifier.calculate(), isNull);
      expect(
        container.read(btuCalculatorProvider).errors.keys,
        containsAll(BtuInputField.values),
      );

      notifier
        ..setLength('5')
        ..setWidth('5')
        ..setHeight('3,0')
        ..setOccupants('4')
        ..setEquipment('2')
        ..setClimate(ClimateZone.warm);
      final res = notifier.calculate();
      expect(res?.requiredBtu, 21555);
      expect(res?.suggestedCapacity, 24000);
      expect(container.read(btuCalculatorProvider).errors, isEmpty);
    });
  });
}
