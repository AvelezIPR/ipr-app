import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/core/session/session_gateway.dart';
import 'package:ipr_mobile/core/session/session_remote.dart';
import 'package:ipr_mobile/core/session/session_state.dart';
import 'package:ipr_mobile/core/session/session_tokens.dart';
import 'package:ipr_mobile/core/session/token_store.dart';

/// Acciones que otras features enganchan al cierre de sesión o a la
/// eliminación de cuenta (vaciar caché personal, carrito, etc.). `core` no
/// importa features: ellas se registran vía provider.
abstract interface class SessionHook {
  /// Cierre de sesión: se conserva el carrito (CR-040).
  Future<void> onLogout();

  /// Cuenta eliminada: borrar carrito y caché personal (CR-040).
  Future<void> onAccountDeleted();
}

/// Dependencias de [SessionController], inyectables para pruebas.
final class SessionDependencies {
  const new({
    required this.tokenStore,
    required this.remote,
    this.hooks = const [],
    this.sleep = Future<void>.delayed,
    this.refreshRetryWindow = const Duration(seconds: 30),
    this.conflictWait = const Duration(seconds: 1),
    this._now,
  });

  final TokenStore tokenStore;
  final SessionRemote remote;
  final List<SessionHook> hooks;
  final Future<void> Function(Duration) sleep;

  /// Ventana en la que se reintenta una vez con el mismo refresh tras un
  /// error de red sin respuesta (CR-020).
  final Duration refreshRetryWindow;

  /// Espera ante `409 refresh_in_progress` (CR-024).
  final Duration conflictWait;
  final DateTime Function()? _now;

  DateTime now() => (_now ?? DateTime.now)();
}

/// Proveedor de las dependencias (se sobrescribe en el arranque y en pruebas).
final sessionDependenciesProvider = Provider<SessionDependencies>(
  (ref) => throw UnimplementedError('sessionDependenciesProvider sin override'),
);

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);

/// Controla la sesión del dispositivo (ADR-013, CR-019/020/024/039/040).
///
/// * El *access token* vive solo en memoria.
/// * El *refresh token* y el id de instalación, en el almacén seguro.
/// * Un único refresh en vuelo; fallos de red no borran la sesión.
class SessionController extends Notifier<SessionState>
    implements SessionGateway {
  String? _accessToken;
  Future<RefreshOutcome>? _inflight;

  SessionDependencies get _deps => ref.read(sessionDependenciesProvider);

  @override
  SessionState build() => const SessionUnknown();

  @override
  String? get accessToken => _accessToken;

  @override
  Future<bool> hasRefreshToken() async =>
      (await _deps.tokenStore.readRefreshToken()) != null;

  /// Lee el almacén seguro al arrancar.
  Future<void> restore() async {
    final hasToken = await hasRefreshToken();
    state = hasToken ? const SessionAuthenticated() : const SessionAnonymous();
    await retryPendingRevocation();
  }

  /// Guarda la sesión recién creada (login, registro o refresh).
  Future<void> setSession(SessionTokens tokens, {int? userId}) async {
    _accessToken = tokens.accessToken;
    await _deps.tokenStore.writeRefreshToken(tokens.refreshToken);
    state = SessionAuthenticated(userId: userId);
  }

  @override
  Future<RefreshOutcome> refresh() =>
      _inflight ??= _refreshOnce().whenComplete(() => _inflight = null);

  Future<RefreshOutcome> _refreshOnce() async {
    final refreshToken = await _deps.tokenStore.readRefreshToken();
    if (refreshToken == null) {
      await expire();
      return RefreshOutcome.expired;
    }
    final startedAt = _deps.now();
    var result = await _deps.remote.refresh(refreshToken);

    // 409 refresh_in_progress: otro refresh tiene el bloqueo; esperar y
    // reintentar una vez (CR-024).
    if (result case Err<SessionTokens>(
      failure: Conflict(code: 'refresh_in_progress'),
    )) {
      await _deps.sleep(_deps.conflictWait);
      result = await _deps.remote.refresh(refreshToken);
    }

    // Error de red sin respuesta: un reintento con el mismo refresh dentro
    // de la ventana de gracia, sin borrar la sesión (CR-020).
    if (result case Err<SessionTokens>(
      failure: NoConnection() || RequestTimeout(),
    )) {
      final elapsed = _deps.now().difference(startedAt);
      if (elapsed < _deps.refreshRetryWindow) {
        result = await _deps.remote.refresh(refreshToken);
      }
    }

    switch (result) {
      case Ok<SessionTokens>(:final value):
        await setSession(value);
        return RefreshOutcome.refreshed;
      case Err<SessionTokens>(failure: Unauthorized()):
        // unauthorized o refresh_token_reused: se borra todo de inmediato.
        await expire();
        return RefreshOutcome.expired;
      case Err<SessionTokens>():
        return RefreshOutcome.transientFailure;
    }
  }

  @override
  Future<void> expire() async {
    _accessToken = null;
    await _deps.tokenStore.clearRefreshToken();
    state = const SessionExpired();
  }

  /// Cierra la sesión: revoca en el servidor; si no hay red guarda el refresh
  /// en `pendingRevocation` para revocarlo al recuperarla (CR-039). Conserva
  /// el carrito (CR-040).
  Future<void> logout({bool all = false}) async {
    final refreshToken = await _deps.tokenStore.readRefreshToken();
    var revoked = false;
    var access = _accessToken;
    if (access == null && refreshToken != null) {
      // Sin access en memoria (reinicio): se renueva solo para revocar.
      if (await refresh() == RefreshOutcome.refreshed) access = _accessToken;
    }
    if (access != null) {
      final result = await _deps.remote.logout(accessToken: access, all: all);
      revoked = result.isOk || result.failureOrNull is Unauthorized;
    }
    final latestRefresh = await _deps.tokenStore.readRefreshToken();
    if (!revoked && (latestRefresh ?? refreshToken) != null) {
      await _deps.tokenStore.writePendingRevocation(
        (latestRefresh ?? refreshToken)!,
      );
    }
    await _clearLocalSession();
    state = const SessionAnonymous();
    for (final hook in _deps.hooks) {
      await hook.onLogout();
    }
  }

  /// Intenta revocar un refresh pendiente. Mecanismo: se renueva con ese
  /// refresh y se llama a `logout` (A VALIDAR con el backend: CR-039 no define
  /// otro).
  Future<void> retryPendingRevocation() async {
    final pending = await _deps.tokenStore.readPendingRevocation();
    if (pending == null) return;
    final refreshed = await _deps.remote.refresh(pending);
    switch (refreshed) {
      case Ok<SessionTokens>(:final value):
        final out = await _deps.remote.logout(accessToken: value.accessToken);
        if (out.isOk || out.failureOrNull is Unauthorized) {
          await _deps.tokenStore.clearPendingRevocation();
        }
      case Err<SessionTokens>(failure: Unauthorized()):
        // Ya estaba revocado en el servidor.
        await _deps.tokenStore.clearPendingRevocation();
      case Err<SessionTokens>():
        break; // se reintentará al volver a primer plano
    }
  }

  /// Tras `POST /me/deletion` aceptado: borra tokens, datos personales en
  /// memoria, carrito y caché personal, y regenera el id de instalación
  /// (CR-040).
  Future<void> onAccountDeleted() async {
    await _clearLocalSession();
    await _deps.tokenStore.clearPendingRevocation();
    await _deps.tokenStore.regenerateDeviceId();
    state = const SessionAnonymous();
    for (final hook in _deps.hooks) {
      await hook.onAccountDeleted();
    }
  }

  Future<void> _clearLocalSession() async {
    _accessToken = null;
    await _deps.tokenStore.clearRefreshToken();
  }
}
