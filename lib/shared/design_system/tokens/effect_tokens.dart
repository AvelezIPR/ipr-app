import 'package:ipr_mobile/shared/design_system/tokens/color_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Sombras difusas teñidas de azul marino, como las de la web (tarjetas con
/// elevación suave en vez de bordes duros).
abstract final class IprShadows {
  /// Tarjetas de lista y de producto.
  static const card = <BoxShadow>[
    BoxShadow(color: Color(0x1A053554), blurRadius: 14, offset: Offset(0, 4)),
  ];

  /// Bloques destacados (hero, banda de cifras).
  static const raised = <BoxShadow>[
    BoxShadow(color: Color(0x33053554), blurRadius: 24, offset: Offset(0, 10)),
  ];
}

/// Degradados de la web: azul profundo para bloques de marca y un fondo de
/// página que pasa de blanco a un azul casi imperceptible.
abstract final class IprGradients {
  /// Hero: del azul de marca al marino. Texto blanco encima (≥ 6,7:1).
  static const hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [IprPalette.blue700, IprPalette.blue900],
  );

  /// Banda de cifras: más oscura que el hero.
  static const band = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [IprPalette.blue800, IprPalette.blue900],
  );

  /// Fondo de pantalla de Inicio.
  static const page = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [IprPalette.white, Color(0xFFF1F7FB)],
  );
}
