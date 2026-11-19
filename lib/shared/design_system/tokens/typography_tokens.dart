import 'package:material_ui/material_ui.dart';

/// Familias empaquetadas como assets (OFL 1.1; DA-08/APR-05 pendientes).
abstract final class IprFonts {
  static const poppins = 'Poppins';
  static const mono = 'JetBrainsMono';
}

/// Escala tipográfica (`design_system.md` §5.2). Mínimo absoluto 12 sp.
abstract final class IprTypography {
  static TextStyle _poppins(
    double size,
    double height,
    FontWeight weight, {
    double letterSpacing = 0,
  }) => TextStyle(
    fontFamily: IprFonts.poppins,
    fontSize: size,
    height: height / size,
    fontWeight: weight,
    letterSpacing: letterSpacing,
  );

  static TextTheme textTheme() => TextTheme(
    headlineLarge: _poppins(28, 36, FontWeight.w700),
    headlineMedium: _poppins(24, 32, FontWeight.w600),
    titleLarge: _poppins(20, 28, FontWeight.w600),
    titleMedium: _poppins(16, 24, FontWeight.w500, letterSpacing: 0.15),
    titleSmall: _poppins(14, 20, FontWeight.w500, letterSpacing: 0.1),
    bodyLarge: _poppins(16, 24, FontWeight.w400, letterSpacing: 0.5),
    bodyMedium: _poppins(14, 20, FontWeight.w400, letterSpacing: 0.25),
    bodySmall: _poppins(12, 16, FontWeight.w400, letterSpacing: 0.4),
    labelLarge: _poppins(14, 20, FontWeight.w600, letterSpacing: 0.1),
    labelMedium: _poppins(12, 16, FontWeight.w500, letterSpacing: 0.5),
  );
}

/// Estilos que `TextTheme` no cubre (precio de tarjeta, SKU).
@immutable
final class IprTextStyles extends ThemeExtension<IprTextStyles> {
  const new({required this.priceCard, required this.monoSku});

  static final standard = IprTextStyles(
    priceCard: IprTypography._poppins(16, 24, FontWeight.w700),
    monoSku: const TextStyle(
      fontFamily: IprFonts.mono,
      fontSize: 13,
      height: 18 / 13,
    ),
  );

  final TextStyle priceCard;
  final TextStyle monoSku;

  @override
  IprTextStyles copyWith({TextStyle? priceCard, TextStyle? monoSku}) =>
      IprTextStyles(
        priceCard: priceCard ?? this.priceCard,
        monoSku: monoSku ?? this.monoSku,
      );

  @override
  IprTextStyles lerp(ThemeExtension<IprTextStyles>? other, double t) {
    if (other is! IprTextStyles) return this;
    return IprTextStyles(
      priceCard: TextStyle.lerp(priceCard, other.priceCard, t)!,
      monoSku: TextStyle.lerp(monoSku, other.monoSku, t)!,
    );
  }
}
