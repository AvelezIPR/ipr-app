import 'package:ipr_mobile/shared/domain/image_ref.dart';
import 'package:meta/meta.dart';

/// Tipo de línea telefónica corporativa de una sede (`Store.phones[].type`,
/// incluyendo `mobile_secondary` de CR-057).
enum BranchPhoneType {
  landline,
  salesParts,
  salesAc,
  mobile,
  mobileSecondary,
  other,
}

@immutable
final class BranchPhone {
  const new({required this.type, required this.display, required this.dial});

  final BranchPhoneType type;
  final String display;
  final String dial;

  @override
  bool operator ==(Object other) =>
      other is BranchPhone &&
      other.type == type &&
      other.display == display &&
      other.dial == dial;

  @override
  int get hashCode => Object.hash(type, display, dial);
}

/// Sede de IPR (`openapi.yaml` → `Store`, RF-072..076). Sin coordenadas ni
/// horarios en el MVP (D-09).
@immutable
final class Branch {
  const new({
    required this.slug,
    required this.city,
    required this.name,
    required this.address,
    required this.upcoming,
    required this.phones,
    this.whatsappNumber,
    this.image,
    this.mapsQuery,
  });

  final String slug;
  final String city;
  final String name;
  final String address;
  final bool upcoming;
  final List<BranchPhone> phones;
  final String? whatsappNumber;
  final ImageRef? image;
  final String? mapsQuery;

  /// Texto efectivo de búsqueda para "Cómo llegar" (AC-075-1).
  String? get effectiveMapsQuery {
    final query = mapsQuery?.trim();
    if (query != null && query.isNotEmpty) return query;
    final addr = address.trim();
    return addr.isEmpty ? null : addr;
  }

  @override
  bool operator ==(Object other) =>
      other is Branch &&
      other.slug == slug &&
      other.city == city &&
      other.name == name &&
      other.address == address &&
      other.upcoming == upcoming &&
      other.whatsappNumber == whatsappNumber &&
      other.image == image &&
      other.mapsQuery == mapsQuery &&
      _samePhones(other.phones);

  bool _samePhones(List<BranchPhone> other) {
    if (other.length != phones.length) return false;
    for (var i = 0; i < phones.length; i++) {
      if (phones[i] != other[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    slug,
    city,
    name,
    address,
    upcoming,
    whatsappNumber,
    image,
    mapsQuery,
    phones.length,
  );
}

/// Grupo de sedes de una ciudad con al menos una sede (AC-072-1, AC-072-6).
@immutable
final class CityBranchGroup {
  const new({required this.city, required this.branches});

  final String city;
  final List<Branch> branches;
}

/// Agrupa las sedes por ciudad en orden de aparición, sin grupos vacíos.
List<CityBranchGroup> groupBranchesByCity(List<Branch> branches) {
  final grouped = <String, List<Branch>>{};
  for (final branch in branches) {
    final city = branch.city.trim();
    if (city.isEmpty) continue;
    grouped.putIfAbsent(city, () => []).add(branch);
  }
  return [
    for (final entry in grouped.entries)
      CityBranchGroup(
        city: entry.key,
        branches: List.unmodifiable(entry.value),
      ),
  ];
}
