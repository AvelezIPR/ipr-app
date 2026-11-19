import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Delegados de localización de la app.
///
/// Con Flutter 3.50 el código generado por `gen-l10n` referencia los
/// delegados de `flutter_localizations` (Material antiguo), que NO sirven al
/// paquete `material_ui`: Material avisa de que no encuentra su
/// `MaterialLocalizations`. El README de `material_ui` indica usar
/// `GlobalMaterialLocalizations.delegates` de ese paquete; por eso no se usa
/// `AppLocalizations.localizationsDelegates`.
const List<LocalizationsDelegate<dynamic>> iprLocalizationsDelegates = [
  AppLocalizations.delegate,
  ...GlobalMaterialLocalizations.delegates,
];

/// `es_CO` para formatos; los textos de Material caen en `es`.
const Locale iprLocale = Locale('es', 'CO');
