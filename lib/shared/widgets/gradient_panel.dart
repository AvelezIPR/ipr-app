import 'dart:ui' show PointMode;

import 'package:ipr_mobile/shared/design_system/tokens/effect_tokens.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Bloque de marca: degradado azul, puntos tenues y sombra elevada, como el
/// bloque de cifras y los banners de la web. Es decorativo: el contenido
/// ([child]) es el que lleva la semántica. El texto debe ser blanco.
class IprGradientPanel extends StatelessWidget {
  const new({
    required this.child,
    super.key,
    this.gradient = IprGradients.hero,
    this.padding = const EdgeInsets.all(IprSpace.s5),
  });

  final Widget child;
  final Gradient gradient;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(IprRadius.xxl);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: radius,
        boxShadow: IprShadows.raised,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: CustomPaint(
          painter: const _DotPainter(),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Cuadrícula de puntos blancos al 10 %: textura, no información.
class _DotPainter extends CustomPainter {
  const new();

  static const double _gap = 14;

  @override
  void paint(Canvas canvas, Size size) {
    final points = <Offset>[
      for (var y = _gap / 2; y < size.height; y += _gap)
        for (var x = _gap / 2; x < size.width; x += _gap) Offset(x, y),
    ];
    canvas.drawPoints(
      PointMode.points,
      points,
      Paint()
        ..color = const Color(0x1AFFFFFF)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Cuadro translúcido con un ícono, sobre un [IprGradientPanel] (el "vidrio"
/// de la web). Decorativo: queda fuera del árbol de accesibilidad.
class IprGlassIcon extends StatelessWidget {
  const new({required this.icon, super.key, this.size = 44});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0x26FFFFFF),
          borderRadius: BorderRadius.circular(IprRadius.lg),
          border: Border.all(color: const Color(0x33FFFFFF)),
        ),
        child: SizedBox.square(
          dimension: size,
          child: Icon(icon, color: Colors.white, size: size * 0.5),
        ),
      ),
    );
  }
}
