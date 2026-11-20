import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ipr_mobile/features/support/domain/entities/legal_document.dart';
import 'package:ipr_mobile/features/support/presentation/controllers/legal_controllers.dart';
import 'package:ipr_mobile/features/support/presentation/widgets/legal_widgets.dart';
import 'package:ipr_mobile/features/support/support_providers.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:ipr_mobile/shared/widgets/whatsapp_button.dart';
import 'package:material_ui/material_ui.dart';

/// Documentos legales (`/support/legal`, PT-33): RF-099.
///
/// Accesible sin sesión, antes del registro y desde la pestaña Cuenta. Lista
/// lo que `/config` publica (título, versión) y lo abre en el navegador
/// seguro del sistema, nunca en un WebView. No hay textos ni URL incrustados
/// (D-12): sin documentos publicados la pantalla lo explica y ofrece
/// "Reintentar" (falla cerrado).
class LegalScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final documents = ref.watch(legalDocumentsProvider);
    final notice = ref.watch(accountDeletionNoticeProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.supportLegalTitle)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(IprSpace.s4),
          children: [
            if (documents.isEmpty)
              const _LegalUnavailable()
            else ...[
              Text(l10n.supportLegalIntro, style: theme.textTheme.bodyMedium),
              const SizedBox(height: IprSpace.s2),
              for (final document in documents) ...[
                if (document.url != null || document.email == null)
                  LegalDocumentTile(
                    document: document,
                    onTap: () => unawaited(_open(context, ref, document)),
                  ),
                if (document.email case final mail?)
                  LegalEmailTile(
                    email: mail,
                    onTap: () => unawaited(_writeTo(context, ref, mail)),
                  ),
              ],
            ],
            if (notice != null) ...[
              const SizedBox(height: IprSpace.s5),
              Semantics(
                header: true,
                child: Text(
                  l10n.supportLegalDeletionTitle,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: IprSpace.s2),
              // Texto plano: el servidor no puede inyectar marcado.
              Text(notice, style: theme.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }

  static String? _emailOf(List<LegalDocument> documents) {
    for (final document in documents) {
      if (document.email != null) return document.email;
    }
    return null;
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    LegalDocument document,
  ) async {
    final result = await ref
        .read(legalOpenControllerProvider.notifier)
        .open(document);
    if (result == null || result == LegalOpenResult.opened) return;
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _OpenFailedDialog(
        result: result,
        email: _emailOf(ref.read(legalDocumentsProvider)),
      ),
    );
  }

  Future<void> _writeTo(
    BuildContext context,
    WidgetRef ref,
    String email,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final opened = await ref
        .read(legalOpenControllerProvider.notifier)
        .openEmail(email);
    if (opened) return;
    await Clipboard.setData(ClipboardData(text: email));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(l10n.supportLegalEmailCopied(email))),
      );
  }
}

/// Sin documentos publicados (o `/config` aún sin cargar): explicación,
/// "Reintentar" y alternativa por WhatsApp.
class _LegalUnavailable extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final refreshing = ref.watch(legalRetryControllerProvider);
    return Column(
      children: [
        const SizedBox(height: IprSpace.s5),
        ExcludeSemantics(
          child: Icon(
            Icons.description_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: IprSpace.s3),
        Semantics(
          liveRegion: true,
          child: Text(
            l10n.supportLegalEmptyTitle,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: IprSpace.s2),
        Text(
          l10n.supportLegalEmptyBody,
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: IprSpace.s4),
        FilledButton(
          onPressed: refreshing ? null : () => unawaited(_retry(context, ref)),
          child: Text(refreshing ? l10n.stateLoading : l10n.actionRetry),
        ),
        const SizedBox(height: IprSpace.s3),
        WhatsAppButton(
          label: l10n.supportLegalWhatsapp,
          message: l10n.supportLegalWhatsappMsg,
          filled: false,
        ),
      ],
    );
  }

  Future<void> _retry(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final message = AppLocalizations.of(context).supportLegalStillEmpty;
    final found = await ref.read(legalRetryControllerProvider.notifier).retry();
    if (found) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

/// El documento no se abrió: mensaje claro y alternativa (WhatsApp y, si
/// existe, el correo del canal de derechos).
class _OpenFailedDialog extends StatelessWidget {
  const new({required this.result, required this.email});

  final LegalOpenResult result;
  final String? email;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final body = result == LegalOpenResult.failed
        ? l10n.supportLegalOpenFailedBody
        : l10n.supportLegalUnavailableBody;
    final mail = email;
    return AlertDialog(
      scrollable: true,
      title: Text(l10n.supportLegalOpenFailedTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(body),
          const SizedBox(height: IprSpace.s4),
          WhatsAppButton(
            label: l10n.supportLegalWhatsapp,
            message: l10n.supportLegalWhatsappMsg,
          ),
        ],
      ),
      actions: [
        if (mail != null)
          TextButton(
            onPressed: () {
              final messenger = ScaffoldMessenger.of(context);
              final copied = l10n.supportLegalEmailCopied(mail);
              unawaited(Clipboard.setData(ClipboardData(text: mail)));
              Navigator.of(context).pop();
              messenger
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(copied)));
            },
            child: Text(l10n.supportLegalCopyEmail),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.supportLegalClose),
        ),
      ],
    );
  }
}
