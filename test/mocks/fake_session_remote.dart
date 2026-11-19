import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/core/session/session_remote.dart';
import 'package:ipr_mobile/core/session/session_tokens.dart';

/// Genera tokens con la forma del contrato (`ipra_*` / `iprr_*`).
SessionTokens fakeTokens(String tag) => SessionTokens(
  accessToken: 'ipra_$tag',
  accessTokenExpiresIn: 900,
  refreshToken: 'iprr_$tag',
);

/// [SessionRemote] guionado: cada llamada consume el siguiente resultado.
final class FakeSessionRemote implements SessionRemote {
  new({
    List<Result<SessionTokens>>? refreshResults,
    List<Result<void>>? logoutResults,
  }) : refreshResults = [...?refreshResults],
       logoutResults = [...?logoutResults];

  final List<Result<SessionTokens>> refreshResults;
  final List<Result<void>> logoutResults;

  final List<String> refreshCalls = [];
  final List<({String accessToken, bool all})> logoutCalls = [];

  /// Permite pausar el refresh para probar solicitudes concurrentes.
  Future<void>? refreshGate;

  @override
  Future<Result<SessionTokens>> refresh(String refreshToken) async {
    refreshCalls.add(refreshToken);
    if (refreshGate != null) await refreshGate;
    if (refreshResults.isEmpty) {
      return const Err(UnknownFailure());
    }
    return refreshResults.removeAt(0);
  }

  @override
  Future<Result<void>> logout({
    required String accessToken,
    bool all = false,
  }) async {
    logoutCalls.add((accessToken: accessToken, all: all));
    if (logoutResults.isEmpty) return const Ok(null);
    return logoutResults.removeAt(0);
  }
}
