import 'package:ipr_mobile/shared/navigation/routes.dart';

/// Ruta de autenticación ([path]: `Routes.login` o `Routes.register`) con el
/// parámetro `from` si lo hay.
///
/// Solo se reenvía una ruta interna conocida (`Routes.safeInternal`): el
/// router vuelve a validarla, pero una URL externa nunca debe viajar por aquí.
String authLocation(String path, String? from) {
  final safe = Routes.safeInternal(from);
  if (safe == Routes.home) return path;
  return Uri(path: path, queryParameters: {'from': safe}).toString();
}
