import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/core/network/uuid_v4.dart';
import 'package:ipr_mobile/core/session/session_controller.dart';
import 'package:ipr_mobile/core/session/session_gateway.dart';
import 'package:ipr_mobile/core/session/session_state.dart';
import 'package:ipr_mobile/core/session/session_tokens.dart';
import 'package:ipr_mobile/core/session/token_store.dart';
import 'package:ipr_mobile/core/storage/secure_key_value.dart';

import '../../../mocks/fake_session_remote.dart';
import '../../../mocks/memory_secure_key_value.dart';

final class RecordingHook implements SessionHook {
  int logouts = 0;
  int deletions = 0;
  @override
  Future<void> onLogout() async => logouts++;
  @override
  Future<void> onAccountDeleted() async => deletions++;
}

class Harness {
  new({
    FakeSessionRemote? remote,
    Map<String, String>? secureData,
    Duration clockStep = Duration.zero,
  }) : secure = InMemorySecureKeyValue(secureData),
       remote = remote ?? FakeSessionRemote() {
    var tick = DateTime.utc(2026, 11, 19);
    DateTime now() {
      final current = tick;
      tick = tick.add(clockStep);
      return current;
    }

    container = ProviderContainer(
      overrides: [
        sessionDependenciesProvider.overrideWithValue(
          SessionDependencies(
            tokenStore: TokenStore(secure),
            remote: this.remote,
            hooks: [hook],
            sleep: (d) async => sleeps.add(d),
            now: now,
          ),
        ),
      ],
    );
  }

  final InMemorySecureKeyValue secure;
  final FakeSessionRemote remote;
  final hook = RecordingHook();
  final sleeps = <Duration>[];
  late final ProviderContainer container;

  SessionController get controller =>
      container.read(sessionControllerProvider.notifier);
  SessionState get state => container.read(sessionControllerProvider);

  void dispose() => container.dispose();
}

void main() {
  late Harness h;
  tearDown(() => h.dispose());

  group('Restauración y almacenamiento', () {
    test('restore sin refresh token deja la sesión anónima', () async {
      h = Harness();
      expect(h.state, isA<SessionUnknown>());
      await h.controller.restore();
      expect(h.state, isA<SessionAnonymous>());
    });

    test(
      'restore con refresh token queda autenticada y sin access en memoria',
      () async {
        h = Harness(secureData: {SecureKeys.refreshToken: 'iprr_x'});
        await h.controller.restore();
        expect(h.state, isA<SessionAuthenticated>());
        expect(h.controller.accessToken, isNull);
        expect(await h.controller.hasRefreshToken(), isTrue);
      },
    );

    test(
      'M0 · CR-019/SC-030 · el access token NUNCA se persiste: solo el refresh',
      () async {
        h = Harness();
        await h.controller.setSession(fakeTokens('a'), userId: 7);
        expect(h.controller.accessToken, 'ipra_a');
        expect(h.secure.data[SecureKeys.refreshToken], 'iprr_a');
        expect(
          h.secure.data.values.where((v) => v.startsWith('ipra_')),
          isEmpty,
        );
        expect((h.state as SessionAuthenticated).userId, 7);
      },
    );
  });

  group('Refresh', () {
    test(
      'TC-020 · AC-044-3 · renovación exitosa guarda tokens nuevos',
      () async {
        h = Harness(
          remote: FakeSessionRemote(refreshResults: [Ok(fakeTokens('new'))]),
          secureData: {SecureKeys.refreshToken: 'iprr_old'},
        );
        expect(await h.controller.refresh(), RefreshOutcome.refreshed);
        expect(h.controller.accessToken, 'ipra_new');
        expect(h.secure.data[SecureKeys.refreshToken], 'iprr_new');
        expect(h.remote.refreshCalls, ['iprr_old']);
      },
    );

    test('TC-021 · AC-044-6 · cinco solicitudes simultáneas producen un solo refresh', () async {
      final gate = Completer<void>();
      h = Harness(
        remote: FakeSessionRemote(refreshResults: [Ok(fakeTokens('n'))])
          ..refreshGate = gate.future,
        secureData: {SecureKeys.refreshToken: 'iprr_old'},
      );
      final calls = List.generate(5, (_) => h.controller.refresh());
      await Future<void>.delayed(Duration.zero);
      gate.complete();
      final outcomes = await Future.wait(calls);
      expect(outcomes, everyElement(RefreshOutcome.refreshed));
      expect(h.remote.refreshCalls, hasLength(1));
    });

    test(
      'tras terminar, un nuevo refresh vuelve a llamar al servidor',
      () async {
        h = Harness(
          remote: FakeSessionRemote(
            refreshResults: [Ok(fakeTokens('1')), Ok(fakeTokens('2'))],
          ),
          secureData: {SecureKeys.refreshToken: 'iprr_old'},
        );
        await h.controller.refresh();
        await h.controller.refresh();
        expect(h.remote.refreshCalls, ['iprr_old', 'iprr_1']);
      },
    );

    test(
      'TC-022 · AC-044-5 · 401 del refresh borra la sesión de inmediato',
      () async {
        h = Harness(
          remote: FakeSessionRemote(
            refreshResults: [const Err(Unauthorized())],
          ),
          secureData: {SecureKeys.refreshToken: 'iprr_old'},
        );
        await h.controller.setSession(fakeTokens('old'));
        expect(await h.controller.refresh(), RefreshOutcome.expired);
        expect(h.controller.accessToken, isNull);
        expect(h.secure.data.containsKey(SecureKeys.refreshToken), isFalse);
        expect(h.state, isA<SessionExpired>());
      },
    );

    test('refresh_token_reused también termina la sesión', () async {
      h = Harness(
        remote: FakeSessionRemote(
          refreshResults: [
            const Err(Unauthorized(code: 'refresh_token_reused')),
          ],
        ),
        secureData: {SecureKeys.refreshToken: 'iprr_old'},
      );
      expect(await h.controller.refresh(), RefreshOutcome.expired);
      expect(h.state, isA<SessionExpired>());
    });

    test('sin refresh token persistido la sesión termina', () async {
      h = Harness();
      expect(await h.controller.refresh(), RefreshOutcome.expired);
      expect(h.state, isA<SessionExpired>());
      expect(h.remote.refreshCalls, isEmpty);
    });

    test('TC-023 · AC-044-7 · error de red: un reintento con el mismo refresh y se recupera', () async {
      h = Harness(
        remote: FakeSessionRemote(
          refreshResults: [const Err(NoConnection()), Ok(fakeTokens('ok'))],
        ),
        secureData: {SecureKeys.refreshToken: 'iprr_old'},
        clockStep: const Duration(seconds: 1),
      );
      expect(await h.controller.refresh(), RefreshOutcome.refreshed);
      expect(h.remote.refreshCalls, ['iprr_old', 'iprr_old']);
    });

    test(
      'TC-023 · AC-044-7 · dos fallos de red NO cierran la sesión',
      () async {
        h = Harness(
          remote: FakeSessionRemote(
            refreshResults: [
              const Err(NoConnection()),
              const Err(RequestTimeout()),
            ],
          ),
          secureData: {SecureKeys.refreshToken: 'iprr_old'},
          clockStep: const Duration(seconds: 1),
        );
        await h.controller.restore();
        expect(await h.controller.refresh(), RefreshOutcome.transientFailure);
        expect(h.secure.data[SecureKeys.refreshToken], 'iprr_old');
        expect(h.state, isA<SessionAuthenticated>());
      },
    );

    test(
      'fuera de la ventana de 30 s no se reintenta con el mismo refresh',
      () async {
        h = Harness(
          remote: FakeSessionRemote(
            refreshResults: [const Err(NoConnection())],
          ),
          secureData: {SecureKeys.refreshToken: 'iprr_old'},
          clockStep: const Duration(seconds: 40),
        );
        expect(await h.controller.refresh(), RefreshOutcome.transientFailure);
        expect(h.remote.refreshCalls, hasLength(1));
      },
    );

    test(
      'CR-024 · 409 refresh_in_progress: espera 1 s y reintenta una vez',
      () async {
        h = Harness(
          remote: FakeSessionRemote(
            refreshResults: [
              const Err(Conflict(code: 'refresh_in_progress')),
              Ok(fakeTokens('ok')),
            ],
          ),
          secureData: {SecureKeys.refreshToken: 'iprr_old'},
        );
        expect(await h.controller.refresh(), RefreshOutcome.refreshed);
        expect(h.sleeps, [const Duration(seconds: 1)]);
        expect(h.remote.refreshCalls, hasLength(2));
      },
    );

    test('un error 500 al renovar no borra la sesión', () async {
      h = Harness(
        remote: FakeSessionRemote(refreshResults: [const Err(ServerFailure())]),
        secureData: {SecureKeys.refreshToken: 'iprr_old'},
      );
      expect(await h.controller.refresh(), RefreshOutcome.transientFailure);
      expect(h.secure.data[SecureKeys.refreshToken], 'iprr_old');
    });
  });

  group('Cierre de sesión', () {
    test(
      'en línea revoca en el servidor y conserva el carrito (hook de logout)',
      () async {
        h = Harness();
        await h.controller.setSession(fakeTokens('a'));
        await h.controller.logout();
        expect(h.remote.logoutCalls.single, (
          accessToken: 'ipra_a',
          all: false,
        ));
        expect(h.secure.data.containsKey(SecureKeys.refreshToken), isFalse);
        expect(
          h.secure.data.containsKey(SecureKeys.pendingRevocation),
          isFalse,
        );
        expect(h.controller.accessToken, isNull);
        expect(h.state, isA<SessionAnonymous>());
        expect(h.hook.logouts, 1);
        expect(
          h.hook.deletions,
          0,
          reason: 'CR-040: cerrar sesión conserva el carrito',
        );
      },
    );

    test('scope all revoca todas las sesiones', () async {
      h = Harness();
      await h.controller.setSession(fakeTokens('a'));
      await h.controller.logout(all: true);
      expect(h.remote.logoutCalls.single.all, isTrue);
    });

    test(
      'TC-015 · AC-041-6 · sin red guarda el refresh para revocarlo después',
      () async {
        h = Harness(
          remote: FakeSessionRemote(logoutResults: [const Err(NoConnection())]),
        );
        await h.controller.setSession(fakeTokens('a'));
        await h.controller.logout();
        expect(h.secure.data[SecureKeys.pendingRevocation], 'iprr_a');
        expect(h.secure.data.containsKey(SecureKeys.refreshToken), isFalse);
        expect(h.state, isA<SessionAnonymous>());
      },
    );

    test('un 401 al revocar cuenta como revocada', () async {
      h = Harness(
        remote: FakeSessionRemote(logoutResults: [const Err(Unauthorized())]),
      );
      await h.controller.setSession(fakeTokens('a'));
      await h.controller.logout();
      expect(h.secure.data.containsKey(SecureKeys.pendingRevocation), isFalse);
    });

    test(
      'tras reiniciar (sin access en memoria) renueva y luego revoca',
      () async {
        h = Harness(
          remote: FakeSessionRemote(refreshResults: [Ok(fakeTokens('r'))]),
          secureData: {SecureKeys.refreshToken: 'iprr_old'},
        );
        await h.controller.restore();
        await h.controller.logout();
        expect(h.remote.refreshCalls, ['iprr_old']);
        expect(h.remote.logoutCalls.single.accessToken, 'ipra_r');
        expect(
          h.secure.data.containsKey(SecureKeys.pendingRevocation),
          isFalse,
        );
      },
    );

    test('sin red y sin access: se guarda el refresh pendiente', () async {
      h = Harness(
        remote: FakeSessionRemote(
          refreshResults: [
            const Err(NoConnection()),
            const Err(NoConnection()),
          ],
        ),
        secureData: {SecureKeys.refreshToken: 'iprr_old'},
        clockStep: const Duration(seconds: 1),
      );
      await h.controller.restore();
      await h.controller.logout();
      expect(h.secure.data[SecureKeys.pendingRevocation], 'iprr_old');
      expect(h.remote.logoutCalls, isEmpty);
    });

    test(
      'sin ninguna sesión, cerrar sesión no falla ni deja pendientes',
      () async {
        h = Harness();
        await h.controller.logout();
        expect(h.secure.data, isEmpty);
        expect(h.state, isA<SessionAnonymous>());
      },
    );
  });

  group('Revocación pendiente (CR-039)', () {
    test(
      'al recuperar la red renueva con el refresh pendiente y revoca',
      () async {
        h = Harness(
          remote: FakeSessionRemote(refreshResults: [Ok(fakeTokens('p'))]),
          secureData: {SecureKeys.pendingRevocation: 'iprr_pend'},
        );
        await h.controller.retryPendingRevocation();
        expect(h.remote.refreshCalls, ['iprr_pend']);
        expect(h.remote.logoutCalls.single.accessToken, 'ipra_p');
        expect(
          h.secure.data.containsKey(SecureKeys.pendingRevocation),
          isFalse,
        );
      },
    );

    test('si el servidor ya lo había revocado (401) se limpia', () async {
      h = Harness(
        remote: FakeSessionRemote(refreshResults: [const Err(Unauthorized())]),
        secureData: {SecureKeys.pendingRevocation: 'iprr_pend'},
      );
      await h.controller.retryPendingRevocation();
      expect(h.secure.data.containsKey(SecureKeys.pendingRevocation), isFalse);
    });

    test('sin red se conserva para el siguiente intento', () async {
      h = Harness(
        remote: FakeSessionRemote(refreshResults: [const Err(NoConnection())]),
        secureData: {SecureKeys.pendingRevocation: 'iprr_pend'},
      );
      await h.controller.retryPendingRevocation();
      expect(h.secure.data[SecureKeys.pendingRevocation], 'iprr_pend');
    });

    test('si el logout posterior falla por red se conserva', () async {
      h = Harness(
        remote: FakeSessionRemote(
          refreshResults: [Ok(fakeTokens('p'))],
          logoutResults: [const Err(NoConnection())],
        ),
        secureData: {SecureKeys.pendingRevocation: 'iprr_pend'},
      );
      await h.controller.retryPendingRevocation();
      expect(h.secure.data[SecureKeys.pendingRevocation], 'iprr_pend');
    });

    test('sin pendiente no llama al servidor', () async {
      h = Harness();
      await h.controller.retryPendingRevocation();
      expect(h.remote.refreshCalls, isEmpty);
    });

    test('restore reintenta la revocación pendiente', () async {
      h = Harness(
        remote: FakeSessionRemote(refreshResults: [Ok(fakeTokens('p'))]),
        secureData: {SecureKeys.pendingRevocation: 'iprr_pend'},
      );
      await h.controller.restore();
      expect(h.remote.logoutCalls, hasLength(1));
    });
  });

  group('Eliminación de cuenta y expiración (CR-040)', () {
    test('borra tokens y pendientes, regenera el id de instalación y avisa a los hooks', () async {
      h = Harness();
      final tokenStore = TokenStore(h.secure);
      final before = await tokenStore.deviceId();
      await h.controller.setSession(fakeTokens('a'));
      await h.secure.write(SecureKeys.pendingRevocation, 'iprr_x');

      await h.controller.onAccountDeleted();

      expect(h.secure.data.containsKey(SecureKeys.refreshToken), isFalse);
      expect(h.secure.data.containsKey(SecureKeys.pendingRevocation), isFalse);
      final after = await tokenStore.deviceId();
      expect(after, isNot(before));
      expect(isUuidV4(after), isTrue);
      expect(h.controller.accessToken, isNull);
      expect(h.state, isA<SessionAnonymous>());
      expect(h.hook.deletions, 1);
    });

    test('expire limpia tokens y marca la sesión como vencida', () async {
      h = Harness();
      await h.controller.setSession(fakeTokens('a'));
      await h.controller.expire();
      expect(h.state, isA<SessionExpired>());
      expect(h.controller.accessToken, isNull);
      expect(h.secure.data, isEmpty);
    });

    test('SessionStateX.isAuthenticated', () {
      expect(const SessionAuthenticated().isAuthenticated, isTrue);
      expect(const SessionAnonymous().isAuthenticated, isFalse);
      expect(const SessionExpired().isAuthenticated, isFalse);
      expect(const SessionUnknown().isAuthenticated, isFalse);
    });
  });

  group('TokenStore y SessionTokens', () {
    test('SC-031 · el id de instalación es UUID v4 y se conserva', () async {
      final store = TokenStore(InMemorySecureKeyValue());
      final id = await store.deviceId();
      expect(isUuidV4(id), isTrue);
      expect(await store.deviceId(), id);
    });

    test('un id corrupto se reemplaza por uno válido', () async {
      final secure = InMemorySecureKeyValue({SecureKeys.deviceId: 'basura'});
      final id = await TokenStore(secure).deviceId();
      expect(isUuidV4(id), isTrue);
    });

    test('SessionTokens valida prefijos y tipos del contrato', () {
      final ok = SessionTokens.fromSessionJson({
        'accessToken': 'ipra_abc',
        'accessTokenExpiresIn': 900,
        'refreshToken': 'iprr_abc',
        'sessionId': 's-1',
      });
      expect(ok.accessToken, 'ipra_abc');
      expect(ok.sessionId, 's-1');
      for (final bad in <Object?>[
        'texto',
        {
          'accessToken': 'x',
          'refreshToken': 'iprr_a',
          'accessTokenExpiresIn': 1,
        },
        {
          'accessToken': 'ipra_a',
          'refreshToken': 'x',
          'accessTokenExpiresIn': 1,
        },
        {
          'accessToken': 'ipra_a',
          'refreshToken': 'iprr_a',
          'accessTokenExpiresIn': 0,
        },
        {'accessToken': 'ipra_a', 'refreshToken': 'iprr_a'},
      ]) {
        expect(() => SessionTokens.fromSessionJson(bad), throwsFormatException);
      }
    });

    test('SC-044 · toString nunca imprime los tokens', () {
      expect(fakeTokens('secreto').toString(), isNot(contains('secreto')));
    });
  });
}
