import 'package:ipr_mobile/features/support/domain/entities/legal_document.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Título del documento según su tipo (texto del l10n, no del servidor).
String legalDocumentTitle(AppLocalizations l10n, LegalDocumentKind kind) =>
    switch (kind) {
      LegalDocumentKind.terms => l10n.supportLegalTerms,
      LegalDocumentKind.privacy => l10n.supportLegalPrivacy,
      LegalDocumentKind.dataRights => l10n.supportLegalDataRights,
    };

/// Fila de un documento: título + versión y aviso "se abre en el navegador".
/// Objetivo táctil ≥ 48 dp; texto + ícono (nunca solo color).
class LegalDocumentTile extends StatelessWidget {
  const new({required this.document, required this.onTap, super.key});

  final LegalDocument document;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final version = document.version;
    return Semantics(
      hint: l10n.supportLegalOpensInBrowser,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        minTileHeight: IprSpace.minTapTarget,
        leading: const ExcludeSemantics(
          child: Icon(Icons.description_outlined),
        ),
        title: Text(legalDocumentTitle(l10n, document.kind)),
        subtitle: version == null
            ? null
            : Text(l10n.supportLegalVersion(version)),
        trailing: const ExcludeSemantics(child: Icon(Icons.open_in_new)),
        onTap: onTap,
      ),
    );
  }
}

/// Fila del correo del canal de derechos del titular.
class LegalEmailTile extends StatelessWidget {
  const new({required this.email, required this.onTap, super.key});

  final String email;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minTileHeight: IprSpace.minTapTarget,
      leading: const ExcludeSemantics(child: Icon(Icons.mail_outline)),
      title: Text(l10n.supportLegalEmailAction(email)),
      onTap: onTap,
    );
  }
}
