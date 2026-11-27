import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ipr_mobile/core/config/home_content.dart';
import 'package:ipr_mobile/core/config/remote_config_controller.dart';
import 'package:ipr_mobile/core/providers.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/navigation/routes.dart';
import 'package:ipr_mobile/shared/widgets/whatsapp_button.dart';
import 'package:material_ui/material_ui.dart';

/// ¿Se puede ofrecer este destino ahora? La calculadora de BTU depende de un
/// interruptor del servidor (D-08): apagada, ningún banner debe llevar a ella.
bool isHomeTargetAvailable(HomeTarget target, {required bool btuEnabled}) =>
    target.kind != HomeTargetKind.calculator || btuEnabled;

/// Lleva al destino de un banner o bloque de la portada (W2).
///
/// * Pantallas propias: se navega con las rutas de la app, nunca con cadenas
///   del servidor (el `ref` ya llegó validado como slug).
/// * `web`: se abre en el navegador del sistema **solo** si la política de
///   enlaces externos lo permite (https y el dominio de IPR, SC-036): las
///   campañas con ruleta o raspa viven en WordPress y no se portan.
/// * `whatsapp`: el asesor con el mensaje que indica la campaña.
Future<void> openHomeTarget(
  BuildContext context,
  WidgetRef ref,
  HomeTarget target,
) async {
  final reference = target.ref ?? '';
  switch (target.kind) {
    case HomeTargetKind.category:
      unawaited(context.push(Routes.categoryList(reference)));
    case HomeTargetKind.product:
      unawaited(context.push(Routes.product(reference)));
    case HomeTargetKind.brand:
      unawaited(context.push(Routes.brand(reference)));
    case HomeTargetKind.sale:
      unawaited(context.push(Routes.sale));
    case HomeTargetKind.branches:
      unawaited(context.push(Routes.branches));
    case HomeTargetKind.engineering:
      unawaited(context.push(Routes.engineering));
    case HomeTargetKind.support:
      unawaited(context.push(Routes.support));
    case HomeTargetKind.calculator:
      if (ref.read(remoteConfigProvider).config.btuCalculatorEnabled) {
        unawaited(context.push(Routes.btu));
      }
    case HomeTargetKind.whatsapp:
      await openWhatsApp(context, ref, message: reference);
    case HomeTargetKind.web:
      final uri = Uri.tryParse(reference);
      final opened =
          uri != null && await ref.read(externalLauncherProvider).open(uri);
      if (opened || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).homeLinkFailed)),
      );
  }
}
