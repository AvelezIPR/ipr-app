import 'package:meta/meta.dart';

/// Canal corporativo de ingeniería en una ciudad (`openapi.yaml` →
/// `EngineeringContact`). Solo canales de la empresa: el servidor no publica
/// nombres ni teléfonos o correos personales (AC-080-2).
@immutable
final class EngineeringContact {
  const new({
    required this.id,
    required this.city,
    this.email,
    this.whatsapp,
    this.phoneDisplay,
    this.phoneDial,
  });

  final String id;
  final String city;
  final String? email;

  /// Número de WhatsApp (solo dígitos, con código de país).
  final String? whatsapp;

  /// Teléfono tal como se lee, con extensión ("6043604440 ext. 1151").
  final String? phoneDisplay;

  /// Número base para marcar (sin extensión).
  final String? phoneDial;

  /// Hay teléfono para marcar y para leer.
  bool get hasPhone => phoneDial != null;

  @override
  bool operator ==(Object other) =>
      other is EngineeringContact &&
      other.id == id &&
      other.city == city &&
      other.email == email &&
      other.whatsapp == whatsapp &&
      other.phoneDisplay == phoneDisplay &&
      other.phoneDial == phoneDial;

  @override
  int get hashCode =>
      Object.hash(id, city, email, whatsapp, phoneDisplay, phoneDial);
}

/// Una especialidad del equipo de ingeniería con sus contactos por ciudad.
@immutable
final class EngineeringSpecialty {
  const new({
    required this.id,
    required this.name,
    required this.contacts,
    this.description,
    this.whatsappMessage,
  });

  final String id;
  final String name;
  final String? description;
  final String? whatsappMessage;
  final List<EngineeringContact> contacts;

  @override
  bool operator ==(Object other) =>
      other is EngineeringSpecialty &&
      other.id == id &&
      other.name == name &&
      other.description == description &&
      other.whatsappMessage == whatsappMessage &&
      _same(other.contacts, contacts);

  @override
  int get hashCode => Object.hash(id, name, description, contacts.length);
}

/// Lectura **tolerante** de `contact.engineering.specialties`: lo ilegible se
/// descarta uno a uno y un contacto sin ningún canal válido no se muestra.
abstract final class EngineeringTeam {
  static const _maxSpecialties = 6;
  static const _maxContacts = 20;
  static const _maxText = 200;

  static final _digits = RegExp(r'^[0-9]{8,15}$');
  static final _dial = RegExp(r'^\+?[0-9]{6,15}$');
  static final _email = RegExp(r'^[^@\s]{1,64}@[^@\s]+\.[^@\s]{2,}$');

  static List<EngineeringSpecialty> fromJson(Object? json) {
    if (json is! List<Object?>) return const [];
    final out = <EngineeringSpecialty>[];
    for (final item in json) {
      if (out.length >= _maxSpecialties) break;
      if (item is! Map<String, dynamic>) continue;
      final specialty = _specialty(item);
      if (specialty != null) out.add(specialty);
    }
    return List.unmodifiable(out);
  }

  static String? _text(Object? raw, {int max = _maxText}) {
    if (raw is! String) return null;
    final text = raw.trim();
    return text.isEmpty || text.length > max ? null : text;
  }

  static EngineeringSpecialty? _specialty(Map<String, dynamic> json) {
    final id = _text(json['id'], max: 80);
    final name = _text(json['name']);
    if (id == null || name == null) return null;
    final raw = json['contacts'];
    final contacts = <EngineeringContact>[];
    if (raw is List<Object?>) {
      for (final item in raw) {
        if (contacts.length >= _maxContacts) break;
        if (item is! Map<String, dynamic>) continue;
        final contact = _contact(item);
        if (contact != null) contacts.add(contact);
      }
    }
    if (contacts.isEmpty) return null;
    return EngineeringSpecialty(
      id: id,
      name: name,
      description: _text(json['description'], max: 400),
      whatsappMessage: _text(json['whatsappMessage'], max: 300),
      contacts: List.unmodifiable(contacts),
    );
  }

  static EngineeringContact? _contact(Map<String, dynamic> json) {
    final id = _text(json['id'], max: 80);
    final city = _text(json['city'], max: 80);
    if (id == null || city == null) return null;

    final email = _text(json['email'], max: 120);
    final whatsapp = _text(json['whatsapp'], max: 20);
    final dial = _text(json['phoneDial'], max: 20);
    final validEmail = email != null && _email.hasMatch(email) ? email : null;
    final validWhatsapp = whatsapp != null && _digits.hasMatch(whatsapp)
        ? whatsapp
        : null;
    final validDial = dial != null && _dial.hasMatch(dial) ? dial : null;
    if (validEmail == null && validWhatsapp == null && validDial == null) {
      return null;
    }
    return EngineeringContact(
      id: id,
      city: city,
      email: validEmail,
      whatsapp: validWhatsapp,
      phoneDial: validDial,
      // El texto del teléfono solo se muestra si hay a quién marcar.
      phoneDisplay: validDial == null
          ? null
          : (_text(json['phoneDisplay'], max: 60) ?? validDial),
    );
  }
}

bool _same<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
