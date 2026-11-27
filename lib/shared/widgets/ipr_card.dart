import 'package:ipr_mobile/shared/design_system/tokens/effect_tokens.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Tarjeta de la app: superficie blanca, borde fino y sombra suave teñida de
/// azul (la web usa elevación, no solo bordes). Si hay [onTap] toda la
/// tarjeta es un solo objetivo táctil con ondulación recortada al radio; la
/// semántica la pone quien la usa.
class IprCard extends StatelessWidget {
  const new({
    required this.child,
    super.key,
    this.onTap,
    this.radius = IprRadius.xl,
    this.color,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double radius;

  /// Relleno; por defecto la superficie del tema.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final borderRadius = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? scheme.surface,
        borderRadius: borderRadius,
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: IprShadows.card,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: onTap == null ? child : InkWell(onTap: onTap, child: child),
      ),
    );
  }
}
