/// Qué pasa con el carrito local ante eventos de la cuenta. **Único punto**
/// donde se decide (DN-10, CR-040).
///
/// * Cerrar sesión: **se conserva**. El carrito no tiene datos personales y es
///   lo que hace la web. **H-07 sigue PENDIENTE de aprobación**: si se decide
///   vaciarlo, basta cambiar [clearOnLogout] (y su prueba).
/// * Sesión expirada (RF-044): **se conserva**; no hay gancho de sesión para
///   este caso y el carrito nunca depende de la sesión.
/// * Cuenta eliminada: **se borra** (CR-040, RNF-062).
final class CartRetentionPolicy {
  const new({this.clearOnLogout = false, this.clearOnAccountDeleted = true});

  /// Política vigente.
  static const current = CartRetentionPolicy();

  final bool clearOnLogout;
  final bool clearOnAccountDeleted;

  /// El carrito se conserva al expirar la sesión (RF-044). No configurable.
  bool get clearOnSessionExpired => false;
}
