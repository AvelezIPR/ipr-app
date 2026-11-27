import 'package:ipr_mobile/core/config/engineering_team.dart';
import 'package:ipr_mobile/core/config/home_content.dart';
import 'package:ipr_mobile/core/config/remote_config.dart';
import 'package:json_annotation/json_annotation.dart';

part 'remote_config_dto.g.dart';

/// Contrato de `GET /config` (`openapi.yaml` → `AppConfig`). Todos los campos
/// son opcionales: el mapeador es tolerante y nunca lanza por un campo ausente.
@JsonSerializable(createToJson: false)
final class RemoteConfigDto {
  const new({
    this.minSupportedVersion,
    this.recommendedVersion,
    this.features,
    this.contact,
    this.checkout,
    this.notices,
    this.legal,
    this.home,
  });

  factory fromJson(Map<String, dynamic> json) =>
      _$RemoteConfigDtoFromJson(json);

  final PlatformVersionsDto? minSupportedVersion;
  final PlatformVersionsDto? recommendedVersion;
  final FeaturesDto? features;
  final ContactDto? contact;
  final CheckoutConfigDto? checkout;
  final NoticesDto? notices;
  final LegalDto? legal;

  /// `home` tal cual llega: se interpreta con [HomeContent.fromJson], que
  /// descarta lo ilegible sin lanzar.
  final Object? home;

  /// Mapeo tolerante a la entidad; [platform] es `android` o `ios`.
  RemoteConfig toEntity({required String platform}) => RemoteConfig(
    minSupportedVersion: minSupportedVersion?.forPlatform(platform),
    recommendedVersion: recommendedVersion?.forPlatform(platform),
    checkoutEnabled: features?.checkoutEnabled ?? false,
    pqrsEnabled: features?.pqrsEnabled ?? false,
    btuCalculatorEnabled: features?.btuCalculatorEnabled ?? false,
    checkoutAllowedHosts: Set.unmodifiable(
      (checkout?.allowedHosts ?? const <String>[]).map((h) => h.toLowerCase()),
    ),
    returnPathPrefix: checkout?.returnPathPrefix,
    whatsappNumber: contact?.whatsapp?.number,
    whatsappDefaultMessage: contact?.whatsapp?.defaultMessage,
    phoneDisplay: contact?.phone?.display,
    phoneDial: contact?.phone?.dial,
    salesEmail: contact?.salesEmail,
    pqrsEmail: contact?.pqrsEmail,
    engineeringWhatsapp: contact?.engineering?.whatsapp,
    engineeringEmail: contact?.engineering?.email,
    engineeringSpecialties: EngineeringTeam.fromJson(
      contact?.engineering?.specialties,
    ),
    shippingNotice: notices?.shipping,
    warrantyNotice: notices?.warranty,
    priceOnRequestNotice: notices?.priceOnRequest,
    termsVersion: legal?.terms?.version,
    termsUrl: legal?.terms?.url,
    privacyPolicyVersion: legal?.privacyPolicy?.version,
    privacyPolicyUrl: legal?.privacyPolicy?.url,
    dataRightsUrl: legal?.dataRightsChannel?.url,
    dataRightsEmail: legal?.dataRightsChannel?.email,
    accountDeletionNotice: legal?.accountDeletionNotice,
    home: HomeContent.fromJson(home),
  );
}

@JsonSerializable(createToJson: false)
final class PlatformVersionsDto {
  const new({this.android, this.ios});

  factory fromJson(Map<String, dynamic> json) =>
      _$PlatformVersionsDtoFromJson(json);

  final String? android;
  final String? ios;

  String? forPlatform(String platform) => platform == 'ios' ? ios : android;
}

@JsonSerializable(createToJson: false)
final class FeaturesDto {
  const new({
    this.checkoutEnabled,
    this.pqrsEnabled,
    this.btuCalculatorEnabled,
  });

  factory fromJson(Map<String, dynamic> json) => _$FeaturesDtoFromJson(json);

  final bool? checkoutEnabled;
  final bool? pqrsEnabled;
  final bool? btuCalculatorEnabled;
}

@JsonSerializable(createToJson: false)
final class ContactDto {
  const new({
    this.whatsapp,
    this.phone,
    this.salesEmail,
    this.pqrsEmail,
    this.engineering,
  });

  factory fromJson(Map<String, dynamic> json) => _$ContactDtoFromJson(json);

  final WhatsAppDto? whatsapp;
  final PhoneDto? phone;
  final String? salesEmail;
  final String? pqrsEmail;
  final EngineeringContactDto? engineering;
}

@JsonSerializable(createToJson: false)
final class EngineeringContactDto {
  const new({this.whatsapp, this.email, this.specialties});

  factory fromJson(Map<String, dynamic> json) =>
      _$EngineeringContactDtoFromJson(json);

  final String? whatsapp;
  final String? email;

  /// Equipo por especialidad tal cual llega (W3-02): se interpreta con
  /// [EngineeringTeam.fromJson], que descarta lo ilegible sin lanzar.
  final Object? specialties;
}

@JsonSerializable(createToJson: false)
final class WhatsAppDto {
  const new({this.number, this.defaultMessage});

  factory fromJson(Map<String, dynamic> json) => _$WhatsAppDtoFromJson(json);

  final String? number;
  final String? defaultMessage;
}

@JsonSerializable(createToJson: false)
final class PhoneDto {
  const new({this.display, this.dial});

  factory fromJson(Map<String, dynamic> json) => _$PhoneDtoFromJson(json);

  final String? display;
  final String? dial;
}

@JsonSerializable(createToJson: false)
final class CheckoutConfigDto {
  const new({this.allowedHosts, this.returnPathPrefix});

  factory fromJson(Map<String, dynamic> json) =>
      _$CheckoutConfigDtoFromJson(json);

  final List<String>? allowedHosts;
  final String? returnPathPrefix;
}

@JsonSerializable(createToJson: false)
final class NoticesDto {
  const new({this.shipping, this.warranty, this.priceOnRequest});

  factory fromJson(Map<String, dynamic> json) => _$NoticesDtoFromJson(json);

  final String? shipping;
  final String? warranty;
  final String? priceOnRequest;
}

@JsonSerializable(createToJson: false)
final class LegalDto {
  const new({
    this.terms,
    this.privacyPolicy,
    this.dataRightsChannel,
    this.accountDeletionNotice,
  });

  factory fromJson(Map<String, dynamic> json) => _$LegalDtoFromJson(json);

  final LegalDocumentDto? terms;
  final LegalDocumentDto? privacyPolicy;
  final DataRightsChannelDto? dataRightsChannel;
  final String? accountDeletionNotice;
}

@JsonSerializable(createToJson: false)
final class LegalDocumentDto {
  const new({this.version, this.url});

  factory fromJson(Map<String, dynamic> json) =>
      _$LegalDocumentDtoFromJson(json);

  final String? version;
  final String? url;
}

@JsonSerializable(createToJson: false)
final class DataRightsChannelDto {
  const new({this.url, this.email});

  factory fromJson(Map<String, dynamic> json) =>
      _$DataRightsChannelDtoFromJson(json);

  final String? url;
  final String? email;
}
