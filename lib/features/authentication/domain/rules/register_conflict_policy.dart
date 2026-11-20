import 'package:ipr_mobile/core/errors/app_failure.dart';

/// Cómo se presenta un `409` al registrar (correo ya registrado).
enum RegisterConflictResolution {
  /// Mensaje NEUTRAL que no confirma que la cuenta exista, con las acciones
  /// "Iniciar sesión" y "Recuperar contraseña". Es lo que se aplica hoy.
  neutralNotice,
}

/// ÚNICO punto donde se decide el comportamiento ante un `409` de registro.
///
/// **PENDIENTE de aprobación de H-03 / PA-02**: el contrato define
/// `409 email_in_use` (RA-11 acepta el riesgo de revelar la existencia), pero
/// RF-045 / AC-038-5 piden no revelarla, y `SUP-H03` propone una respuesta
/// uniforme con verificación de correo (RF-046, fase 2). Mientras no haya
/// decisión se usa la salida más conservadora: un mensaje neutral. Cuando se
/// decida basta con cambiar [resolution] (y añadir el caso al `switch` del
/// controlador); ningún otro archivo conoce el motivo del conflicto.
abstract final class RegisterConflictPolicy {
  static const RegisterConflictResolution resolution =
      RegisterConflictResolution.neutralNotice;

  /// Un `409` de `/auth/register` (cualquiera sea su `code`: `email_in_use`,
  /// `conflict`...) se trata como conflicto de cuenta.
  static bool appliesTo(AppFailure failure) => failure is Conflict;
}
