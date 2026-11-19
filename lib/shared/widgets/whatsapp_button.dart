import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ipr_mobile/core/config/remote_config_controller.dart';
import 'package:ipr_mobile/core/external/external_launcher.dart';
import 'package:ipr_mobile/core/providers.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Texto máximo del término de búsqueda en el mensaje (evita enlaces enormes).
const whatsAppMaxTermLength = 100;

/// Recorta y limpia un texto escrito por el usuario antes de ponerlo en un
/// mensaje de WhatsApp.
String sanitizeWhatsAppTerm(String raw) {
  final collapsed = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  return collapsed.length <= whatsAppMaxTermLength
      ? collapsed
      : collapsed.substring(0, whatsAppMaxTermLength);
}

/// Número de WhatsApp vigente: el de `/config` y, mientras no se haya cargado,
/// el público de respaldo del flavor.
String whatsAppNumberOf(WidgetRef ref) {
  final remote = ref.read(remoteConfigProvider).config.whatsappNumber;
  return (remote == null || remote.isEmpty)
      ? ref.read(appConfigProvider).supportWhatsApp
      : remote;
}

/// Abre WhatsApp con [message]; si no se puede (RF-063) ofrece llamar a la
/// línea de atención o abrir la versión web.
Future<void> openWhatsApp(
  BuildContext context,
  WidgetRef ref, {
  required String message,
}) async {
  final number = whatsAppNumberOf(ref);
  final launcher = ref.read(externalLauncherProvider);
  final opened = await launcher.open(whatsAppUri(number, text: message));
  if (opened || !context.mounted) return;

  final dial = ref.read(remoteConfigProvider).config.phoneDial;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final l10n = AppLocalizations.of(dialogContext);
      return AlertDialog(
        title: Text(l10n.sharedWhatsappOpenFailedTitle),
        content: Text(l10n.sharedWhatsappOpenFailedBody),
        actions: [
          if (dial != null && dial.isNotEmpty)
            TextButton(
              onPressed: () {
                unawaited(launcher.open(Uri(scheme: 'tel', path: dial)));
                Navigator.of(dialogContext).pop();
              },
              child: Text(l10n.sharedWhatsappCall),
            ),
          TextButton(
            onPressed: () {
              final web = Uri.https('api.whatsapp.com', '/send', {
                'phone': number.replaceAll(RegExp('[^0-9]'), ''),
                if (message.isNotEmpty) 'text': message,
              });
              unawaited(launcher.open(web));
              Navigator.of(dialogContext).pop();
            },
            child: Text(l10n.sharedWhatsappWeb),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.sharedWhatsappClose),
          ),
        ],
      );
    },
  );
}

/// Botón que abre WhatsApp con un mensaje prellenado. Un solo objetivo táctil
/// de al menos 48 dp; texto + ícono (RNF-076).
class WhatsAppButton extends ConsumerWidget {
  const new({
    required this.label,
    required this.message,
    super.key,
    this.filled = true,
    this.expand = true,
  });

  final String label;
  final String message;

  /// Primario (relleno) o secundario (contorno).
  final bool filled;

  /// Ocupa todo el ancho disponible (formularios y llamadas a la acción).
  final bool expand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void onPressed() => unawaited(openWhatsApp(context, ref, message: message));
    const icon = ExcludeSemantics(child: Icon(Icons.chat_outlined));
    final text = Flexible(child: Text(label, textAlign: TextAlign.center));
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: IprSpace.s2),
        text,
      ],
    );
    final button = filled
        ? FilledButton(onPressed: onPressed, child: content)
        : OutlinedButton(onPressed: onPressed, child: content);
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
