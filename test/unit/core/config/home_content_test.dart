import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/config/home_content.dart';
import 'package:ipr_mobile/core/config/remote_config_dto.dart';

Map<String, dynamic> _banner({
  Object? id = 'jugada-samsung',
  Object? alt = 'Jugada Navideña Samsung X IPR',
  Object? image = 'https://iprpartesyrepuestos.com/slider-main/a.webp',
  Object? target = const {
    'kind': 'web',
    'ref': 'https://iprpartesyrepuestos.com/jugada-samsung',
  },
}) => {
  'id': id,
  'alt': alt,
  'image': {'url': image, 'alt': ''},
  'target': target,
};

HomeTarget? _target(Object? json) => HomeTarget.tryFromJson(json);

// Funciones intermedias: los literales no se pasan a constructores de clases
// inmutables (lint), y así las pruebas pueden escribir el JSON tal cual.
HomeContent _content(Object? json) => HomeContent.fromJson(json);

RemoteConfigDto _dto(Map<String, dynamic> json) =>
    RemoteConfigDto.fromJson(json);

void main() {
  group('W2 · HomeTarget (destino validado)', () {
    test('categoría, producto y marca exigen un slug válido', () {
      for (final kind in ['category', 'product', 'brand']) {
        expect(_target({'kind': kind, 'ref': 'aire-acondicionado'}), isNotNull);
        for (final bad in [null, '', 'Aire', '../x', 'a b', '-x', 'x' * 201]) {
          expect(
            _target({'kind': kind, 'ref': bad}),
            isNull,
            reason: '$kind $bad',
          );
        }
      }
    });

    test('pantallas propias no necesitan ref', () {
      for (final kind in [
        'sale',
        'branches',
        'engineering',
        'support',
        'calculator',
      ]) {
        final target = _target({'kind': kind});
        expect(target, isNotNull, reason: kind);
        expect(target!.ref, isNull);
      }
    });

    test('web solo acepta https con host y sin credenciales', () {
      expect(
        _target({'kind': 'web', 'ref': 'https://iprpartesyrepuestos.com/x'}),
        isNotNull,
      );
      for (final bad in [
        'http://iprpartesyrepuestos.com/x',
        'javascript:alert(1)',
        'intent://x#Intent;end',
        'file:///etc/passwd',
        'https://user:pw@iprpartesyrepuestos.com/x',
        'https:///sin-host',
        '/solo/ruta',
        '',
        null,
        'https://iprpartesyrepuestos.com/${'a' * 600}',
      ]) {
        expect(_target({'kind': 'web', 'ref': bad}), isNull, reason: '$bad');
      }
    });

    test('whatsapp exige un mensaje acotado', () {
      expect(_target({'kind': 'whatsapp', 'ref': 'Hola IPR'}), isNotNull);
      expect(_target({'kind': 'whatsapp', 'ref': ''}), isNull);
      expect(_target({'kind': 'whatsapp', 'ref': 'x' * 301}), isNull);
      expect(_target({'kind': 'whatsapp'}), isNull);
    });

    test('un kind desconocido o un destino ilegible se descarta', () {
      expect(_target({'kind': 'abrir-ajustes'}), isNull);
      expect(_target({'kind': 7}), isNull);
      expect(_target('web'), isNull);
      expect(_target(null), isNull);
    });
  });

  group('W2 · HomeContent.fromJson (lectura tolerante)', () {
    test('sin datos o con tipos raros queda vacío', () {
      expect(_content(null), HomeContent.empty);
      expect(_content('x'), HomeContent.empty);
      expect(_content(const <Object?>[]), HomeContent.empty);
      expect(_content({'banners': 'x', 'stats': 3}).isEmpty, isTrue);
    });

    test('lee campañas, cifras y destacados', () {
      final content = _content({
        'banners': [_banner()],
        'stats': [
          {
            'id': 'years',
            'value': '+30',
            'unit': 'años',
            'label': 'Importando',
          },
          {'id': 'branches', 'value': '31', 'label': 'Sedes'},
        ],
        'highlights': [
          {
            'id': 'training',
            'eyebrow': 'Formación técnica',
            'title': 'Capacitaciones',
            'body': 'Jornadas con las marcas.',
            'cta': 'Ver capacitaciones',
            'image': {
              'url': 'https://iprpartesyrepuestos.com/x.png',
              'alt': '',
            },
            'target': {
              'kind': 'web',
              'ref': 'https://iprpartesyrepuestos.com/capacitaciones',
            },
          },
        ],
      });
      expect(content.banners.single.target.kind, HomeTargetKind.web);
      expect(content.stats.map((s) => s.spoken), ['+30 años', '31']);
      expect(content.highlights.single.eyebrow, 'Formación técnica');
      expect(content.highlights.single.imageUrl, isNotNull);
      expect(content.isEmpty, isFalse);
    });

    test('una campaña inválida se descarta y no arrastra a las demás', () {
      final content = _content({
        'banners': [
          _banner(id: 'ok'),
          _banner(alt: ''),
          _banner(alt: null),
          _banner(id: ''),
          _banner(image: 'http://iprpartesyrepuestos.com/a.webp'),
          _banner(image: null),
          _banner(target: {'kind': 'web', 'ref': 'http://x.com'}),
          _banner(target: {'kind': 'nuevo'}),
          'basura',
          _banner(id: 'ok2', target: const {'kind': 'sale'}),
        ],
      });
      expect(content.banners.map((b) => b.id), ['ok', 'ok2']);
    });

    test('respeta los topes de cantidad', () {
      final content = _content({
        'banners': [for (var i = 0; i < 20; i++) _banner(id: 'b$i')],
        'stats': [
          for (var i = 0; i < 20; i++)
            {'id': 's$i', 'value': '$i', 'label': 'x'},
        ],
      });
      expect(content.banners, hasLength(10));
      expect(content.stats, hasLength(6));
    });

    test('textos vacíos, enormes o de otro tipo se descartan', () {
      final content = _content({
        'stats': [
          {'id': 'a', 'value': '', 'label': 'x'},
          {'id': 'b', 'value': '1', 'label': ''},
          {'id': 'c', 'value': 5, 'label': 'x'},
          {'id': 'd', 'value': '1', 'label': 'y' * 401},
          {'id': 'e', 'value': '2', 'label': 'ok', 'unit': 7},
        ],
        'highlights': [
          {
            'id': 'h',
            'title': 'T',
            'body': 'B',
            'cta': '',
            'target': {'kind': 'sale'},
          },
        ],
      });
      expect(content.stats.map((s) => s.id), ['e']);
      expect(content.stats.single.unit, isNull);
      expect(content.highlights, isEmpty);
    });

    test('un destacado con imagen insegura se conserva sin imagen', () {
      final content = _content({
        'highlights': [
          {
            'id': 'h',
            'title': 'T',
            'body': 'B',
            'cta': 'Ir',
            'image': {'url': 'http://x.com/a.png'},
            'target': {'kind': 'engineering'},
          },
        ],
      });
      expect(content.highlights.single.imageUrl, isNull);
    });

    test('la cifra se lee junta con su unidad', () {
      const withUnit = HomeStat(
        id: 'a',
        value: '+30',
        unit: 'años',
        label: 'x',
      );
      const without = HomeStat(id: 'b', value: '31', label: 'x');
      expect(withUnit.spoken, '+30 años');
      expect(without.spoken, '31');
    });

    test('HomeStat.target acepta destinos válidos (branches, category)', () {
      final content = _content({
        'stats': [
          {
            'id': 'branches',
            'value': '31',
            'label': 'Sedes',
            'target': {'kind': 'branches'},
          },
          {
            'id': 'refs',
            'value': '+10.000',
            'label': 'Referencias',
            'target': {'kind': 'category', 'ref': 'aire-acondicionado'},
          },
        ],
      });
      expect(
        content.stats[0].target,
        const HomeTarget(HomeTargetKind.branches),
      );
      expect(
        content.stats[1].target,
        const HomeTarget(HomeTargetKind.category, 'aire-acondicionado'),
      );
      expect(
        content.stats[0],
        const HomeStat(
          id: 'branches',
          value: '31',
          label: 'Sedes',
          target: HomeTarget(HomeTargetKind.branches),
        ),
      );
      expect(
        content.stats[0] ==
            const HomeStat(id: 'branches', value: '31', label: 'Sedes'),
        isFalse,
      );
    });

    test(
      'HomeStat con target inválido conserva la cifra y deja target en null',
      () {
        final content = _content({
          'stats': [
            {
              'id': 'branches',
              'value': '31',
              'label': 'Sedes',
              'target': {'kind': 'desconocido'},
            },
            {
              'id': 'refs',
              'value': '+10.000',
              'label': 'Referencias',
              'target': {'kind': 'category', 'ref': 'INVALIDO'},
            },
          ],
        });
        expect(content.stats, hasLength(2));
        expect(content.stats[0].id, 'branches');
        expect(content.stats[0].value, '31');
        expect(content.stats[0].target, isNull);
        expect(content.stats[1].id, 'refs');
        expect(content.stats[1].target, isNull);
      },
    );
  });

  group('W2 · /config → RemoteConfig.home', () {
    test('el DTO entrega el contenido y es opcional', () {
      final withHome = _dto({
        'home': {
          'banners': [_banner()],
        },
      }).toEntity(platform: 'android');
      expect(withHome.home.banners, hasLength(1));

      final without = _dto(const {}).toEntity(platform: 'android');
      expect(without.home, HomeContent.empty);
    });

    test('un home corrupto no rompe el resto de la configuración', () {
      final config = _dto({
        'features': {'checkoutEnabled': true},
        'home': 'roto',
      }).toEntity(platform: 'android');
      expect(config.checkoutEnabled, isTrue);
      expect(config.home.isEmpty, isTrue);
    });
  });
}
