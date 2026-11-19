import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Esqueleto estático de una sección que carga (sin animación: respeta
/// "reducir movimiento", RNF-074). El buscador y WhatsApp no dependen de la
/// red, así que ya son operativos mientras tanto.
class SectionSkeleton extends StatelessWidget {
  const new({required this.title, required this.height, super.key});

  final String title;
  final double height;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      container: true,
      liveRegion: true,
      label: l10n.homeSectionLoadingSemantics(title),
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(IprRadius.xl),
          ),
          child: SizedBox(height: height, width: double.infinity),
        ),
      ),
    );
  }
}
