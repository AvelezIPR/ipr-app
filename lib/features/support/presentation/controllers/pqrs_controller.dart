import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ipr_mobile/core/config/remote_config_controller.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/support/domain/entities/pqrs.dart';
import 'package:ipr_mobile/features/support/domain/rules/pqrs_validation.dart';
import 'package:ipr_mobile/features/support/support_providers.dart';
import 'package:meta/meta.dart';

@immutable
final class PqrsState {
  const new({
    this.submitting = false,
    this.fieldErrors = const {},
    this.failure,
    this.receipt,
  });

  final bool submitting;
  final Map<PqrsField, String> fieldErrors;
  final AppFailure? failure;
  final PqrsReceipt? receipt;

  PqrsState copyWith({
    bool? submitting,
    Map<PqrsField, String>? fieldErrors,
    AppFailure? failure,
    bool clearFailure = false,
    PqrsReceipt? receipt,
    bool clearReceipt = false,
  }) => PqrsState(
    submitting: submitting ?? this.submitting,
    fieldErrors: fieldErrors ?? this.fieldErrors,
    failure: clearFailure ? null : (failure ?? this.failure),
    receipt: clearReceipt ? null : (receipt ?? this.receipt),
  );
}

final NotifierProvider<PqrsController, PqrsState> pqrsControllerProvider =
    NotifierProvider.autoDispose<PqrsController, PqrsState>(PqrsController.new);

/// Controlador de radicación de PQRS (`POST /pqrs`, RF-096/097).
///
/// * Impide doble envío mientras una solicitud está en curso (`AC-096-5`).
/// * Reutiliza la misma `Idempotency-Key` si el usuario reintenta exactamente el
///   mismo borrador tras un error transitorio, y genera una nueva al editar o al
///   recibir confirmación 202.
/// * Nunca persiste datos personales en disco ni en logs (`AC-096-12`).
class PqrsController extends Notifier<PqrsState> {
  RequestCancellation? _inflight;
  String? _draftKey;

  @override
  PqrsState build() {
    ref.onDispose(() => _inflight?.cancel());
    return const PqrsState();
  }

  /// Al cambiar cualquier campo del borrador se limpia el error de ese campo y
  /// se invalida la `Idempotency-Key` previa.
  void clearFieldError(PqrsField field) {
    _draftKey = null;
    if (!state.fieldErrors.containsKey(field) && state.failure == null) {
      return;
    }
    state = state.copyWith(
      fieldErrors: Map.unmodifiable({...state.fieldErrors}..remove(field)),
      clearFailure: true,
    );
  }

  void markDraftEdited() {
    _draftKey = null;
    if (state.receipt != null || state.failure != null) {
      state = state.copyWith(clearReceipt: true, clearFailure: true);
    }
  }

  Future<bool> submit({
    required PqrsType type,
    required String name,
    required String email,
    required String phone,
    required String orderReference,
    required String message,
    required bool acceptsDataPolicy,
  }) async {
    if (state.submitting) return false;

    final errors = PqrsValidation.validate(
      name: name,
      email: email,
      phone: phone,
      orderReference: orderReference,
      message: message,
      acceptsDataPolicy: acceptsDataPolicy,
    );
    if (errors.isNotEmpty) {
      state = state.copyWith(
        fieldErrors: errors,
        clearFailure: true,
        clearReceipt: true,
      );
      return false;
    }

    final submission = PqrsValidation.normalizeSubmission(
      type: type,
      name: name,
      email: email,
      phone: phone,
      orderReference: orderReference,
      message: message,
      acceptsDataPolicy: acceptsDataPolicy,
    );

    _inflight?.cancel();
    final cancel = _inflight = RequestCancellation();
    final key = _draftKey ??= ref.read(supportUuidProvider)();

    state = state.copyWith(
      submitting: true,
      fieldErrors: const {},
      clearFailure: true,
      clearReceipt: true,
    );

    final result = await ref
        .read(pqrsRepositoryProvider)
        .submit(submission: submission, idempotencyKey: key, cancel: cancel);
    if (!ref.mounted) return false;

    switch (result) {
      case Ok<PqrsReceipt>(:final value):
        _draftKey = null;
        state = PqrsState(receipt: value);
        return true;
      case Err<PqrsReceipt>(:final failure):
        // Ante errores definitivos de validación/conflicto se renueva la clave.
        if (!failure.retryable) _draftKey = null;
        state = state.copyWith(submitting: false, failure: failure);
        return false;
    }
  }

  Future<void> refreshConfig() =>
      ref.read(remoteConfigProvider.notifier).refresh();
}
