import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/features/authentication/domain/rules/auth_validation.dart';
import 'package:meta/meta.dart';

/// Motivo de un fallo a nivel de formulario (no de un campo).
enum AuthProblem {
  /// Login: mensaje ÚNICO (cuenta inexistente, contraseña errónea, rol
  /// bloqueado, cuenta en eliminación). Nunca revela cuál de ellos fue.
  invalidCredentials,

  /// 429: demasiados intentos; puede haber cuenta regresiva.
  rateLimited,

  /// Registro: conflicto de cuenta (`409`), con mensaje neutral. Ver
  /// `RegisterConflictPolicy`.
  accountConflict,

  /// Registro: no hay versión vigente de los documentos legales.
  legalUnavailable,

  /// Cualquier otro fallo: el texto sale de [AuthFormState.failure].
  other,
}

/// Estado de un formulario de autenticación (login, registro o recuperación).
///
/// **No contiene valores de campos**: ni la contraseña ni el correo se
/// guardan aquí (los textos viven solo en los `TextEditingController` de la
/// pantalla y se limpian al salir). Solo hay códigos de error por campo.
@immutable
final class AuthFormState {
  const new({
    this.submitting = false,
    this.fieldIssues = const {},
    this.serverMessages = const {},
    this.problem,
    this.failure,
    this.cooldownSeconds = 0,
    this.completed = false,
  });

  /// Hay una solicitud en curso: el botón queda deshabilitado (un solo envío).
  final bool submitting;

  /// Errores de la validación local, por campo.
  final Map<AuthField, FieldIssue> fieldIssues;

  /// Errores por campo que devolvió el servidor (`400 validation_failed`).
  /// Un texto vacío significa "usa el mensaje de respaldo".
  final Map<AuthField, String> serverMessages;

  final AuthProblem? problem;

  /// El [AppFailure] detrás de [problem] (para `other` y `rateLimited`).
  final AppFailure? failure;

  /// Segundos restantes de espera tras un 429 con `Retry-After`.
  final int cooldownSeconds;

  /// Login/registro: la sesión quedó guardada. Recuperación: el servidor
  /// aceptó la solicitud (`202`).
  final bool completed;

  bool get coolingDown => cooldownSeconds > 0;

  /// Se puede enviar: ni en curso, ni en espera, ni ya completado.
  bool get canSubmit => !submitting && !coolingDown && !completed;

  AuthFormState withCooldown(int remaining) {
    final ended = remaining <= 0;
    final clearBanner = ended && problem == AuthProblem.rateLimited;
    return AuthFormState(
      submitting: submitting,
      fieldIssues: fieldIssues,
      serverMessages: serverMessages,
      problem: clearBanner ? null : problem,
      failure: clearBanner ? null : failure,
      cooldownSeconds: ended ? 0 : remaining,
      completed: completed,
    );
  }

  // Nada de valores de campos: solo la forma del estado.
  @override
  String toString() =>
      'AuthFormState(submitting: $submitting, problem: $problem, '
      'issues: ${fieldIssues.length}, cooldown: $cooldownSeconds, '
      'completed: $completed)';
}
