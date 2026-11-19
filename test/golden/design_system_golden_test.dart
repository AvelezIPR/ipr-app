// `goldenTest` registra la prueba y devuelve un Future que no hay que esperar
// (patrón documentado de alchemist), por eso se ignora `discarded_futures`.
// ignore_for_file: discarded_futures

import 'package:alchemist/alchemist.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/ipr_localizations.dart';
import 'package:ipr_mobile/shared/design_system/ipr_theme.dart';
import 'package:ipr_mobile/shared/domain/money.dart';
import 'package:ipr_mobile/shared/domain/price_status.dart';
import 'package:ipr_mobile/shared/domain/stock_status.dart';
import 'package:ipr_mobile/shared/widgets/price_widgets.dart';
import 'package:ipr_mobile/shared/widgets/state_widgets.dart';
import 'package:material_ui/material_ui.dart';

/// Monta [child] con el tema y la localización de la app a una escala de texto.
///
/// `alchemist` usa el Material antiguo; el tema de la app es el de
/// `material_ui`, por eso cada escenario lleva su propio `MaterialApp`.
Widget _scene(Widget child, {required double textScale}) => SizedBox(
  width: 360,
  height: 280,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: IprTheme.light(),
    locale: iprLocale,
    localizationsDelegates: iprLocalizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, app) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: app!,
    ),
    home: Scaffold(
      body: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  ),
);

void main() {
  // Solo goldens "CI" (independientes de la plataforma): se pueden generar y
  // comparar en cualquier sistema operativo.
  AlchemistConfig.runWithConfig(
    config: const AlchemistConfig(
      platformGoldensConfig: PlatformGoldensConfig(enabled: false),
    ),
    run: () {
      for (final scale in [1.0, 2.0]) {
        goldenTest(
          'Design system a escala de texto $scale',
          fileName: 'design_system_x${scale.toStringAsFixed(1)}',
          builder: () => GoldenTestGroup(
            children: [
              GoldenTestScenario(
                name: 'precio con IVA',
                child: _scene(
                  const PriceText(price: Priced(Money(1445000))),
                  textScale: scale,
                ),
              ),
              GoldenTestScenario(
                name: r'sin precio (nunca $0)',
                child: _scene(
                  const PriceText(price: OnRequest()),
                  textScale: scale,
                ),
              ),
              GoldenTestScenario(
                name: 'en stock',
                child: _scene(
                  const StockBadge(stock: StockStatus.inStock),
                  textScale: scale,
                ),
              ),
              GoldenTestScenario(
                name: 'agotado',
                child: _scene(
                  const StockBadge(stock: StockStatus.outOfStock),
                  textScale: scale,
                ),
              ),
              GoldenTestScenario(
                name: 'error de red con Reintentar',
                child: _scene(
                  ErrorState(failure: const NoConnection(), onRetry: () {}),
                  textScale: scale,
                ),
              ),
              GoldenTestScenario(
                name: 'datos guardados',
                child: _scene(const StaleBanner(), textScale: scale),
              ),
            ],
          ),
        );
      }
    },
  );
}
