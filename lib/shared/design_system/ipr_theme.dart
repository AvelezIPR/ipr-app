import 'package:ipr_mobile/shared/design_system/tokens/color_tokens.dart';
import 'package:ipr_mobile/shared/design_system/tokens/ipr_colors.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:ipr_mobile/shared/design_system/tokens/typography_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Tema Material 3 construido desde tokens con un `ColorScheme` EXPLÍCITO
/// (no `fromSeed`), para garantizar los contrastes medidos (`design_system.md`
/// §3.4). MVP: solo tema claro; los tokens oscuros están preparados.
abstract final class IprTheme {
  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: IprPalette.blue700,
    onPrimary: IprPalette.white,
    primaryContainer: IprPalette.surfaceTint,
    onPrimaryContainer: IprPalette.onTint,
    secondary: IprPalette.blue900,
    onSecondary: IprPalette.white,
    secondaryContainer: IprPalette.surfaceAccent,
    onSecondaryContainer: IprPalette.onTint,
    error: IprPalette.red700,
    onError: IprPalette.white,
    errorContainer: IprPalette.red50,
    onErrorContainer: IprPalette.ink,
    surface: IprPalette.white,
    onSurface: IprPalette.ink,
    surfaceContainer: IprPalette.surfaceMuted,
    surfaceContainerHigh: IprPalette.outlineSoft,
    onSurfaceVariant: IprPalette.gray700,
    outline: IprPalette.gray500,
    outlineVariant: IprPalette.outlineSoft,
    inverseSurface: IprPalette.ink,
    onInverseSurface: IprPalette.white,
    scrim: Color(0x52000000),
  );

  static ThemeData light() {
    final base = IprTypography.textTheme().apply(
      bodyColor: _lightScheme.onSurface,
      displayColor: _lightScheme.onSurface,
    );
    // Títulos en azul marino como los h2 de la web (#053554 ≈ blue900,
    // 12,5:1 sobre blanco); el cuerpo conserva la tinta.
    const heading = IprPalette.blue900;
    final textTheme = base.copyWith(
      headlineLarge: base.headlineLarge?.copyWith(color: heading),
      headlineMedium: base.headlineMedium?.copyWith(color: heading),
      titleLarge: base.titleLarge?.copyWith(color: heading),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: _lightScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: _lightScheme.surface,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      extensions: [IprColors.light, IprTextStyles.standard],
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(IprSpace.minTapTarget, IprSpace.minTapTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(IprRadius.lg),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(IprSpace.minTapTarget, IprSpace.minTapTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(IprRadius.lg),
          ),
          side: const BorderSide(color: IprPalette.blue700),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(IprSpace.minTapTarget, IprSpace.minTapTarget),
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        // Etiqueta SIEMPRE visible arriba, nunca flotante (se recorta a 200 %).
        floatingLabelBehavior: FloatingLabelBehavior.never,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(IprRadius.lg),
          borderSide: const BorderSide(color: IprPalette.gray500),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(IprRadius.lg),
          borderSide: const BorderSide(color: IprPalette.blue700, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        color: _lightScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shadowColor: const Color(0x33053554),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(IprRadius.xl),
          side: BorderSide(color: _lightScheme.outlineVariant),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _lightScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: const Color(0x33053554),
        indicatorColor: _lightScheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? textTheme.labelMedium?.copyWith(
                  color: _lightScheme.primary,
                  fontWeight: FontWeight.w700,
                )
              : textTheme.labelMedium,
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? _lightScheme.primary
                : _lightScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
