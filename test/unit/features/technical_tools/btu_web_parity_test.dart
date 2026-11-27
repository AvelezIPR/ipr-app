import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/features/technical_tools/domain/entities/btu_models.dart';
import 'package:ipr_mobile/features/technical_tools/domain/rules/btu_calculator.dart';

/// Réplica **literal** de `calcular()` de la web
/// (`ipr-frontend/src/features/calculadora/btu-fields.tsx`, 2026-11-26), la
/// fórmula que hoy usan los visitantes del sitio. Sirve de referencia para
/// demostrar que la app calcula lo mismo (W3-04). La validación oficial
/// sigue pendiente de Ingeniería IPR (D-08).
({double required, int? suggested}) _web({
  required double largo,
  required double ancho,
  required double alto,
  required int personas,
  required int equipos,
  required double factor,
}) {
  final area = largo * ancho;
  var requerido = area * 600;
  if (alto > 2.5) {
    requerido *= 1 + ((alto - 2.5) / 0.5).ceil() * 0.1;
  }
  requerido += math.max(0, personas - 2) * 600;
  requerido *= factor;
  requerido += equipos * 600;
  const btus = [9000, 12000, 18000, 24000, 36000];
  int? suggested;
  for (final btu in btus) {
    if (btu >= requerido) {
      suggested = btu;
      break;
    }
  }
  return (required: requerido, suggested: suggested);
}

void main() {
  group('W3-04 · paridad con la calculadora de la web', () {
    test('los factores de clima y las capacidades son los mismos', () {
      expect(ClimateZone.cold.factor, 1);
      expect(ClimateZone.temperate.factor, 1.05);
      expect(ClimateZone.warm.factor, 1.15);
      expect(BtuCalculator.commercialCapacities, [
        9000,
        12000,
        18000,
        24000,
        36000,
      ]);
    });

    test('los rangos de entrada son los de los controles de la web', () {
      expect(BtuCalculator.minLengthMeters, 1);
      expect(BtuCalculator.maxLengthMeters, 15);
      expect(BtuCalculator.minWidthMeters, 1);
      expect(BtuCalculator.maxWidthMeters, 15);
      expect(BtuCalculator.minHeightMeters, 2);
      expect(BtuCalculator.maxHeightMeters, 4);
      expect(BtuCalculator.minOccupants, 1);
      expect(BtuCalculator.maxOccupants, 10);
      expect(BtuCalculator.minEquipment, 0);
      expect(BtuCalculator.maxEquipment, 10);
    });

    test(
      'valores por defecto de la web (5 × 4 × 2,5 m, 2 personas, 1 equipo)',
      () {
        // 20 m² × 600 = 12.000 → × 1,05 = 12.600 → + 1 equipo × 600 = 13.200.
        final result = BtuCalculator.calculate(
          const BtuInput(
            lengthMeters: 5,
            widthMeters: 4,
            heightMeters: 2.5,
            occupants: 2,
            equipmentCount: 1,
            climate: ClimateZone.temperate,
          ),
        );
        expect(result.requiredBtu, 13200);
        expect(result.suggestedCapacity, 18000);
        expect(result.filterSlug, '18-000-btu');
      },
    );

    test('da lo mismo que la web en una malla de 10.800 combinaciones', () {
      const largos = [1.0, 3.5, 5.0, 7.5, 12.0, 15.0];
      const anchos = [1.0, 4.0, 6.5, 10.0, 15.0];
      const altos = [2.0, 2.5, 2.6, 3.0, 3.4, 4.0];
      const personas = [1, 2, 3, 6, 10];
      const equipos = [0, 1, 5, 10];
      var compared = 0;
      for (final largo in largos) {
        for (final ancho in anchos) {
          for (final alto in altos) {
            for (final p in personas) {
              for (final e in equipos) {
                for (final zone in ClimateZone.values) {
                  final web = _web(
                    largo: largo,
                    ancho: ancho,
                    alto: alto,
                    personas: p,
                    equipos: e,
                    factor: zone.factor,
                  );
                  final app = BtuCalculator.calculate(
                    BtuInput(
                      lengthMeters: largo,
                      widthMeters: ancho,
                      heightMeters: alto,
                      occupants: p,
                      equipmentCount: e,
                      climate: zone,
                    ),
                  );
                  final reason =
                      '$largo×$ancho×$alto, $p pers., $e eq., ${zone.name}';
                  // Misma potencia requerida, redondeada igual.
                  expect(app.requiredBtu, web.required.round(), reason: reason);

                  // La web compara SIN redondear; si el valor cae a menos de
                  // un BTU de una capacidad, el ruido de coma flotante puede
                  // empujar a la web a la capacidad siguiente (p. ej.
                  // 9000,000000000001 → 12.000). La app redondea primero y da
                  // la capacidad exacta: es la diferencia conocida y buscada.
                  final nearBoundary = BtuCalculator.commercialCapacities.any(
                    (c) => (web.required - c).abs() < 1,
                  );
                  if (!nearBoundary) {
                    expect(
                      app.suggestedCapacity,
                      web.suggested,
                      reason: reason,
                    );
                  }
                  compared++;
                }
              }
            }
          }
        }
      }
      expect(compared, 10800);
    });

    test(
      'en el límite exacto la app da la capacidad exacta (la web, ruido)',
      () {
        // 10 m² × 600 = 6.000 → alto 3,0 (+10 %) = 6.600 → 6 personas (+2.400)
        // = 9.000 exactos. En coma flotante la web obtiene 9000,000000000001 y
        // sugiere 12.000; la app redondea y sugiere 9.000.
        final web = _web(
          largo: 5,
          ancho: 2,
          alto: 3,
          personas: 6,
          equipos: 0,
          factor: 1,
        );
        final app = BtuCalculator.calculate(
          const BtuInput(
            lengthMeters: 5,
            widthMeters: 2,
            heightMeters: 3,
            occupants: 6,
            equipmentCount: 0,
            climate: ClimateZone.cold,
          ),
        );
        expect(app.requiredBtu, 9000);
        expect(app.suggestedCapacity, 9000);
        expect(web.suggested, anyOf(9000, 12000));
      },
    );
  });
}
