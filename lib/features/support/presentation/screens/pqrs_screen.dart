import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ipr_mobile/core/config/remote_config_controller.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/features/support/domain/entities/pqrs.dart';
import 'package:ipr_mobile/features/support/domain/rules/pqrs_validation.dart';
import 'package:ipr_mobile/features/support/presentation/controllers/pqrs_controller.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/tokens/spacing_tokens.dart';
import 'package:ipr_mobile/shared/navigation/routes.dart';
import 'package:ipr_mobile/shared/widgets/failure_messages.dart';
import 'package:ipr_mobile/shared/widgets/state_widgets.dart';
import 'package:material_ui/material_ui.dart';

/// Formulario de PQRS (`/support/pqrs`, RF-096, RF-097).
///
/// * Accesible sin sesión (`AC-096-10`), pero apagado por defecto mientras
///   `pqrsEnabled` sea falso en `/config`.
/// * Sin almacenamiento en disco ni logs (`AC-096-12`).
/// * Limpia todos los campos al confirmarse HTTP 202 y conserva lo escrito ante
///   sin red, 429 o 5xx (`AC-096-4..8`).
class PqrsScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final enabled = ref.watch(
      remoteConfigProvider.select((s) => s.config.pqrsEnabled),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.supportPqrsTitle)),
      body: SafeArea(
        top: false,
        child: enabled ? const _PqrsFormBody() : const _PqrsDisabledView(),
      ),
    );
  }
}

class _PqrsDisabledView extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return EmptyState(
      title: l10n.supportPqrsDisabledTitle,
      body: l10n.supportPqrsDisabledBody,
      action: FilledButton(
        onPressed: () => unawaited(
          ref.read(pqrsControllerProvider.notifier).refreshConfig(),
        ),
        child: Text(l10n.supportPqrsRetryConfig),
      ),
    );
  }
}

class _PqrsFormBody extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_PqrsFormBody> createState() => _PqrsFormBodyState();
}

class _PqrsFormBodyState extends ConsumerState<_PqrsFormBody> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _orderRef = TextEditingController();
  final _message = TextEditingController();
  PqrsType _type = PqrsType.peticion;
  bool _acceptsDataPolicy = false;

  @override
  void initState() {
    super.initState();
    _message.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _orderRef.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final controller = ref.read(pqrsControllerProvider.notifier);
    final ok = await controller.submit(
      type: _type,
      name: _name.text,
      email: _email.text,
      phone: _phone.text,
      orderReference: _orderRef.text,
      message: _message.text,
      acceptsDataPolicy: _acceptsDataPolicy,
    );
    if (!ok || !mounted) return;
    _name.clear();
    _email.clear();
    _phone.clear();
    _orderRef.clear();
    _message.clear();
    setState(() {
      _type = PqrsType.peticion;
      _acceptsDataPolicy = false;
    });
  }

  static String _typeLabel(AppLocalizations l10n, PqrsType type) =>
      switch (type) {
        PqrsType.peticion => l10n.supportPqrsTypePeticion,
        PqrsType.queja => l10n.supportPqrsTypeQueja,
        PqrsType.reclamo => l10n.supportPqrsTypeReclamo,
        PqrsType.sugerencia => l10n.supportPqrsTypeSugerencia,
      };

  static String _failureText(AppLocalizations l10n, AppFailure failure) =>
      switch (failure) {
        RateLimited() => l10n.supportPqrsErrorRateLimit,
        ServerFailure() ||
        ServiceUnavailable() ||
        ContractFailure() ||
        UnknownFailure() => l10n.supportPqrsErrorServer,
        _ => failureText(l10n, failure),
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(pqrsControllerProvider);
    final controller = ref.read(pqrsControllerProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(IprSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.receipt != null) ...[
            Semantics(
              liveRegion: true,
              child: Card(
                color: theme.colorScheme.primaryContainer,
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(IprSpace.s4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.supportPqrsSuccessTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: IprSpace.s1),
                      Text(
                        l10n.supportPqrsSuccessBody,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: IprSpace.s4),
          ],
          Text(l10n.supportPqrsIntro, style: theme.textTheme.bodyMedium),
          const SizedBox(height: IprSpace.s4),
          DropdownButtonFormField<PqrsType>(
            initialValue: _type,
            decoration: InputDecoration(labelText: l10n.supportPqrsTypeLabel),
            items: [
              for (final value in PqrsType.values)
                DropdownMenuItem(
                  value: value,
                  child: Text(_typeLabel(l10n, value)),
                ),
            ],
            onChanged: state.submitting
                ? null
                : (value) {
                    if (value == null) return;
                    setState(() => _type = value);
                    controller.markDraftEdited();
                  },
          ),
          const SizedBox(height: IprSpace.s3),
          TextField(
            controller: _name,
            enabled: !state.submitting,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: l10n.supportPqrsNameLabel,
              errorText: state.fieldErrors[PqrsField.name] == null
                  ? null
                  : l10n.supportPqrsErrorName,
            ),
            onChanged: (_) => controller.clearFieldError(PqrsField.name),
          ),
          const SizedBox(height: IprSpace.s3),
          TextField(
            controller: _email,
            enabled: !state.submitting,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: l10n.supportPqrsEmailLabel,
              errorText: state.fieldErrors[PqrsField.email] == null
                  ? null
                  : l10n.supportPqrsErrorEmail,
            ),
            onChanged: (_) => controller.clearFieldError(PqrsField.email),
          ),
          const SizedBox(height: IprSpace.s3),
          TextField(
            controller: _phone,
            enabled: !state.submitting,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: l10n.supportPqrsPhoneLabel,
              errorText: state.fieldErrors[PqrsField.phone] == null
                  ? null
                  : l10n.supportPqrsErrorPhone,
            ),
            onChanged: (_) => controller.clearFieldError(PqrsField.phone),
          ),
          const SizedBox(height: IprSpace.s3),
          TextField(
            controller: _orderRef,
            enabled: !state.submitting,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: l10n.supportPqrsOrderRefLabel,
              errorText: state.fieldErrors[PqrsField.orderReference] == null
                  ? null
                  : l10n.supportPqrsErrorOrderRef,
            ),
            onChanged: (_) =>
                controller.clearFieldError(PqrsField.orderReference),
          ),
          const SizedBox(height: IprSpace.s3),
          TextField(
            controller: _message,
            enabled: !state.submitting,
            maxLines: 4,
            maxLength: PqrsValidation.maxMessageLength,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            decoration: InputDecoration(
              labelText: l10n.supportPqrsMessageLabel,
              counterText: l10n.supportPqrsMessageCounter(
                _message.text.length,
                PqrsValidation.maxMessageLength,
              ),
              errorText: state.fieldErrors[PqrsField.message] == null
                  ? null
                  : l10n.supportPqrsErrorMessage,
            ),
            onChanged: (_) => controller.clearFieldError(PqrsField.message),
          ),
          const SizedBox(height: IprSpace.s2),
          CheckboxListTile(
            value: _acceptsDataPolicy,
            enabled: !state.submitting,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(l10n.supportPqrsDataPolicyLabel),
            onChanged: (checked) {
              setState(() => _acceptsDataPolicy = checked ?? false);
              controller.clearFieldError(PqrsField.dataPolicy);
            },
          ),
          if (state.fieldErrors[PqrsField.dataPolicy] != null)
            Padding(
              padding: const EdgeInsets.only(bottom: IprSpace.s2),
              child: Text(
                l10n.supportPqrsErrorDataPolicy,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: IprSpace.minTapTarget,
              ),
              child: TextButton(
                onPressed: () => unawaited(context.push(Routes.legal)),
                child: Text(l10n.supportPqrsDataPolicyLink),
              ),
            ),
          ),
          if (state.failure case final failure?) ...[
            const SizedBox(height: IprSpace.s2),
            Semantics(
              liveRegion: true,
              child: Text(
                _failureText(l10n, failure),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          ],
          const SizedBox(height: IprSpace.s4),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: IprSpace.minTapTarget),
            child: FilledButton(
              onPressed: state.submitting ? null : () => unawaited(_submit()),
              child: Text(
                state.submitting
                    ? l10n.supportPqrsSubmitting
                    : l10n.supportPqrsSubmit,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
