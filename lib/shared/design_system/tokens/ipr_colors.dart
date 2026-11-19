import 'package:ipr_mobile/shared/design_system/tokens/color_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Roles de color que Material 3 no tiene (`design_system.md` §3.4).
@immutable
final class IprColors extends ThemeExtension<IprColors> {
  const new({
    required this.primaryPressed,
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.brandGreen,
    required this.focusRing,
    required this.textSecondary,
  });

  static const light = IprColors(
    primaryPressed: IprPalette.blue800,
    success: IprPalette.green700,
    onSuccess: IprPalette.white,
    successContainer: IprPalette.green50,
    onSuccessContainer: IprPalette.ink,
    brandGreen: IprPalette.green500,
    focusRing: IprPalette.blue900,
    textSecondary: IprPalette.gray700,
  );

  final Color primaryPressed;

  /// Texto e íconos de éxito sobre claro (5,71:1).
  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;

  /// **Solo decorativo**: nunca como texto (3,03:1).
  final Color brandGreen;
  final Color focusRing;
  final Color textSecondary;

  @override
  IprColors copyWith({
    Color? primaryPressed,
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? brandGreen,
    Color? focusRing,
    Color? textSecondary,
  }) => IprColors(
    primaryPressed: primaryPressed ?? this.primaryPressed,
    success: success ?? this.success,
    onSuccess: onSuccess ?? this.onSuccess,
    successContainer: successContainer ?? this.successContainer,
    onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
    brandGreen: brandGreen ?? this.brandGreen,
    focusRing: focusRing ?? this.focusRing,
    textSecondary: textSecondary ?? this.textSecondary,
  );

  @override
  IprColors lerp(ThemeExtension<IprColors>? other, double t) {
    if (other is! IprColors) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return IprColors(
      primaryPressed: mix(primaryPressed, other.primaryPressed),
      success: mix(success, other.success),
      onSuccess: mix(onSuccess, other.onSuccess),
      successContainer: mix(successContainer, other.successContainer),
      onSuccessContainer: mix(onSuccessContainer, other.onSuccessContainer),
      brandGreen: mix(brandGreen, other.brandGreen),
      focusRing: mix(focusRing, other.focusRing),
      textSecondary: mix(textSecondary, other.textSecondary),
    );
  }
}
