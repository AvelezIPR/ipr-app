import 'dart:math' as math;

import 'package:ipr_mobile/features/branches/domain/entities/colombia_map.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/effect_tokens.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Ciudad con sedes que se marca en el mapa.
class MapPin {
  const new({
    required this.city,
    required this.branchCount,
    required this.upcoming,
  });

  final String city;

  /// Sedes abiertas en la ciudad.
  final int branchCount;

  /// Solo hay sedes por abrir.
  final bool upcoming;
}

/// Mapa de Colombia con un pin por ciudad con sedes (W3-03).
///
/// Es una **ayuda visual**: la lista y los botones de ciudad de la pantalla
/// son el control accesible (WCAG 2.5.1), así que el mapa se anuncia como una
/// sola imagen. Un toque elige el pin más cercano (radio de 28 dp, así dos
/// ciudades casi pegadas como Medellín y Rionegro no se estorban); tocar el
/// pin elegido lo deselecciona.
class BranchesMap extends StatelessWidget {
  const new({
    required this.map,
    required this.pins,
    required this.onSelect,
    super.key,
    this.selected,
    this.maxHeight = 300,
  });

  final ColombiaMap map;
  final List<MapPin> pins;
  final String? selected;
  final ValueChanged<String?> onSelect;
  final double maxHeight;

  /// Radio de toque por pin, en dp.
  static const double hitRadius = 28;

  /// Pin más cercano a [tap] dentro de [hitRadius], o `null`.
  static String? nearestPin({
    required Offset tap,
    required Map<String, Offset> positions,
  }) {
    String? best;
    var bestDistance = hitRadius;
    for (final entry in positions.entries) {
      final distance = (entry.value - tap).distance;
      if (distance <= bestDistance) {
        best = entry.key;
        bestDistance = distance;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    if (map.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      container: true,
      image: true,
      label: l10n.branchesMapSemantics,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(IprRadius.xxl),
          boxShadow: IprShadows.card,
        ),
        child: Padding(
          padding: const EdgeInsets.all(IprSpace.s3),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final aspect = map.width / map.height;
              final height = math.min(maxHeight, constraints.maxWidth / aspect);
              final size = Size(height * aspect, height);
              final scale = size.width / map.width;
              final positions = <String, Offset>{
                for (final pin in pins)
                  if (map.cities[pin.city] case final city?)
                    pin.city: Offset(city.x * scale, city.y * scale),
              };
              return Center(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) {
                    final hit = nearestPin(
                      tap: details.localPosition,
                      positions: positions,
                    );
                    if (hit == null) return;
                    onSelect(hit == selected ? null : hit);
                  },
                  child: CustomPaint(
                    size: size,
                    painter: _MapPainter(
                      map: map,
                      positions: positions,
                      pins: pins,
                      selected: selected,
                      land: scheme.surface,
                      landSelected: scheme.surfaceContainerHigh,
                      border: scheme.outlineVariant,
                      pin: scheme.primary,
                      pinSelected: scheme.secondary,
                      pinMuted: scheme.onSurfaceVariant,
                      ring: scheme.surface,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  const new({
    required this.map,
    required this.positions,
    required this.pins,
    required this.selected,
    required this.land,
    required this.landSelected,
    required this.border,
    required this.pin,
    required this.pinSelected,
    required this.pinMuted,
    required this.ring,
  });

  final ColombiaMap map;
  final Map<String, Offset> positions;
  final List<MapPin> pins;
  final String? selected;
  final Color land;
  final Color landSelected;
  final Color border;
  final Color pin;
  final Color pinSelected;
  final Color pinMuted;
  final Color ring;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / map.width;
    final selectedDepartment = selected == null
        ? null
        : map.departmentOf(selected!)?.code;

    final fill = Paint()..style = PaintingStyle.fill;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..strokeJoin = StrokeJoin.round
      ..color = border;

    for (final department in map.departments) {
      fill.color = department.code == selectedDepartment ? landSelected : land;
      for (final polygon in department.polygons) {
        final path = Path()
          ..moveTo(polygon.first.x * scale, polygon.first.y * scale);
        for (final point in polygon.skip(1)) {
          path.lineTo(point.x * scale, point.y * scale);
        }
        path.close();
        canvas
          ..drawPath(path, fill)
          ..drawPath(path, stroke);
      }
    }

    // El elegido se pinta al final para que quede por encima del resto.
    final ordered = [...pins]
      ..sort(
        (a, b) => (a.city == selected ? 1 : 0) - (b.city == selected ? 1 : 0),
      );
    for (final item in ordered) {
      final at = positions[item.city];
      if (at == null) continue;
      final isSelected = item.city == selected;
      final color = item.upcoming ? pinMuted : (isSelected ? pinSelected : pin);
      canvas
        ..drawCircle(at, isSelected ? 11 : 8, Paint()..color = ring)
        ..drawCircle(at, isSelected ? 8 : 5.5, Paint()..color = color);
      if (item.upcoming) {
        canvas.drawCircle(at, 2, Paint()..color = ring);
      }
    }
  }

  @override
  bool shouldRepaint(_MapPainter old) =>
      old.selected != selected ||
      old.map != map ||
      old.pins != pins ||
      old.land != land;
}
