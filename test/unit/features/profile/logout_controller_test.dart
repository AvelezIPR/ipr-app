import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/core/session/session_controller.dart';
import 'package:ipr_mobile/core/session/session_remote.dart';
import 'package:ipr_mobile/core/session/session_state.dart';
import 'package:ipr_mobile/core/session/session_tokens.dart';
import 'package:ipr_mobile/core/session/token_store.dart';
import 'package:ipr_mobile/features/profile/presentation/controllers/logout_controller.dart';

import '../../../mocks/fake_session_remote.dart';
import '../../../mocks/memory_secure_key_value.dart';

final class _RecordingHook implements SessionHook {
  int logouts = 0;
  int deletions = 0;

  @override
  Future<void> onLogout() async => logouts++;

  @override
  Future<void> onAccountDeleted() async => deletions++;
}

/// `logout` espera una compuerta y cuenta las llamadas.
final class _GatedRemote implements SessionRemote {
  new(this.gate);

  final Future<void> gate;
  int calls = 0;

  @override
  Future<Result<SessionTokens>> refresh(String refreshToken) async =>
      const Err(NoConnection());

  @override
  Future<Result<void>> logout({
    required String accessToken,
    bool all = false,
  }) async {
    calls++;
    await gate;
    return const Ok(null);
  }
}

/// La primera llamada a `logout` lanza (fallo local); la segunda funciona.
final class _ThrowingOnceRemote implements SessionRemote {
  bool _thrown = false;

  @override
  Future<Result<SessionTokens>> refresh(String refreshToken) async =>
      const Err(NoConnection());

  @override
  Future<Result<void>> logout({
    required String accessToken,
    bool all = false,
  }) async {
    if (!_thrown) {
      _thrown = true;
      throw StateError('fallo local simulado');
    }
    return const Ok(null);
  }
}

void main() {
  late InMemorySecureKeyValue secure;
  late _RecordingHook hook;

  ProviderContainer make(SessionRemote remote) {
    secure = InMemorySecureKeyValue();
    hook = _RecordingHook();
    final container = ProviderContainer(
      overrides: [
        sessionDependenciesProvider.overrideWithValue(
          SessionDependencies(
            tokenStore: TokenStore(secure),
            remote: remote,
            hooks: [hook],
            sleep: (_) async {},
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('M2 · RF-041 · LogoutController', () {
    test(
      'cierra la sesión, revoca una vez y conserva el gancho del carrito',
      () async {
        final remote = FakeSessionRemote();
        final container = make(remote);
        final session = container.read(sessionControllerProvider.notifier);
        await session.setSession(fakeTokens('a'));

        final outcome = await container
            .read(logoutControllerProvider.notifier)
            .logout();

        expect(outcome, LogoutOutcome.done);
        expect(remote.logoutCalls, hasLength(1));
        expect(
          container.read(sessionControllerProvider),
          isA<SessionAnonymous>(),
        );
        expect(hook.logouts, 1);
        expect(
          hook.deletions,
          0,
          reason: 'cerrar sesión NO borra carrito ni caché (CR-040)',
        );
        expect(container.read(logoutControllerProvider), isFalse);
      },
    );

    test('TC-015 · AC-041-6 · sin red cierra localmente y deja la '
        'revocación pendiente', () async {
      final remote = FakeSessionRemote(
        logoutResults: const [Err(NoConnection())],
      );
      final container = make(remote);
      await container
          .read(sessionControllerProvider.notifier)
          .setSession(fakeTokens('a'));

      final outcome = await container
          .read(logoutControllerProvider.notifier)
          .logout();

      expect(outcome, LogoutOutcome.done);
      expect(
        container.read(sessionControllerProvider),
        isA<SessionAnonymous>(),
      );
      expect(await TokenStore(secure).readRefreshToken(), isNull);
      expect(await TokenStore(secure).readPendingRevocation(), 'iprr_a');
    });

    test(
      'TC-014 · AC-041-8 · una segunda llamada en curso se ignora',
      () async {
        final gate = Completer<void>();
        final remote = _GatedRemote(gate.future);
        final container = make(remote);
        await container
            .read(sessionControllerProvider.notifier)
            .setSession(fakeTokens('a'));
        final controller = container.read(logoutControllerProvider.notifier);

        final first = controller.logout();
        expect(container.read(logoutControllerProvider), isTrue);
        expect(await controller.logout(), LogoutOutcome.ignored);

        gate.complete();
        expect(await first, LogoutOutcome.done);
        expect(remote.calls, 1);
        expect(container.read(logoutControllerProvider), isFalse);
      },
    );

    test('un fallo inesperado devuelve failed, conserva la sesión y se '
        'puede reintentar', () async {
      final remote = _ThrowingOnceRemote();
      final container = make(remote);
      await container
          .read(sessionControllerProvider.notifier)
          .setSession(fakeTokens('a'));
      final controller = container.read(logoutControllerProvider.notifier);

      expect(await controller.logout(), LogoutOutcome.failed);
      expect(
        container.read(sessionControllerProvider),
        isA<SessionAuthenticated>(),
      );
      expect(container.read(logoutControllerProvider), isFalse);

      expect(await controller.logout(), LogoutOutcome.done);
      expect(
        container.read(sessionControllerProvider),
        isA<SessionAnonymous>(),
      );
    });
  });
}
