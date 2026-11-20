/// API pública de la feature `authentication` (RF-038, RF-039, RF-040, RF-042,
/// RF-043, RF-044, RF-045, RF-048): solo las pantallas de nivel de ruta.
///
/// Rutas: `Routes.login` (`/login?from=`), `Routes.register`
/// (`/register?from=`) y `Routes.passwordRecovery` (`/password-recovery`).
/// `from` es opcional: el router ya vuelve a la ruta de origen al autenticar;
/// la pantalla solo lo reenvía entre Login y Registro.
library;

export 'package:ipr_mobile/features/authentication/presentation/screens/login_screen.dart'
    show LoginScreen;
export 'package:ipr_mobile/features/authentication/presentation/screens/password_recovery_screen.dart'
    show PasswordRecoveryScreen;
export 'package:ipr_mobile/features/authentication/presentation/screens/register_screen.dart'
    show RegisterScreen;
