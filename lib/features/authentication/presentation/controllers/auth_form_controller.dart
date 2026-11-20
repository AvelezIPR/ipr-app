import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/session/session_controller.dart';
import 'package:ipr_mobile/features/authentication/domain/entities/authenticated_session.dart';
import 'package:ipr_mobile/features/authentication/domain/rules/auth_validation.dart';
import 'package:ipr_mobile/features/authentication/presentation/controllers/auth_form_state.dart';

/// Cuenta regresiva de un segundo (espera tras `429 Retry-After`).
final class Cooldown {
  new({required this.onTick});

  /// Se invoca de inmediato con el total y luego cada segundo; `0` al terminar.
  final void Function(int remaining) onTick;

  Timer? _timer;
  int _remaining = 0;

  void start(int seconds) {
    cancel();
    _remaining = seconds;
    onTick(_remaining);
    if (_remaining <= 0) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _remaining--;
      if (_remaining <= 0) {
        cancel();
        onTick(0);
      } else {
        onTick(_remaining);
      }
    });
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}

/// Base de los tres controladores de formulario (login, registro y
/// recuperación). Concentra lo que NO debe variar entre ellos:
///
/// * un solo envío a la vez (doble toque, AC-038-6, AC-040-4);
/// * errores por campo del servidor junto al campo (`validation_failed`);
/// * `429` con cuenta regresiva que deshabilita el botón (AC-045-1);
/// * cancelación de la petición al salir de la pantalla;
/// * guardar la sesión **solo** con `SessionController.setSession`.
///
/// El estado nunca contiene valores de campos.
abstract class AuthFormController extends Notifier<AuthFormState> {
  Cooldown? _cooldown;
  RequestCancellation? _inflight;

  @override
  AuthFormState build() {
    _cooldown = Cooldown(
      onTick: (remaining) {
        if (ref.mounted) state = state.withCooldown(remaining);
      },
    );
    ref.onDispose(() {
      _cooldown?.cancel();
      _inflight?.cancel();
    });
    return const AuthFormState();
  }

  /// No se puede enviar ahora (en curso, en espera o ya completado).
  bool get busy => !state.canSubmit;

  /// Rechazo de la validación local: no se emite ninguna petición.
  void rejectLocally(Map<AuthField, FieldIssue> issues) {
    state = AuthFormState(fieldIssues: issues);
  }

  /// Marca el envío en curso y devuelve la cancelación de la petición.
  RequestCancellation startRequest() {
    _inflight?.cancel();
    state = const AuthFormState(submitting: true);
    return _inflight = RequestCancellation();
  }

  /// Fallo de red/servidor con el tratamiento común. [problem] fuerza el
  /// motivo para fallos no genéricos (`Unauthorized` del login, etc.).
  void failWith(AppFailure failure, {AuthProblem? problem}) {
    if (!ref.mounted) return;
    switch (failure) {
      case RateLimited(:final retryAfter):
        state = AuthFormState(
          problem: AuthProblem.rateLimited,
          failure: failure,
        );
        if (retryAfter != null && retryAfter > 0) _cooldown?.start(retryAfter);
      case Validation(:final fields):
        final mapped = <AuthField, String>{};
        var unmapped = false;
        for (final error in fields) {
          final field = AuthField.fromServer(error.field);
          if (field == null) {
            unmapped = true;
          } else {
            mapped[field] = error.message.trim();
          }
        }
        state = (mapped.isNotEmpty && !unmapped)
            ? AuthFormState(serverMessages: mapped)
            : AuthFormState(
                serverMessages: mapped,
                problem: AuthProblem.other,
                failure: failure,
              );
      default:
        state = AuthFormState(
          problem: problem ?? AuthProblem.other,
          failure: failure,
        );
    }
  }

  /// Guarda la sesión del dispositivo y marca el formulario como completado.
  /// El router reacciona al cambio de sesión (vuelve a `from` o va a Cuenta).
  /// Devuelve `false` si el almacén seguro falla (no queda sesión a medias).
  Future<bool> establishSession(AuthenticatedSession session) async {
    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .setSession(session.tokens, userId: session.userId);
    } on Object {
      failWith(const UnknownFailure());
      return false;
    }
    if (ref.mounted) state = const AuthFormState(completed: true);
    return true;
  }

  /// Fin sin error (recuperación aceptada).
  void complete() {
    if (ref.mounted) state = const AuthFormState(completed: true);
  }
}
