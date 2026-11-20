import 'package:ipr_mobile/core/config/remote_config.dart';
import 'package:ipr_mobile/features/support/domain/entities/legal_document.dart';

String? _clean(String? raw) {
  final trimmed = raw?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}

/// Documentos publicados en `/config`. Un documento se lista si trae URL o
/// versión (términos y política) o URL o correo (derechos del titular); lo
/// que no venga no se inventa. Sin nada publicado devuelve una lista vacía
/// (falla cerrado: la pantalla lo explica).
List<LegalDocument> legalDocumentsFromConfig(RemoteConfig config) {
  final terms = LegalDocument(
    kind: LegalDocumentKind.terms,
    version: _clean(config.termsVersion),
    url: _clean(config.termsUrl),
  );
  final privacy = LegalDocument(
    kind: LegalDocumentKind.privacy,
    version: _clean(config.privacyPolicyVersion),
    url: _clean(config.privacyPolicyUrl),
  );
  final rights = LegalDocument(
    kind: LegalDocumentKind.dataRights,
    url: _clean(config.dataRightsUrl),
    email: _clean(config.dataRightsEmail),
  );
  return [
    if (terms.url != null || terms.version != null) terms,
    if (privacy.url != null || privacy.version != null) privacy,
    if (rights.url != null || rights.email != null) rights,
  ];
}

/// Aviso informativo sobre la eliminación de cuenta (texto plano) o `null`.
String? accountDeletionNoticeFromConfig(RemoteConfig config) =>
    _clean(config.accountDeletionNotice);
