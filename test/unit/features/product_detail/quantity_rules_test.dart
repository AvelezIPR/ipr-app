import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/features/product_detail/domain/rules/quantity_rules.dart';

void main() {
  group('AC-029-2 · clamp', () {
    test('no baja de 1 ni sube de 99', () {
      expect(QuantityRules.clamp(0), 1);
      expect(QuantityRules.clamp(-5), 1);
      expect(QuantityRules.clamp(1), 1);
      expect(QuantityRules.clamp(50), 50);
      expect(QuantityRules.clamp(99), 99);
      expect(QuantityRules.clamp(100), 99);
    });

    test('un tope menor lo respeta, pero nunca pasa de 99 ni baja de 1', () {
      expect(QuantityRules.clamp(10, maxQuantity: 5), 5);
      expect(QuantityRules.clamp(10, maxQuantity: 0), 1);
      expect(QuantityRules.clamp(500, maxQuantity: 500), 99);
    });
  });

  group('AC-029-3 · parse de cantidades escritas a mano', () {
    const cases = {
      '0': (1, true),
      '100': (99, true),
      '-1': (1, true),
      '1.5': (1, true),
      '': (1, true),
      '   ': (1, true),
      'abc': (1, true),
      '12abc': (1, true),
      '1e2': (1, true),
      '٣': (1, true),
      '9999999999': (99, true),
      '1': (1, false),
      '7': (7, false),
      ' 42 ': (42, false),
      '99': (99, false),
    };
    cases.forEach((raw, expected) {
      test('"$raw" → ${expected.$1} (corregido: ${expected.$2})', () {
        final result = QuantityRules.parse(raw);
        expect(result.value, expected.$1);
        expect(result.corrected, expected.$2);
        expect(result.value, inInclusiveRange(1, 99));
      });
    });

    test('con tope menor corrige al tope', () {
      expect(
        QuantityRules.parse('10', maxQuantity: 5),
        const QuantityInput(value: 5, corrected: true),
      );
    });
  });
}
