import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/app/providers.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/core/session/session_controller.dart';
import 'package:ipr_mobile/core/session/session_state.dart';
import 'package:ipr_mobile/core/session/session_tokens.dart';
import 'package:ipr_mobile/features/cart/cart.dart';
import 'package:ipr_mobile/features/profile/domain/entities/profile_entities.dart';
import 'package:ipr_mobile/features/profile/domain/repositories/profile_repository.dart';
import 'package:ipr_mobile/features/profile/domain/rules/profile_validation.dart';
import 'package:ipr_mobile/features/profile/presentation/controllers/delete_account_controller.dart';
import 'package:ipr_mobile/features/profile/presentation/controllers/profile_controllers.dart';
import 'package:ipr_mobile/features/profile/profile_providers.dart';
import 'package:ipr_mobile/shared/widgets/ui_state.dart';

import '../../../mocks/fake_session_remote.dart';
import '../../../mocks/test_providers.dart';

UserProfile _sampleProfile({String email = 'qa@example.test'}) => UserProfile(
  id: 42,
  email: email,
  firstName: 'Ana',
  lastName: 'Prueba',
  displayName: 'Ana Prueba',
);

final class _FakeProfileRepository implements ProfileRepository {
  int updateNamesCalls = 0;
  int changeEmailCalls = 0;
  int changePasswordCalls = 0;
  int putAddressCalls = 0;
  int deletionCalls = 0;
  String? lastIdempotencyKey;

  FutureOr<Result<UserProfile>> Function()? onGetMe;
  FutureOr<Result<UserProfile>> Function()? onUpdateNames;
  FutureOr<Result<EmailChangeResult>> Function()? onChangeEmail;
  FutureOr<Result<SessionTokens>> Function()? onChangePassword;
  FutureOr<Result<UserProfile>> Function(AddressType, AddressInput)?
  onPutAddress;
  FutureOr<Result<AccountDeletionStatus>> Function()? onDeletion;

  @override
  Future<Result<UserProfile>> getMe({
    RequestCancellation? cancellation,
  }) async => await onGetMe?.call() ?? Ok(_sampleProfile());

  @override
  Future<Result<UserProfile>> updateNames({
    required String firstName,
    required String lastName,
    RequestCancellation? cancellation,
  }) async {
    updateNamesCalls++;
    return await onUpdateNames?.call() ?? Ok(_sampleProfile());
  }

  @override
  Future<Result<EmailChangeResult>> changeEmail({
    required String newEmail,
    required String currentPassword,
    RequestCancellation? cancellation,
  }) async {
    changeEmailCalls++;
    return await onChangeEmail?.call() ??
        Ok(
          EmailChangeResult(
            tokens: fakeTokens('new_email'),
            profile: _sampleProfile(email: newEmail),
          ),
        );
  }

  @override
  Future<Result<SessionTokens>> changePassword({
    required String currentPassword,
    required String newPassword,
    RequestCancellation? cancellation,
  }) async {
    changePasswordCalls++;
    return await onChangePassword?.call() ?? Ok(fakeTokens('new_pass'));
  }

  @override
  Future<Result<UserProfile>> putAddress({
    required AddressType type,
    required AddressInput input,
    RequestCancellation? cancellation,
  }) async {
    putAddressCalls++;
    return await onPutAddress?.call(type, input) ?? Ok(_sampleProfile());
  }

  @override
  Future<Result<AccountDeletionStatus>> requestDeletion({
    required String currentPassword,
    required String idempotencyKey,
    RequestCancellation? cancellation,
  }) async {
    deletionCalls++;
    lastIdempotencyKey = idempotencyKey;
    return await onDeletion?.call() ??
        Ok(
          AccountDeletionStatus(
            requestId: 'req-1',
            status: AccountDeletionState.scheduled,
            completeBy: DateTime.utc(2026, 12, 10),
          ),
        );
  }
}

Future<ProviderContainer> _container(_FakeProfileRepository repo) async {
  final c = ProviderContainer(
    overrides: testOverrides(
      extra: [
        ...integrationOverrides(),
        profileRepositoryProvider.overrideWithValue(repo),
        profileUuidProvider.overrideWithValue(
          () => '11111111-1111-4111-8111-111111111111',
        ),
      ],
    ),
  );
  addTearDown(c.dispose);
  await c
      .read(sessionControllerProvider.notifier)
      .setSession(fakeTokens('initial'), userId: 42);
  return c;
}

void main() {
  group('TC-093 · TC-094 · ProfileEditController y ChangePasswordController', () {
    test(
      'AC-104-4 · cambio de correo rota el token en sesión y actualiza perfil',
      () async {
        final repo = _FakeProfileRepository();
        final c = await _container(repo);
        c.listen(profileDataProvider, (_, _) {});
        await Future<void>.delayed(Duration.zero);

        final ok = await c
            .read(profileEditProvider.notifier)
            .changeEmail(
              currentEmail: 'qa@example.test',
              newEmail: 'nuevo@example.test',
              currentPassword: 'QaPassword123',
            );
        expect(ok, isTrue);
        expect(
          c.read(sessionControllerProvider.notifier).accessToken,
          fakeTokens('new_email').accessToken,
        );
        expect(
          (c.read(profileDataProvider) as UiData<UserProfile>).value.email,
          'nuevo@example.test',
        );
      },
    );

    test(
      'TC-098 · AC-104-6 · 409 email_in_use marca conflicto neutral',
      () async {
        final repo = _FakeProfileRepository()
          ..onChangeEmail = () => const Err(Conflict(code: 'email_in_use'));
        final c = await _container(repo);

        final ok = await c
            .read(profileEditProvider.notifier)
            .changeEmail(
              currentEmail: 'qa@example.test',
              newEmail: 'otro@example.test',
              currentPassword: 'QaPassword123',
            );
        expect(ok, isFalse);
        expect(c.read(profileEditProvider).emailConflict, isTrue);
      },
    );

    test('AC-104-8 · AC-105-8 · doble toque mientras está en curso emite una sola solicitud', () async {
      final gate = Completer<Result<SessionTokens>>();
      final repo = _FakeProfileRepository()
        ..onChangePassword = () => gate.future;
      final c = await _container(repo);
      final ctrl = c.read(changePasswordProvider.notifier);

      final first = ctrl.submit(
        currentPassword: 'OldPassword123',
        newPassword: 'NewPassword123',
        confirmPassword: 'NewPassword123',
      );
      final second = await ctrl.submit(
        currentPassword: 'OldPassword123',
        newPassword: 'NewPassword123',
        confirmPassword: 'NewPassword123',
      );
      expect(second, isFalse);
      expect(repo.changePasswordCalls, 1);

      gate.complete(Ok(fakeTokens('rotated')));
      expect(await first, isTrue);
      expect(
        c.read(sessionControllerProvider.notifier).accessToken,
        fakeTokens('rotated').accessToken,
      );
    });

    test('AC-105-6 · 429 inicia cuenta regresiva y bloquea envío', () async {
      final repo = _FakeProfileRepository()
        ..onChangePassword = () => const Err(RateLimited(retryAfter: 5));
      final c = await _container(repo);
      final ctrl = c.read(changePasswordProvider.notifier);

      final ok = await ctrl.submit(
        currentPassword: 'OldPassword123',
        newPassword: 'NewPassword123',
        confirmPassword: 'NewPassword123',
      );
      expect(ok, isFalse);
      expect(c.read(changePasswordProvider).coolingDown, isTrue);
      expect(
        await ctrl.submit(
          currentPassword: 'OldPassword123',
          newPassword: 'NewPassword123',
          confirmPassword: 'NewPassword123',
        ),
        isFalse,
      );
      expect(repo.changePasswordCalls, 1);
    });
  });

  group('TC-087 · TC-089 · TC-091 · DeleteAccountController y H-07', () {
    test('sin confirmación o sin contraseña no emite solicitud', () async {
      final repo = _FakeProfileRepository();
      final c = await _container(repo);
      final ok = await c
          .read(deleteAccountProvider.notifier)
          .submit(confirmed: false, currentPassword: '');
      expect(ok, isFalse);
      expect(repo.deletionCalls, 0);
      expect(c.read(deleteAccountProvider).fieldIssues, {
        ProfileField.deleteConfirm: ProfileFieldIssue.confirmationRequired,
        ProfileField.currentPassword: ProfileFieldIssue.required,
      });
    });

    test(
      'H-07 · CR-040 · 202 revoca sesión local y borra el carrito',
      () async {
        final repo = _FakeProfileRepository();
        final c = await _container(repo);
        await c.read(cartProvider.notifier).add(7, 2);
        expect(c.read(cartProvider).lines, hasLength(1));

        final ok = await c
            .read(deleteAccountProvider.notifier)
            .submit(confirmed: true, currentPassword: 'QaPassword123');
        expect(ok, isTrue);
        expect(repo.lastIdempotencyKey, '11111111-1111-4111-8111-111111111111');
        expect(c.read(sessionControllerProvider), isA<SessionAnonymous>());
        expect(c.read(cartProvider).lines, isEmpty);
      },
    );

    test(
      'TC-091 · AC-110-9 · error de red conserva sesión y carrito activos',
      () async {
        final repo = _FakeProfileRepository()
          ..onDeletion = () => const Err(NoConnection());
        final c = await _container(repo);
        await c.read(cartProvider.notifier).add(7, 2);

        final ok = await c
            .read(deleteAccountProvider.notifier)
            .submit(confirmed: true, currentPassword: 'QaPassword123');
        expect(ok, isFalse);
        expect(c.read(sessionControllerProvider), isA<SessionAuthenticated>());
        expect(c.read(cartProvider).lines, hasLength(1));
      },
    );
  });
}
