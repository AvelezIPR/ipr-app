import 'package:ipr_mobile/features/support/domain/entities/legal_document.dart';

/// Abre un documento legal fuera de la app. Nunca con un WebView propio
/// (AC-099-7).
abstract interface class LegalOpener {
  Future<LegalOpenResult> open(LegalDocument document);
}
