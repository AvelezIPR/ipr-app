/// Política ante `409 email_in_use` al cambiar el correo (`POST /me/email`,
/// AC-104-6, TC-098).
///
/// **Único punto** donde se aísla la decisión **H-03 / PA-02**:
/// * `true` (por defecto): mensaje neutral que no confirma si el correo nuevo
///   pertenece a otra cuenta.
/// * `false`: distinguir el conflicto con un mensaje específico si se aprueba
///   aceptar el riesgo RA-11.
final class EmailChangeConflictPolicy {
  const new({this.treatConflictAsNeutral = true});

  static const current = EmailChangeConflictPolicy();

  final bool treatConflictAsNeutral;
}
