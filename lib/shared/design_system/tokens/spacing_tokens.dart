/// Escala de espaciado base 4 dp (`design_system.md` §6.1).
abstract final class IprSpace {
  static const double s0 = 0;
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;

  /// Margen lateral de pantalla compacta.
  static const double s4 = 16;
  static const double s5 = 24;
  static const double s6 = 32;
  static const double s7 = 48;
  static const double s8 = 64;

  /// Objetivo táctil mínimo (RNF-071).
  static const double minTapTarget = 48;
}

/// Radios (`design_system.md` §6.3).
abstract final class IprRadius {
  static const double sm = 6;
  static const double md = 8;
  static const double lg = 10;
  static const double xl = 14;
  static const double xxl = 18;
  static const double full = 999;
}
