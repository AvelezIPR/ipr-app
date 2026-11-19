import 'package:flutter/painting.dart';

/// Paleta base. Los colores de marca vienen de la documentación y de la web;
/// los derivados (`green700`, `red700`, `gray700` y los tintes) son
/// **PROPUESTA A APROBAR por Marketing** (APR-02, D-13). Las razones de
/// contraste están calculadas en `docs/07_ux_ui/accessibility.md`.
abstract final class IprPalette {
  // Marca [HECHO].
  static const blue900 = Color(0xFF0A3651);
  static const blue800 = Color(0xFF0B4970);
  static const blue700 = Color(0xFF07628E);
  static const ink = Color(0xFF151A21);
  static const surfaceMuted = Color(0xFFF3F5F7);
  static const surfaceTint = Color(0xFFEAF4F9);
  static const surfaceAccent = Color(0xFFE8F3FA);
  static const onTint = Color(0xFF055177);
  static const outlineSoft = Color(0xFFE2E8F0);
  static const white = Color(0xFFFFFFFF);

  /// Verde de marca según la documentación (APR-01: la web define #99C120).
  /// **Solo** decorativo o relleno con texto `ink`: nunca texto normal ni
  /// texto blanco encima (3,03:1).
  static const green500 = Color(0xFF5BA628);

  // Gris de la web: 4,49:1, **no** sirve como texto; sí como borde (≥ 3:1).
  static const gray500 = Color(0xFF75777B);

  // Derivados [PROPUESTA A APROBAR por Marketing].
  static const green700 = Color(0xFF3F731C);
  static const green50 = Color(0xFFEBF8E2);
  static const red700 = Color(0xFFC1292F);
  static const red50 = Color(0xFFFAEBEB);
  static const gray700 = Color(0xFF66686B);

  // Tema oscuro: tokens preparados, tema desactivado en el MVP (RF-113).
  static const darkSurface = Color(0xFF0A1320);
  static const darkSurfaceContainer = Color(0xFF0F1A26);
  static const darkOnSurface = Color(0xFFEAF3F9);
  static const darkPrimary = Color(0xFF439BE4);
}
