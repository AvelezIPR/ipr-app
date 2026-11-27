import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/config/engineering_team.dart';
import 'package:ipr_mobile/core/config/remote_config_dto.dart';

Map<String, dynamic> _contact({
  Object? id = 'refri-medellin',
  Object? city = 'Medellín',
  Object? email = 'ingenieriamedellin@example.invalid',
  Object? whatsapp = '573011384281',
  Object? phoneDisplay = '6043604440 ext. 1151',
  Object? phoneDial = '6043604440',
}) => {
  'id': id,
  'city': city,
  'email': email,
  'whatsapp': whatsapp,
  'phoneDisplay': phoneDisplay,
  'phoneDial': phoneDial,
};

Map<String, dynamic> _specialty({
  Object? id = 'refrigeracion',
  Object? name = 'Refrigeración Comercial e Industrial',
  Object? contacts,
}) => {
  'id': id,
  'name': name,
  'description': 'Cuartos fríos, cámaras y procesos',
  'whatsappMessage': 'Hola, quiero hablar con ingeniería en refrigeración',
  'contacts': contacts ?? [_contact()],
};

List<EngineeringSpecialty> _parse(Object? json) =>
    EngineeringTeam.fromJson(json);

RemoteConfigDto _dto(Map<String, dynamic> json) =>
    RemoteConfigDto.fromJson(json);

void main() {
  group('W3-02 · EngineeringTeam.fromJson (lectura tolerante)', () {
    test('sin datos o con tipos raros queda vacío', () {
      expect(_parse(null), isEmpty);
      expect(_parse('x'), isEmpty);
      expect(_parse({'a': 1}), isEmpty);
      expect(_parse(<Object?>[]), isEmpty);
    });

    test('lee especialidades y contactos por ciudad', () {
      final specialties = _parse([_specialty()]);
      final specialty = specialties.single;
      expect(specialty.name, 'Refrigeración Comercial e Industrial');
      expect(specialty.description, 'Cuartos fríos, cámaras y procesos');
      expect(specialty.whatsappMessage, contains('refrigeración'));
      final contact = specialty.contacts.single;
      expect(contact.city, 'Medellín');
      expect(contact.whatsapp, '573011384281');
      expect(contact.phoneDial, '6043604440');
      expect(contact.phoneDisplay, '6043604440 ext. 1151');
      expect(contact.hasPhone, isTrue);
    });

    test('un canal inválido se ignora y los demás siguen', () {
      final contact = _parse([
        _specialty(
          contacts: [
            _contact(
              email: 'no-es-un-correo',
              whatsapp: '+57 301 138',
              phoneDial: '604-360',
            ),
            _contact(id: 'solo-correo', whatsapp: null, phoneDial: null),
            _contact(id: 'solo-wa', email: null, phoneDial: null),
            _contact(id: 'solo-tel', email: null, whatsapp: null),
          ],
        ),
      ]).single.contacts;
      // El primero no tiene ningún canal válido: se descarta entero.
      expect(contact.map((c) => c.id), ['solo-correo', 'solo-wa', 'solo-tel']);
      expect(contact[0].email, isNotNull);
      expect(contact[0].whatsapp, isNull);
      expect(contact[1].whatsapp, '573011384281');
      expect(contact[2].phoneDial, '6043604440');
    });

    test('el texto del teléfono solo existe si hay a quién marcar', () {
      final contact = _parse([
        _specialty(
          contacts: [
            _contact(phoneDial: null, phoneDisplay: '6043604440 ext. 1'),
            _contact(id: 'b', phoneDisplay: null),
          ],
        ),
      ]).single.contacts;
      expect(contact[0].phoneDisplay, isNull);
      expect(contact[0].hasPhone, isFalse);
      // Sin texto, se muestra el número.
      expect(contact[1].phoneDisplay, '6043604440');
    });

    test('una especialidad sin contactos válidos no se muestra', () {
      expect(
        _parse([
          _specialty(contacts: <Object?>[]),
          _specialty(id: 'b', contacts: ['x', 5]),
          _specialty(id: ''),
          _specialty(name: null),
          'basura',
        ]),
        isEmpty,
      );
    });

    test('textos vacíos o enormes se descartan', () {
      final contacts = _parse([
        _specialty(
          contacts: [
            _contact(city: ''),
            _contact(id: 'c' * 81),
            _contact(id: 'ok', city: 'Cali'),
          ],
        ),
      ]).single.contacts;
      expect(contacts.single.city, 'Cali');
    });

    test('respeta los topes de especialidades y de contactos', () {
      final specialties = _parse([
        for (var i = 0; i < 9; i++)
          _specialty(
            id: 's$i',
            contacts: [for (var j = 0; j < 30; j++) _contact(id: 'c$j')],
          ),
      ]);
      expect(specialties, hasLength(6));
      expect(specialties.first.contacts, hasLength(20));
    });

    test('la descripción y el mensaje son opcionales', () {
      final specialty = _parse([
        {
          'id': 'aire',
          'name': 'Aire',
          'contacts': [_contact()],
        },
      ]).single;
      expect(specialty.description, isNull);
      expect(specialty.whatsappMessage, isNull);
    });
  });

  group('W3-02 · /config → RemoteConfig.engineeringSpecialties', () {
    test('el DTO entrega el equipo y es opcional', () {
      final withTeam = _dto({
        'contact': {
          'engineering': {
            'whatsapp': '573001112233',
            'email': 'ing@example.invalid',
            'specialties': [_specialty()],
          },
        },
      }).toEntity(platform: 'android');
      expect(withTeam.engineeringSpecialties, hasLength(1));
      expect(withTeam.engineeringWhatsapp, '573001112233');

      final without = _dto({
        'contact': {
          'engineering': {'whatsapp': null, 'email': null},
        },
      }).toEntity(platform: 'android');
      expect(without.engineeringSpecialties, isEmpty);
    });

    test('un equipo corrupto no rompe el canal general', () {
      final config = _dto({
        'contact': {
          'engineering': {
            'whatsapp': '573001112233',
            'email': null,
            'specialties': 'roto',
          },
        },
      }).toEntity(platform: 'android');
      expect(config.engineeringWhatsapp, '573001112233');
      expect(config.engineeringSpecialties, isEmpty);
    });
  });
}
