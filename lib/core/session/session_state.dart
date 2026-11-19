/// Estado de la sesión del usuario (lo leen el router, checkout, orders...).
sealed class SessionState {
  const new();
}

/// Aún no se ha leído el almacén seguro (arranque).
final class SessionUnknown extends SessionState {
  const new();
}

/// Sin sesión: se puede navegar y comprar el carrito local hasta pagar.
final class SessionAnonymous extends SessionState {
  const new();
}

/// Sesión activa. [userId] viene del perfil; no es un dato sensible.
final class SessionAuthenticated extends SessionState {
  const new({this.userId});
  final int? userId;
}

/// La sesión terminó (401 tras refresh): ir a login conservando el carrito.
final class SessionExpired extends SessionState {
  const new();
}

extension SessionStateX on SessionState {
  bool get isAuthenticated => this is SessionAuthenticated;
}
