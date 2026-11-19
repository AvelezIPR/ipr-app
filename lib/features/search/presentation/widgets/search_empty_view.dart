import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:ipr_mobile/shared/widgets/state_widgets.dart';
import 'package:ipr_mobile/shared/widgets/whatsapp_button.dart';
import 'package:material_ui/material_ui.dart';

/// "Sin resultados" (RF-023). Solo se construye cuando el servidor respondió
/// 200 con lista vacía; un fallo de red o de servidor usa `ErrorState`.
///
/// Acciones: escribir por WhatsApp con el término (saneado y codificado por
/// `WhatsAppButton`/`whatsAppUri`) y volver a buscar.
class SearchEmptyView extends StatelessWidget {
  const new({required this.query, required this.onRetry, super.key});

  /// Texto normalizado que se buscó.
  final String query;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return EmptyState(
      title: l10n.searchEmptyTitle(query),
      body: l10n.searchEmptyBody,
      action: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          WhatsAppButton(
            label: l10n.actionContactWhatsApp,
            message: l10n.sharedWhatsappMsgSearch(sanitizeWhatsAppTerm(query)),
          ),
          const SizedBox(height: IprSpace.s2),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onRetry,
              child: Text(l10n.searchEmptyRetry),
            ),
          ),
        ],
      ),
    );
  }
}
