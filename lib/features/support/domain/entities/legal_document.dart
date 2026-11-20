/// Documentos legales que publica IPR (RF-099). El contenido y las URL llegan
/// por `/config`; la app no incrusta ningún texto legal (D-12).
enum LegalDocumentKind { terms, privacy, dataRights }

/// Un documento publicado: versión y dirección tal como las entrega el
/// servidor, sin interpretar. Puede venir sin URL (p. ej. solo el correo del
/// canal de derechos).
final class LegalDocument {
  const new({required this.kind, this.version, this.url, this.email});

  final LegalDocumentKind kind;

  /// Versión vigente publicada (no vacía) o `null`.
  final String? version;

  /// URL del documento tal como llegó (se valida al abrirla) o `null`.
  final String? url;

  /// Correo del canal (solo `dataRights`) o `null`.
  final String? email;
}

/// Qué pasó al pedir abrir un documento.
enum LegalOpenResult {
  /// Se entregó al navegador seguro del sistema.
  opened,

  /// Falta la URL o no es una dirección válida.
  unavailable,

  /// La política de URLs de la app no la permite (no https, host no
  /// autorizado, credenciales en la URL, puerto raro...).
  blocked,

  /// La URL es válida pero el sistema no pudo abrirla.
  failed,
}
