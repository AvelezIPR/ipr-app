import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:ipr_mobile/core/config/app_config.dart';
import 'package:ipr_mobile/core/config/engineering_team.dart';
import 'package:ipr_mobile/core/config/home_content.dart';

part 'remote_config.freezed.dart';

/// Configuración remota ya interpretada (`GET /config`).
///
/// Aísla decisiones PENDIENTES detrás de interruptores del servidor:
/// calculadora BTU (D-08), PQRS, checkout. Mientras no llegue una respuesta
/// válida, todos los interruptores están **apagados** (falla cerrado).
@freezed
abstract class RemoteConfig with _$RemoteConfig {
  const factory({
    /// Versión mínima soportada para la plataforma actual (`x.y.z`) o `null`.
    String? minSupportedVersion,
    String? recommendedVersion,
    @Default(false) bool checkoutEnabled,
    @Default(false) bool pqrsEnabled,
    @Default(false) bool btuCalculatorEnabled,
    @Default(<String>{}) Set<String> checkoutAllowedHosts,
    String? returnPathPrefix,
    String? whatsappNumber,
    String? whatsappDefaultMessage,
    String? phoneDisplay,
    String? phoneDial,
    String? salesEmail,
    String? pqrsEmail,
    String? engineeringWhatsapp,
    String? engineeringEmail,

    /// Equipo de ingeniería por especialidad y ciudad (W3-02); vacío = solo el
    /// canal general.
    @Default(<EngineeringSpecialty>[])
    List<EngineeringSpecialty> engineeringSpecialties,

    /// Avisos de la ficha (RF-032): envío nacional y garantía.
    String? shippingNotice,
    String? warrantyNotice,
    String? priceOnRequestNotice,

    /// Documentos legales publicados (RF-039, RF-099). Sin versión o sin URL
    /// no se puede registrar la aceptación: la UI no ofrece el registro.
    String? termsVersion,
    String? termsUrl,
    String? privacyPolicyVersion,
    String? privacyPolicyUrl,
    String? dataRightsUrl,
    String? dataRightsEmail,
    String? accountDeletionNotice,

    /// Campañas, cifras y bloques destacados de la portada (W2, D-07).
    @Default(HomeContent.empty) HomeContent home,
  }) = _RemoteConfig;

  /// Valores previos a la primera respuesta: todo apagado y WhatsApp de
  /// respaldo tomado de la configuración pública del flavor.
  factory defaults(AppConfig config) =>
      RemoteConfig(whatsappNumber: config.supportWhatsApp);
}
