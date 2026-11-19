/// Normalización del texto de búsqueda (RF-020, AC-020-3/4, AC-022-2).
///
/// El texto lo escribe el usuario: es un dato suyo y **no se registra** en
/// logs ni analítica; solo vive en memoria durante la sesión.
abstract final class SearchQuery {
  /// `maxLength` de `q` en `openapi.yaml` (`SearchQuery` y `searchSuggestions`).
  static const maxLength = 120;

  /// `minLength` de `q` en `searchSuggestions` (`openapi.yaml`).
  static const minSuggestionLength = 2;

  static final _controlChars = RegExp(r'[\u0000-\u001F\u007F-\u009F]');
  static final _htmlTags = RegExp('</?[A-Za-z][^>]*>');
  static final _whitespace = RegExp(r'\s+');

  /// Quita caracteres de control y etiquetas HTML (el contrato exige `q` sin
  /// ellos), colapsa espacios, recorta y limita a [maxLength] caracteres.
  /// Los demás signos (`' " < > % & #`, tildes) se conservan: se codifican en
  /// la URL (AC-020-4) y nunca se interpretan como marcado.
  static String normalize(String raw) {
    final cleaned = raw
        .replaceAll(_controlChars, ' ')
        .replaceAll(_htmlTags, ' ')
        .replaceAll(_whitespace, ' ')
        .trim();
    if (cleaned.length <= maxLength) return cleaned;
    // Sin partir un par sustituto (emoji) por la mitad.
    var end = maxLength;
    final unit = cleaned.codeUnitAt(end - 1);
    if (unit >= 0xD800 && unit <= 0xDBFF) end--;
    return cleaned.substring(0, end).trimRight();
  }

  /// ¿Hay texto suficiente para pedir sugerencias?
  static bool isSuggestible(String normalized) =>
      normalized.length >= minSuggestionLength;
}
