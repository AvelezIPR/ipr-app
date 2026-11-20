import 'package:ipr_mobile/features/branches/domain/entities/branch.dart';
import 'package:ipr_mobile/shared/domain/image_ref.dart';

final RegExp _dialPattern = RegExp(r'^\+?\d{7,15}$');
final RegExp _whatsappPattern = RegExp(r'^\d{8,15}$');

String? _nonEmptyString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// Mapea `{data: [...]}` de `GET /stores` de forma tolerante (`AC-076-4`).
///
/// * Si la envolvente no es `{data: [...]}` lanza [FormatException] →
///   `ContractFailure`.
/// * Si una sede tiene un campo opcional faltante o inválido (teléfono mal
///   formado, WhatsApp vacío/inválido, `imageUrl` inválida), se omite solo ese
///   campo sin fallar el listado completo.
List<Branch> mapStores(Object? body) {
  if (body is! Map<String, dynamic> || body['data'] is! List<Object?>) {
    throw const FormatException('se esperaba {data: [...]} en /stores');
  }
  final rawList = body['data']! as List<Object?>;
  return [for (final item in rawList) ?_mapStore(item)];
}

Branch? _mapStore(Object? json) {
  if (json is! Map<String, dynamic>) return null;
  final slug = _nonEmptyString(json['slug']);
  final city = _nonEmptyString(json['city']);
  final name = _nonEmptyString(json['name']);
  if (slug == null || city == null || name == null) return null;

  final address = json['address'] is String
      ? (json['address']! as String).trim()
      : '';
  final upcoming = json['upcoming'] is bool && json['upcoming']! as bool;
  final phones = _mapPhones(json['phones']);
  final whatsapp = _mapWhatsapp(json['whatsapp']);
  final imageUrl = _nonEmptyString(json['imageUrl']);
  final image = imageUrl == null ? null : ImageRef(url: imageUrl, alt: name);
  final mapsQuery = _nonEmptyString(json['mapsQuery']);

  return Branch(
    slug: slug,
    city: city,
    name: name,
    address: address,
    upcoming: upcoming,
    phones: List.unmodifiable(phones),
    whatsappNumber: whatsapp,
    image: image,
    mapsQuery: mapsQuery,
  );
}

List<BranchPhone> _mapPhones(Object? raw) {
  if (raw is! List<Object?>) return const [];
  final result = <BranchPhone>[];
  for (final item in raw) {
    if (item is! Map<String, dynamic>) continue;
    final display = _nonEmptyString(item['display']);
    final dial = _nonEmptyString(item['dial']);
    if (display == null || dial == null || !_dialPattern.hasMatch(dial)) {
      continue;
    }
    result.add(
      BranchPhone(
        type: _mapPhoneType(item['type']),
        display: display,
        dial: dial,
      ),
    );
  }
  return result;
}

BranchPhoneType _mapPhoneType(Object? raw) => switch (raw) {
  'landline' => BranchPhoneType.landline,
  'sales_parts' => BranchPhoneType.salesParts,
  'sales_ac' => BranchPhoneType.salesAc,
  'mobile' => BranchPhoneType.mobile,
  'mobile_secondary' => BranchPhoneType.mobileSecondary,
  _ => BranchPhoneType.other,
};

String? _mapWhatsapp(Object? raw) {
  if (raw is! Map<String, dynamic>) return null;
  final number = _nonEmptyString(raw['number']);
  if (number == null || !_whatsappPattern.hasMatch(number)) return null;
  return number;
}
