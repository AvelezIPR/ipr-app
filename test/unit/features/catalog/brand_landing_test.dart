import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/config/home_content.dart';
import 'package:ipr_mobile/features/catalog/data/mappers/catalog_mappers.dart';
import 'package:ipr_mobile/features/catalog/domain/entities/brand_landing.dart';

BrandLanding _map(Object? body) => mapBrandLanding(body);

Map<String, dynamic> _body(List<Object?> blocks, {Object? slug = 'daikin'}) => {
  'data': {'slug': slug, 'blocks': blocks},
};

Map<String, dynamic> _hero({
  Object? title = 'Daikin',
  Object? accent = '#0B2A3F',
  Object? image,
  Object? ctaLabel,
  Object? target,
}) => {
  'type': 'hero',
  'title': title,
  'subtitle': 'Perfecting the Air',
  'accentColor': accent,
  'image': image,
  'ctaLabel': ctaLabel,
  'target': target,
};

Map<String, dynamic> _faq(List<Object?> items) => {
  'type': 'faq',
  'title': 'Preguntas',
  'items': items,
};

const Map<String, Object> _cta = {
  'type': 'cta',
  'title': 'Proyecto',
  'body': 'Te acompañamos.',
  'ctaLabel': 'Hablar con ingeniería',
  'target': {'kind': 'engineering'},
};

void main() {
  group('W3-01 · BrandAccent (guarda de contraste)', () {
    test('acepta colores oscuros con texto blanco legible', () {
      expect(BrandAccent.tryParse('#0B2A3F'), 0xFF0B2A3F);
      expect(BrandAccent.tryParse('#1428A0'), 0xFF1428A0); // Samsung
      expect(BrandAccent.tryParse('#07628E'), 0xFF07628E); // azul de IPR
      expect(BrandAccent.tryParse('#000000'), 0xFF000000);
    });

    test('rechaza colores claros donde el blanco no se lee', () {
      expect(BrandAccent.tryParse('#0098D1'), isNull); // Midea: ~3,3:1
      expect(BrandAccent.tryParse('#0097E0'), isNull); // azul Daikin: ~3:1
      expect(BrandAccent.tryParse('#7DBF3C'), isNull);
      expect(BrandAccent.tryParse('#FFFFFF'), isNull);
    });

    test('rechaza formatos que no son #RRGGBB', () {
      for (final bad in [
        null,
        '',
        '0B2A3F',
        '#0B2A3',
        '#0B2A3F0',
        '#GGGGGG',
        'red',
        'rgb(0,0,0)',
      ]) {
        expect(BrandAccent.tryParse(bad), isNull, reason: '$bad');
      }
    });

    test('el contraste del blanco sobre negro es 21 y sobre blanco 1', () {
      expect(BrandAccent.contrastWithWhite(0xFF000000), closeTo(21, 0.01));
      expect(BrandAccent.contrastWithWhite(0xFFFFFFFF), closeTo(1, 0.01));
    });
  });

  group('W3-01 · mapBrandLanding (lectura tolerante)', () {
    test('lee portada, preguntas y llamado a la acción', () {
      final landing = _map(
        _body([
          _hero(),
          _faq([
            {'title': '¿Garantía?', 'body': 'Sí.'},
          ]),
          _cta,
        ]),
      );
      expect(landing.slug, 'daikin');
      expect(landing.blocks.map((b) => b.type), [
        BrandBlockType.hero,
        BrandBlockType.faq,
        BrandBlockType.cta,
      ]);
      expect(landing.blocks.first.accentArgb, 0xFF0B2A3F);
      expect(landing.blocks[1].items.single.title, '¿Garantía?');
      expect(landing.blocks.last.target!.kind, HomeTargetKind.engineering);
      expect(landing.blocks.last.hasCta, isTrue);
    });

    test('un color claro se descarta pero la portada se conserva', () {
      final hero = _map(_body([_hero(accent: '#0098D1')])).blocks.single;
      expect(hero.accentArgb, isNull);
      expect(hero.title, 'Daikin');
    });

    test('un cuerpo que no es {data: {...}} lanza FormatException', () {
      for (final bad in [
        null,
        'x',
        <Object?>[],
        {'data': 5},
        {'data': <Object?>[]},
      ]) {
        expect(() => _map(bad), throwsFormatException, reason: '$bad');
      }
    });

    test('una landing sin slug lanza FormatException', () {
      expect(() => _map(_body(const [], slug: null)), throwsFormatException);
      expect(() => _map(_body(const [], slug: '')), throwsFormatException);
    });

    test('bloques sin lo mínimo se omiten sin romper el resto', () {
      final landing = _map(
        _body([
          _hero(title: ''),
          _hero(title: null),
          {'type': 'text', 'title': 'Solo título'},
          {'type': 'highlights', 'items': <Object?>[]},
          _faq([
            {'title': 'Sin respuesta'},
            {'body': 'Sin pregunta'},
            'basura',
          ]),
          {'type': 'cta', 'title': 'Sin botón'},
          {'type': 'nuevo-bloque-del-futuro', 'title': 'x'},
          'basura',
          {'type': 7},
          {'type': 'text', 'title': 'Bueno', 'body': 'Texto.\n\nOtro párrafo.'},
        ]),
      );
      expect(landing.blocks.single.type, BrandBlockType.text);
      expect(landing.blocks.single.title, 'Bueno');
    });

    test('un destino inválido descarta el botón, no la portada', () {
      final hero = _map(
        _body([
          _hero(
            ctaLabel: 'Ir',
            target: {'kind': 'web', 'ref': 'http://iprpartesyrepuestos.com'},
          ),
        ]),
      ).blocks.single;
      expect(hero.hasCta, isFalse);
      expect(hero.target, isNull);
      expect(hero.ctaLabel, isNull);
    });

    test('un cta con destino inválido se omite entero', () {
      expect(
        _map(
          _body([
            {
              'type': 'cta',
              'title': 'X',
              'ctaLabel': 'Ir',
              'target': {'kind': 'abrir-ajustes'},
            },
          ]),
        ).blocks,
        isEmpty,
      );
    });

    test('la imagen solo se acepta si es https con host', () {
      BrandBlock hero(Object? url) => _map(
        _body([
          _hero(image: {'url': url}),
        ]),
      ).blocks.single;
      expect(hero('https://iprpartesyrepuestos.com/a.png').imageUrl, isNotNull);
      for (final bad in [
        'http://iprpartesyrepuestos.com/a.png',
        'javascript:alert(1)',
        'https://u:p@iprpartesyrepuestos.com/a.png',
        'https:///a.png',
        '',
        null,
      ]) {
        expect(hero(bad).imageUrl, isNull, reason: '$bad');
      }
    });

    test('textos enormes o de otro tipo se descartan', () {
      final landing = _map(
        _body([
          {'type': 'text', 'body': 'x' * 2001},
          {'type': 'text', 'body': 5},
          {'type': 'text', 'body': '  '},
          {'type': 'text', 'body': 'ok'},
        ]),
      );
      expect(landing.blocks.single.body, 'ok');
    });

    test('respeta los topes de bloques (12) y de elementos (12)', () {
      final blocks = _map(
        _body([
          for (var i = 0; i < 20; i++) {'type': 'text', 'body': 'p$i'},
        ]),
      ).blocks;
      expect(blocks, hasLength(12));

      final items = _map(
        _body([
          _faq([
            for (var i = 0; i < 20; i++) {'title': 'q$i', 'body': 'a$i'},
          ]),
        ]),
      ).blocks.single.items;
      expect(items, hasLength(12));
    });

    test('sin bloques válidos la landing queda vacía', () {
      expect(_map(_body(const [])).isEmpty, isTrue);
      expect(_map(_body(['x', 3])).isEmpty, isTrue);
      expect(
        _map({
          'data': {'slug': 'x'},
        }).isEmpty,
        isTrue,
      );
    });
  });

  group('W3-01 · entidades BrandLanding (igualdad, hashCode y helpers)', () {
    test(
      'BrandBlockType.tryParse reconoce todos los valores y rechaza otros',
      () {
        for (final type in BrandBlockType.values) {
          expect(BrandBlockType.tryParse(type.name), type);
        }
        expect(BrandBlockType.tryParse('unknown'), isNull);
        expect(BrandBlockType.tryParse(null), isNull);
        expect(BrandBlockType.tryParse(42), isNull);
      },
    );

    test('BrandBlockItem compara por valor y expone hashCode', () {
      const a = BrandBlockItem(title: 'T', body: 'B');
      const b = BrandBlockItem(title: 'T', body: 'B');
      const c = BrandBlockItem(title: 'T', body: 'Otro');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
    });

    test('BrandBlock compara por valor, hasCta y lista de items', () {
      const target = HomeTarget(HomeTargetKind.engineering);
      const item1 = BrandBlockItem(title: 'P1', body: 'R1');
      const item2 = BrandBlockItem(title: 'P2', body: 'R2');

      const base = BrandBlock(
        type: BrandBlockType.hero,
        title: 'Daikin',
        subtitle: 'Sub',
        body: 'Cuerpo',
        imageUrl: 'https://iprpartesyrepuestos.com/a.png',
        accentArgb: 0xFF0B2A3F,
        items: [item1],
        ctaLabel: 'Ir',
        target: target,
      );
      const same = BrandBlock(
        type: BrandBlockType.hero,
        title: 'Daikin',
        subtitle: 'Sub',
        body: 'Cuerpo',
        imageUrl: 'https://iprpartesyrepuestos.com/a.png',
        accentArgb: 0xFF0B2A3F,
        items: [BrandBlockItem(title: 'P1', body: 'R1')],
        ctaLabel: 'Ir',
        target: target,
      );

      expect(base, same);
      expect(base.hashCode, same.hashCode);
      expect(base.hasCta, isTrue);

      const onlyLabel = BrandBlock(type: BrandBlockType.cta, ctaLabel: 'Ir');
      const onlyTarget = BrandBlock(type: BrandBlockType.cta, target: target);
      expect(onlyLabel.hasCta, isFalse);
      expect(onlyTarget.hasCta, isFalse);

      expect(
        base ==
            const BrandBlock(
              type: BrandBlockType.hero,
              title: 'Daikin',
              subtitle: 'Sub',
              body: 'Cuerpo',
              imageUrl: 'https://iprpartesyrepuestos.com/a.png',
              accentArgb: 0xFF0B2A3F,
              items: [item2],
              ctaLabel: 'Ir',
              target: target,
            ),
        isFalse,
      );
      expect(
        base ==
            const BrandBlock(
              type: BrandBlockType.hero,
              title: 'Daikin',
              subtitle: 'Sub',
              body: 'Cuerpo',
              imageUrl: 'https://iprpartesyrepuestos.com/a.png',
              accentArgb: 0xFF0B2A3F,
              items: [item1, item2],
              ctaLabel: 'Ir',
              target: target,
            ),
        isFalse,
      );
      expect(
        base == const BrandBlock(type: BrandBlockType.text, title: 'Daikin'),
        isFalse,
      );
    });

    test('BrandLanding compara por valor, isEmpty y hashCode', () {
      const block = BrandBlock(type: BrandBlockType.text, body: 'Hola');
      const a = BrandLanding(slug: 'daikin', blocks: [block]);
      const b = BrandLanding(
        slug: 'daikin',
        blocks: [BrandBlock(type: BrandBlockType.text, body: 'Hola')],
      );
      const otherSlug = BrandLanding(slug: 'elitech', blocks: [block]);
      const empty = BrandLanding(slug: 'daikin', blocks: []);

      expect(a.isEmpty, isFalse);
      expect(empty.isEmpty, isTrue);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == otherSlug, isFalse);
      expect(a == empty, isFalse);
    });
  });
}
