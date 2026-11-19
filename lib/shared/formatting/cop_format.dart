import 'package:ipr_mobile/shared/domain/money.dart';

/// Formato COP sin decimales: `$ 1.234.567` (RNF-084). Implementación propia
/// y determinista: no depende de los datos de localización de la plataforma.
String formatCop(Money money) => '\$ ${_group(money.pesos)}';

/// Solo el número agrupado con puntos: `1.234.567`.
String formatCopNumber(Money money) => _group(money.pesos);

/// Etiqueta para lectores de pantalla: `1.234.567 pesos, IVA incluido`
/// (RNF-070). El texto fijo viene de l10n; esta función lo recibe ya armado
/// solo para el número.
String copSemanticsAmount(Money money) => _group(money.pesos);

String _group(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return value < 0 ? '-$buffer' : buffer.toString();
}
