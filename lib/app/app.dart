import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ipr_mobile/app/router/app_router.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/ipr_localizations.dart';
import 'package:ipr_mobile/shared/design_system/ipr_theme.dart';
import 'package:material_ui/material_ui.dart';

/// Raíz de la app: tema desde tokens, localización es-CO y router.
///
/// No se limita el factor de escala del texto (hasta 200 %, RNF-068).
class IprApp extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: IprTheme.light(),
      routerConfig: router,
      locale: iprLocale,
      localizationsDelegates: iprLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      debugShowCheckedModeBanner: false,
    );
  }
}
