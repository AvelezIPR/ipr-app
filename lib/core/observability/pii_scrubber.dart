/// Elimina datos personales y secretos de cualquier texto antes de enviarlo a
/// un reporte de fallos o a un registro (RNF-047, SC-044).
///
/// **Falla cerrado**: si algo sale mal al depurar, devuelve un marcador y
/// nunca el texto original.
final class PiiScrubber {
  const new();

  static const redacted = '<redacted>';

  static final _patterns = <(RegExp, String)>[
    // Tokens de la app y cabeceras de autenticación.
    (RegExp(r'ipr[ar]_[A-Za-z0-9_\-]+'), '<token>'),
    (
      RegExp(r'Bearer\s+[A-Za-z0-9._~+/=\-]+', caseSensitive: false),
      'Bearer <token>',
    ),
    // JWT y secretos largos en base64url.
    (
      RegExp(r'\beyJ[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]+\.[A-Za-z0-9_\-]*'),
      '<token>',
    ),
    // Consulta de las URL (puede traer términos de búsqueda o tokens).
    (RegExp(r'\?[^\s"]+'), '?<query>'),
    // Correos.
    (RegExp(r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}'), '<email>'),
    // Teléfonos y documentos: 6 o más dígitos, con separadores comunes.
    (RegExp(r'\+?\d[\d\s().\-]{4,}\d'), '<number>'),
  ];

  /// Depura [input]. Nunca lanza.
  String scrub(String input) {
    try {
      var out = input;
      for (final (pattern, replacement) in _patterns) {
        out = out.replaceAll(pattern, replacement);
      }
      return out;
    } on Object {
      return redacted;
    }
  }
}
