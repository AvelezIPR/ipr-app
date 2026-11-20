import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ipr_mobile/core/session/session_controller.dart';

/// Resultado de pedir el cierre de sesión.
enum LogoutOutcome {
  /// La sesión local quedó cerrada (la revocación en el servidor la gestiona
  /// `core/session`: si no hay red queda pendiente, CR-039).
  done,

  /// Algo falló antes de dejar la sesión cerrada; el usuario puede reintentar.
  failed,

  /// Ya había un cierre en curso: no se emite una segunda solicitud
  /// (AC-041-8).
  ignored,
}

/// Estado: `true` mientras hay un cierre de sesión en curso.
final logoutControllerProvider = NotifierProvider<LogoutController, bool>(
  LogoutController.new,
);

/// Cierra la sesión (RF-041). Un solo cierre a la vez aunque el usuario toque
/// dos veces. El carrito se conserva (CR-040; lo gestiona `core`/M3).
class LogoutController extends Notifier<bool> {
  @override
  bool build() => false;

  Future<LogoutOutcome> logout() async {
    if (state) return LogoutOutcome.ignored;
    state = true;
    try {
      await ref.read(sessionControllerProvider.notifier).logout();
      return LogoutOutcome.done;
    } on Object {
      // Sin datos del usuario en el mensaje: solo se informa del fallo.
      return LogoutOutcome.failed;
    } finally {
      state = false;
    }
  }
}
