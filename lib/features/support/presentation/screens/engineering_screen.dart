import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ipr_mobile/core/config/engineering_team.dart';
import 'package:ipr_mobile/core/config/remote_config_controller.dart';
import 'package:ipr_mobile/core/providers.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:ipr_mobile/shared/widgets/whatsapp_button.dart';
import 'package:material_ui/material_ui.dart';

/// Asesoría técnica / Ingeniería (`/support/engineering`, RF-079, RF-080).
///
/// * Accesible sin iniciar sesión (`AC-079-4`).
/// * Solo canales corporativos configurados desde `/config` (`PA-06`), sin
///   nombres ni teléfonos/correos personales de ingenieros (`AC-080-2`).
/// * El correo intenta abrir `mailto:`; si no hay cliente, copia la dirección
///   y lo informa al usuario (`AC-080-3`).
class EngineeringScreen extends ConsumerWidget {
  const new({super.key});

  Future<void> _callPhone(
    BuildContext context,
    WidgetRef ref,
    String dial,
  ) async {
    final l10n = AppLocalizations.of(context);
    final opened = await ref
        .read(externalLauncherProvider)
        .open(Uri(scheme: 'tel', path: dial));
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.supportHelpCallFailed)));
  }

  Future<void> _writeEmail(
    BuildContext context,
    WidgetRef ref,
    String email,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final opened = await ref
        .read(externalLauncherProvider)
        .open(Uri(scheme: 'mailto', path: email));
    if (opened || !context.mounted) return;
    await Clipboard.setData(ClipboardData(text: email));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(l10n.supportHelpEmailCopied(email))),
      );
  }

  Future<void> _copyEmail(BuildContext context, String email) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: email));
    if (!context.mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(l10n.supportHelpEmailCopied(email))),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final config = ref.watch(remoteConfigProvider.select((s) => s.config));
    final engineeringWa = config.engineeringWhatsapp?.trim();
    final phoneDial = config.phoneDial?.trim();
    final phoneDisplay = config.phoneDisplay?.trim();
    final email = _clean(config.engineeringEmail) ?? _clean(config.salesEmail);
    final specialties = config.engineeringSpecialties;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.supportEngineeringTitle)),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(IprSpace.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.supportEngineeringIntro,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: IprSpace.s4),
              _ServiceCard(
                icon: Icons.ac_unit_outlined,
                title: l10n.supportEngineeringAcTitle,
                body: l10n.supportEngineeringAcBody,
              ),
              const SizedBox(height: IprSpace.s3),
              _ServiceCard(
                icon: Icons.kitchen_outlined,
                title: l10n.supportEngineeringRefTitle,
                body: l10n.supportEngineeringRefBody,
              ),
              const SizedBox(height: IprSpace.s5),
              Semantics(
                header: true,
                child: Text(
                  l10n.supportEngineeringContactTitle,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: IprSpace.s3),
              WhatsAppButton(
                label: l10n.supportEngineeringWhatsapp,
                message: l10n.supportEngineeringWhatsappMsg,
                phoneOverride:
                    (engineeringWa != null && engineeringWa.isNotEmpty)
                    ? engineeringWa
                    : null,
              ),
              if (phoneDial != null && phoneDial.isNotEmpty) ...[
                const SizedBox(height: IprSpace.s3),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: IprSpace.minTapTarget,
                  ),
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        unawaited(_callPhone(context, ref, phoneDial)),
                    icon: const ExcludeSemantics(
                      child: Icon(Icons.phone_outlined),
                    ),
                    label: Text(
                      (phoneDisplay != null && phoneDisplay.isNotEmpty)
                          ? '${l10n.supportEngineeringPhone} ($phoneDisplay)'
                          : l10n.supportEngineeringPhone,
                    ),
                  ),
                ),
              ],
              if (email != null) ...[
                const SizedBox(height: IprSpace.s3),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: IprSpace.minTapTarget,
                  ),
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        unawaited(_writeEmail(context, ref, email)),
                    icon: const ExcludeSemantics(
                      child: Icon(Icons.email_outlined),
                    ),
                    label: Text(l10n.supportEngineeringEmailAction(email)),
                  ),
                ),
                const SizedBox(height: IprSpace.s2),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: IprSpace.minTapTarget,
                  ),
                  child: TextButton.icon(
                    onPressed: () => unawaited(_copyEmail(context, email)),
                    icon: const ExcludeSemantics(
                      child: Icon(Icons.copy_outlined),
                    ),
                    label: Text(l10n.supportEngineeringCopyEmail),
                  ),
                ),
              ],
              if (specialties.isNotEmpty) ...[
                const SizedBox(height: IprSpace.s5),
                Semantics(
                  header: true,
                  child: Text(
                    l10n.supportEngineeringTeamTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: IprSpace.s2),
                Text(
                  l10n.supportEngineeringTeamIntro,
                  style: theme.textTheme.bodyMedium,
                ),
                for (final specialty in specialties) ...[
                  const SizedBox(height: IprSpace.s4),
                  Semantics(
                    header: true,
                    child: Text(
                      specialty.name,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  for (final contact in specialty.contacts) ...[
                    const SizedBox(height: IprSpace.s2),
                    _EngineerContactCard(
                      contact: contact,
                      onWhatsApp: () => unawaited(
                        openWhatsApp(
                          context,
                          ref,
                          message:
                              specialty.whatsappMessage ??
                              l10n.supportEngineeringWhatsappMsg,
                          phoneOverride: contact.whatsapp,
                        ),
                      ),
                      onCall: () => unawaited(
                        _callPhone(context, ref, contact.phoneDial!),
                      ),
                      onEmail: () =>
                          unawaited(_writeEmail(context, ref, contact.email!)),
                    ),
                  ],
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String? _clean(String? raw) {
    final trimmed = raw?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}

class _ServiceCard extends StatelessWidget {
  const new({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(IprSpace.s4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Icon(icon, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: IprSpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: IprSpace.s1),
                  Text(body, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Contacto corporativo de ingeniería en una ciudad (W3-02): la ciudad y un
/// botón por cada canal disponible (WhatsApp, teléfono, correo), de al menos
/// 48 dp y con la ciudad en su etiqueta para el lector de pantalla.
class _EngineerContactCard extends StatelessWidget {
  const new({
    required this.contact,
    required this.onWhatsApp,
    required this.onCall,
    required this.onEmail,
  });

  final EngineeringContact contact;
  final VoidCallback onWhatsApp;
  final VoidCallback onCall;
  final VoidCallback onEmail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    const minSize = Size(IprSpace.minTapTarget, IprSpace.minTapTarget);
    final phone = contact.phoneDisplay;
    final email = contact.email;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(IprSpace.s3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(contact.city, style: theme.textTheme.titleSmall),
            ),
            const SizedBox(height: IprSpace.s2),
            Wrap(
              spacing: IprSpace.s2,
              runSpacing: IprSpace.s2,
              children: [
                if (contact.whatsapp != null)
                  Semantics(
                    label: l10n.supportEngineeringCardWhatsappSemantics(
                      contact.city,
                    ),
                    container: true,
                    button: true,
                    excludeSemantics: true,
                    onTap: onWhatsApp,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: minSize),
                      onPressed: onWhatsApp,
                      icon: const Icon(Icons.chat_outlined),
                      label: Text(l10n.supportEngineeringCardWhatsapp),
                    ),
                  ),
                if (contact.hasPhone && phone != null)
                  Semantics(
                    label: l10n.supportEngineeringCardCallSemantics(
                      contact.city,
                      phone,
                    ),
                    container: true,
                    button: true,
                    excludeSemantics: true,
                    onTap: onCall,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: minSize),
                      onPressed: onCall,
                      icon: const Icon(Icons.phone_outlined),
                      label: Text(phone),
                    ),
                  ),
                if (email != null)
                  Semantics(
                    label: l10n.supportEngineeringCardEmailSemantics(
                      contact.city,
                      email,
                    ),
                    container: true,
                    button: true,
                    excludeSemantics: true,
                    onTap: onEmail,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: minSize),
                      onPressed: onEmail,
                      icon: const Icon(Icons.email_outlined),
                      label: Text(l10n.supportEngineeringCardEmail),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
