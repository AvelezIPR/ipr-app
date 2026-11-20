import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/core/session/session_controller.dart';
import 'package:ipr_mobile/core/session/session_tokens.dart';
import 'package:ipr_mobile/features/profile/domain/entities/profile_entities.dart';
import 'package:ipr_mobile/features/profile/domain/rules/profile_validation.dart';
import 'package:ipr_mobile/features/profile/presentation/controllers/profile_form_state.dart';
import 'package:ipr_mobile/features/profile/profile_providers.dart';
import 'package:ipr_mobile/shared/widgets/ui_state.dart';

final NotifierProvider<ProfileDataController, UiState<UserProfile>>
profileDataProvider =
    NotifierProvider.autoDispose<ProfileDataController, UiState<UserProfile>>(
      ProfileDataController.new,
    );

/// Carga `GET /me` solo en memoria (RNF-062).
class ProfileDataController extends Notifier<UiState<UserProfile>> {
  RequestCancellation _cancel = RequestCancellation();
  int _generation = 0;

  @override
  UiState<UserProfile> build() {
    ref.onDispose(() => _cancel.cancel());
    unawaited(Future.microtask(load));
    return const UiLoading();
  }

  Future<void> load() async {
    _cancel.cancel();
    _cancel = RequestCancellation();
    final generation = ++_generation;
    state = const UiLoading();
    final result = await ref
        .read(profileRepositoryProvider)
        .getMe(cancellation: _cancel);
    if (!ref.mounted || generation != _generation) return;
    state = switch (result) {
      Ok<UserProfile>(:final value) => UiData(value),
      Err<UserProfile>(:final failure) => UiFailure(failure),
    };
  }

  void updateInMemory(UserProfile profile) {
    if (ref.mounted) state = UiData(profile);
  }
}

final NotifierProvider<ProfileEditController, ProfileFormState>
profileEditProvider =
    NotifierProvider.autoDispose<ProfileEditController, ProfileFormState>(
      ProfileEditController.new,
    );

/// Edita nombre/apellido (`PATCH /me`) y correo (`POST /me/email`).
class ProfileEditController extends Notifier<ProfileFormState> {
  ProfileCooldown? _cooldown;
  RequestCancellation? _inflight;

  @override
  ProfileFormState build() {
    _cooldown = ProfileCooldown(
      onTick: (remaining) {
        if (ref.mounted) state = state.withCooldown(remaining);
      },
    );
    ref.onDispose(() {
      _cooldown?.cancel();
      _inflight?.cancel();
    });
    return const ProfileFormState();
  }

  Future<bool> saveNames({
    required String firstName,
    required String lastName,
  }) async {
    if (!state.canSubmit) return false;
    final issues = ProfileValidation.forNames(
      firstName: firstName,
      lastName: lastName,
    );
    if (issues.isNotEmpty) {
      state = ProfileFormState(fieldIssues: issues);
      return false;
    }
    _inflight?.cancel();
    final cancel = _inflight = RequestCancellation();
    state = const ProfileFormState(submitting: true);

    final result = await ref
        .read(profileRepositoryProvider)
        .updateNames(
          firstName: firstName,
          lastName: lastName,
          cancellation: cancel,
        );
    if (!ref.mounted) return false;
    switch (result) {
      case Ok<UserProfile>(:final value):
        ref.read(profileDataProvider.notifier).updateInMemory(value);
        state = const ProfileFormState(saved: true);
        return true;
      case Err<UserProfile>(:final failure):
        state = mapProfileFailure(failure, startCooldown: _cooldown?.start);
        return false;
    }
  }

  Future<bool> changeEmail({
    required String currentEmail,
    required String newEmail,
    required String currentPassword,
  }) async {
    if (!state.canSubmit) return false;
    final issues = ProfileValidation.forEmailChange(
      currentEmail: currentEmail,
      newEmail: newEmail,
      currentPassword: currentPassword,
    );
    if (issues.isNotEmpty) {
      state = ProfileFormState(fieldIssues: issues);
      return false;
    }
    _inflight?.cancel();
    final cancel = _inflight = RequestCancellation();
    state = const ProfileFormState(submitting: true);

    final result = await ref
        .read(profileRepositoryProvider)
        .changeEmail(
          newEmail: newEmail,
          currentPassword: currentPassword,
          cancellation: cancel,
        );
    if (!ref.mounted) return false;
    switch (result) {
      case Ok<EmailChangeResult>(:final value):
        try {
          await ref
              .read(sessionControllerProvider.notifier)
              .setSession(value.tokens, userId: value.profile.id);
        } on Object {
          if (ref.mounted) {
            state = const ProfileFormState(failure: UnknownFailure());
          }
          return false;
        }
        if (!ref.mounted) return false;
        ref.read(profileDataProvider.notifier).updateInMemory(value.profile);
        state = const ProfileFormState(saved: true);
        return true;
      case Err<EmailChangeResult>(:final failure):
        state = mapProfileFailure(
          failure,
          startCooldown: _cooldown?.start,
          isEmailChange: true,
        );
        return false;
    }
  }
}

final NotifierProvider<ChangePasswordController, ProfileFormState>
changePasswordProvider =
    NotifierProvider.autoDispose<ChangePasswordController, ProfileFormState>(
      ChangePasswordController.new,
    );

/// Cambio de contraseña (`POST /me/password`, RF-105).
class ChangePasswordController extends Notifier<ProfileFormState> {
  ProfileCooldown? _cooldown;
  RequestCancellation? _inflight;

  @override
  ProfileFormState build() {
    _cooldown = ProfileCooldown(
      onTick: (remaining) {
        if (ref.mounted) state = state.withCooldown(remaining);
      },
    );
    ref.onDispose(() {
      _cooldown?.cancel();
      _inflight?.cancel();
    });
    return const ProfileFormState();
  }

  Future<bool> submit({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    if (!state.canSubmit) return false;
    final issues = ProfileValidation.forPasswordChange(
      currentPassword: currentPassword,
      newPassword: newPassword,
      confirmPassword: confirmPassword,
    );
    if (issues.isNotEmpty) {
      state = ProfileFormState(fieldIssues: issues);
      return false;
    }
    _inflight?.cancel();
    final cancel = _inflight = RequestCancellation();
    state = const ProfileFormState(submitting: true);

    final result = await ref
        .read(profileRepositoryProvider)
        .changePassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
          cancellation: cancel,
        );
    if (!ref.mounted) return false;
    switch (result) {
      case Ok<SessionTokens>(:final value):
        try {
          await ref.read(sessionControllerProvider.notifier).setSession(value);
        } on Object {
          if (ref.mounted) {
            state = const ProfileFormState(failure: UnknownFailure());
          }
          return false;
        }
        if (ref.mounted) state = const ProfileFormState(saved: true);
        return true;
      case Err<SessionTokens>(:final failure):
        state = mapProfileFailure(failure, startCooldown: _cooldown?.start);
        return false;
    }
  }
}

final NotifierProvider<AddressEditController, ProfileFormState>
addressEditProvider =
    NotifierProvider.autoDispose<AddressEditController, ProfileFormState>(
      AddressEditController.new,
    );

/// Guarda dirección de facturación o envío (`PUT /me/addresses/{type}`, RF-106).
class AddressEditController extends Notifier<ProfileFormState> {
  ProfileCooldown? _cooldown;
  RequestCancellation? _inflight;

  @override
  ProfileFormState build() {
    _cooldown = ProfileCooldown(
      onTick: (remaining) {
        if (ref.mounted) state = state.withCooldown(remaining);
      },
    );
    ref.onDispose(() {
      _cooldown?.cancel();
      _inflight?.cancel();
    });
    return const ProfileFormState();
  }

  void clearStatus() {
    if (ref.mounted && !state.submitting) {
      state = ProfileFormState(cooldownSeconds: state.cooldownSeconds);
    }
  }

  Future<bool> save({
    required AddressType type,
    required AddressInput input,
  }) async {
    if (!state.canSubmit) return false;
    final issues = ProfileValidation.forAddress(type: type, input: input);
    if (issues.isNotEmpty) {
      state = ProfileFormState(fieldIssues: issues);
      return false;
    }
    _inflight?.cancel();
    final cancel = _inflight = RequestCancellation();
    state = const ProfileFormState(submitting: true);

    final result = await ref
        .read(profileRepositoryProvider)
        .putAddress(type: type, input: input, cancellation: cancel);
    if (!ref.mounted) return false;
    switch (result) {
      case Ok<UserProfile>(:final value):
        ref.read(profileDataProvider.notifier).updateInMemory(value);
        state = const ProfileFormState(saved: true);
        return true;
      case Err<UserProfile>(:final failure):
        state = mapProfileFailure(failure, startCooldown: _cooldown?.start);
        return false;
    }
  }
}
