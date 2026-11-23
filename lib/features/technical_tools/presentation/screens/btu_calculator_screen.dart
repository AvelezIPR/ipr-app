import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ipr_mobile/core/config/remote_config_controller.dart';
import 'package:ipr_mobile/features/technical_tools/domain/entities/btu_models.dart';
import 'package:ipr_mobile/features/technical_tools/domain/rules/btu_calculator.dart';
import 'package:ipr_mobile/features/technical_tools/presentation/controllers/btu_calculator_controller.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:ipr_mobile/shared/navigation/routes.dart';
import 'package:ipr_mobile/shared/widgets/state_widgets.dart';
import 'package:ipr_mobile/shared/widgets/whatsapp_button.dart';
import 'package:material_ui/material_ui.dart';

/// Calculadora de capacidad térmica en BTU (`/tools/btu`, RF-085..089).
///
/// Funciona sin sesión ni red (AC-085-7), pero permanece detrás del interruptor
/// remoto `btuCalculatorEnabled` (D-08, falla cerrado).
class BtuCalculatorScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final enabled = ref.watch(
      remoteConfigProvider.select((s) => s.config.btuCalculatorEnabled),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.technicalToolsBtuTitle)),
      body: SafeArea(
        top: false,
        child: enabled
            ? const _BtuCalculatorBody()
            : EmptyState(
                title: l10n.technicalToolsBtuDisabledTitle,
                body: l10n.technicalToolsBtuDisabledBody,
              ),
      ),
    );
  }
}

class _BtuCalculatorBody extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_BtuCalculatorBody> createState() => _BtuCalculatorBodyState();
}

class _BtuCalculatorBodyState extends ConsumerState<_BtuCalculatorBody> {
  final _length = TextEditingController();
  final _width = TextEditingController();
  final _height = TextEditingController();
  final _occupants = TextEditingController();
  final _equipment = TextEditingController();

  @override
  void dispose() {
    _length.dispose();
    _width.dispose();
    _height.dispose();
    _occupants.dispose();
    _equipment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(btuCalculatorProvider);
    final controller = ref.read(btuCalculatorProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(IprSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.technicalToolsBtuIntro, style: theme.textTheme.bodyMedium),
          const SizedBox(height: IprSpace.s4),
          _DecimalField(
            controller: _length,
            label: l10n.technicalToolsBtuLengthLabel,
            errorText: state.errors[BtuInputField.length] == null
                ? null
                : l10n.technicalToolsBtuErrorLength,
            onChanged: controller.setLength,
          ),
          const SizedBox(height: IprSpace.s3),
          _DecimalField(
            controller: _width,
            label: l10n.technicalToolsBtuWidthLabel,
            errorText: state.errors[BtuInputField.width] == null
                ? null
                : l10n.technicalToolsBtuErrorWidth,
            onChanged: controller.setWidth,
          ),
          const SizedBox(height: IprSpace.s3),
          _DecimalField(
            controller: _height,
            label: l10n.technicalToolsBtuHeightLabel,
            errorText: state.errors[BtuInputField.height] == null
                ? null
                : l10n.technicalToolsBtuErrorHeight,
            onChanged: controller.setHeight,
          ),
          const SizedBox(height: IprSpace.s3),
          _IntegerField(
            controller: _occupants,
            label: l10n.technicalToolsBtuOccupantsLabel,
            errorText: state.errors[BtuInputField.occupants] == null
                ? null
                : l10n.technicalToolsBtuErrorOccupants,
            onChanged: controller.setOccupants,
          ),
          const SizedBox(height: IprSpace.s3),
          _IntegerField(
            controller: _equipment,
            label: l10n.technicalToolsBtuEquipmentLabel,
            errorText: state.errors[BtuInputField.equipment] == null
                ? null
                : l10n.technicalToolsBtuErrorEquipment,
            onChanged: controller.setEquipment,
          ),
          const SizedBox(height: IprSpace.s3),
          DropdownButtonFormField<ClimateZone>(
            initialValue: state.climate,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l10n.technicalToolsBtuClimateLabel,
            ),
            items: [
              for (final zone in ClimateZone.values)
                DropdownMenuItem(
                  value: zone,
                  child: Text(_climateLabel(l10n, zone)),
                ),
            ],
            onChanged: (zone) {
              if (zone != null) controller.setClimate(zone);
            },
          ),
          const SizedBox(height: IprSpace.s4),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: IprSpace.minTapTarget),
            child: FilledButton(
              onPressed: controller.calculate,
              child: Text(l10n.technicalToolsBtuCalculate),
            ),
          ),
          if (state.result case final result?) ...[
            const SizedBox(height: IprSpace.s5),
            _BtuResultSection(result: result),
          ],
        ],
      ),
    );
  }

  static String _climateLabel(AppLocalizations l10n, ClimateZone zone) =>
      switch (zone) {
        ClimateZone.cold => l10n.technicalToolsBtuClimateCold,
        ClimateZone.temperate => l10n.technicalToolsBtuClimateTemperate,
        ClimateZone.warm => l10n.technicalToolsBtuClimateWarm,
      };
}

class _DecimalField extends StatelessWidget {
  const new({
    required this.controller,
    required this.label,
    required this.errorText,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? errorText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(
      labelText: label,
      errorText: errorText,
      errorMaxLines: 4,
    ),
    onChanged: onChanged,
  );
}

class _IntegerField extends StatelessWidget {
  const new({
    required this.controller,
    required this.label,
    required this.errorText,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String? errorText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9+-.,]'))],
    decoration: InputDecoration(
      labelText: label,
      errorText: errorText,
      errorMaxLines: 4,
    ),
    onChanged: onChanged,
  );
}

class _BtuResultSection extends ConsumerWidget {
  const new({required this.result});

  final BtuResult result;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final formattedRequired = BtuCalculator.formatThousands(result.requiredBtu);
    final suggested = result.suggestedCapacity;
    final filterSlug = result.filterSlug;

    return Semantics(
      liveRegion: true,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(IprSpace.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                container: true,
                child: Text(
                  l10n.technicalToolsBtuResultTitle,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: IprSpace.s3),
              Text(
                l10n.technicalToolsBtuRequiredLabel,
                style: theme.textTheme.labelMedium,
              ),
              Text(
                l10n.technicalToolsBtuValueFormat(formattedRequired),
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: IprSpace.s3),
              if (suggested != null && filterSlug != null) ...[
                Text(
                  l10n.technicalToolsBtuSuggestedLabel,
                  style: theme.textTheme.labelMedium,
                ),
                Text(
                  l10n.technicalToolsBtuValueFormat(
                    BtuCalculator.formatThousands(suggested),
                  ),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: IprSpace.s4),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: IprSpace.minTapTarget,
                  ),
                  child: FilledButton.icon(
                    onPressed: () => unawaited(
                      context.push(Routes.btuCatalogList(filterSlug)),
                    ),
                    icon: const ExcludeSemantics(child: Icon(Icons.search)),
                    label: Text(l10n.technicalToolsBtuViewProducts),
                  ),
                ),
              ] else ...[
                Text(
                  l10n.technicalToolsBtuOverMaxTitle(
                    BtuCalculator.formatThousands(
                      BtuCalculator.commercialCapacities.last,
                    ),
                  ),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: IprSpace.s1),
                Text(
                  l10n.technicalToolsBtuOverMaxBody,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: IprSpace.s3),
                WhatsAppButton(
                  label: l10n.technicalToolsBtuContactAdvisor,
                  message: l10n.technicalToolsBtuAdvisorMsg(formattedRequired),
                ),
              ],
              const Divider(height: IprSpace.s5),
              Text(
                l10n.technicalToolsBtuNotice,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
