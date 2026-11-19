/// Resultado de intentar renovar la sesión.
enum RefreshOutcome {
  /// Hay un access token nuevo.
  refreshed,

  /// El servidor rechazó el refresh (401): la sesión terminó y se limpió.
  expired,

  /// Fallo transitorio (sin red, 5xx...): la sesión **no** se borra (CR-020).
  transientFailure,
}

/// Lo que `AuthInterceptor` necesita de la sesión. Lo implementa
/// `SessionController`.
abstract interface class SessionGateway {
  /// Access token en memoria o `null` si no hay sesión.
  String? get accessToken;

  /// Hay un refresh token persistido (se usa tras reiniciar la app).
  Future<bool> hasRefreshToken();

  /// Renueva la sesión; todas las llamadas concurrentes comparten un único
  /// refresh en vuelo (*single-flight*).
  Future<RefreshOutcome> refresh();

  /// Termina la sesión localmente (tokens y datos personales) sin pasar por
  /// la red.
  Future<void> expire();
}
