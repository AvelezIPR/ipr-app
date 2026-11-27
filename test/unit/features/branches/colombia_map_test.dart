import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/features/branches/domain/entities/colombia_map.dart';

ColombiaMap _parse(Object? json) => ColombiaMap.fromJson(json);

List<List<MapPoint>> _polygons(String d) => ColombiaMap.parsePolygons(d);

void main() {
  group('W3-03 · ColombiaMap.parsePolygons', () {
    test('lee un polígono cerrado con M, L y Z', () {
      final polygons = _polygons('M0 0L10 0L10 10L0 10Z');
      expect(polygons, hasLength(1));
      expect(polygons.single, hasLength(4));
      expect(polygons.single[2], (x: 10.0, y: 10.0));
    });

    test('un path con varios subpaths da varios polígonos (islas)', () {
      final polygons = _polygons('M0 0L10 0L10 10ZM20 20L30 20L30 30Z');
      expect(polygons, hasLength(2));
      expect(polygons.last.first, (x: 20.0, y: 20.0));
    });

    test('lee decimales y negativos', () {
      final polygons = _polygons('M-1.5 2.25L3 -4L5.5 6Z');
      expect(polygons.single.first, (x: -1.5, y: 2.25));
      expect(polygons.single[1], (x: 3.0, y: -4.0));
    });

    test('un polígono sin Z se cierra al llegar a otro M o al final', () {
      expect(_polygons('M0 0L10 0L10 10'), hasLength(1));
    });

    test('menos de tres puntos no es una forma', () {
      expect(_polygons('M0 0L10 0Z'), isEmpty);
      expect(_polygons(''), isEmpty);
    });

    test('comandos no soportados o números ilegibles dejan el path vacío', () {
      for (final bad in [
        'M0 0C1 1 2 2 3 3Z',
        'M0 0l10 0l0 10z',
        'M0 0L10 0L10',
        'M0L10 0L10 10Z',
        'M0 0L10 0 10 10Z',
        'M0 0LxL10 10L5 5Z',
      ]) {
        expect(_polygons(bad), isEmpty, reason: bad);
      }
    });
  });

  group('W3-03 · ColombiaMap.fromJson', () {
    test('sin datos o con tipos raros queda vacío', () {
      expect(_parse(null).isEmpty, isTrue);
      expect(_parse('x').isEmpty, isTrue);
      expect(_parse({'viewBox': 5}).isEmpty, isTrue);
      expect(
        _parse({
          'viewBox': {'width': 0, 'height': 10},
        }).isEmpty,
        isTrue,
      );
    });

    test('descarta lo ilegible sin tirar el resto', () {
      final map = _parse({
        'viewBox': {'width': 100, 'height': 100},
        'departments': [
          {'code': '05', 'name': 'Antioquia', 'd': 'M0 0L10 0L10 10Z'},
          {'code': '08', 'name': 'Roto', 'd': 'M0 0C1 1 2 2 3 3Z'},
          {'code': 7, 'name': 'Sin código', 'd': 'M0 0L1 0L1 1Z'},
          'basura',
        ],
        'cities': {
          'Medellín': {'dept': '05', 'x': 50, 'y': 40},
          'Fuera': {'dept': '05', 'x': 500, 'y': 40},
          'SinY': {'dept': '05', 'x': 5},
          'Mal': 'x',
        },
      });
      expect(map.departments.map((d) => d.code), ['05']);
      expect(map.cities.keys, ['Medellín']);
      expect(map.departmentOf('Medellín')!.name, 'Antioquia');
      expect(map.departmentOf('Fuera'), isNull);
      expect(map.isEmpty, isFalse);
    });

    test('una ciudad cuyo departamento no existe no tiene departamento', () {
      final map = _parse({
        'viewBox': {'width': 100, 'height': 100},
        'departments': [
          {'code': '05', 'name': 'Antioquia', 'd': 'M0 0L10 0L10 10Z'},
        ],
        'cities': {
          'Cali': {'dept': '76', 'x': 10, 'y': 10},
        },
      });
      expect(map.cities.containsKey('Cali'), isTrue);
      expect(map.departmentOf('Cali'), isNull);
    });
  });

  group('W3-03 · asset real (assets/map/colombia_map.json)', () {
    final map = _parse(
      jsonDecode(File('assets/map/colombia_map.json').readAsStringSync()),
    );

    test('trae la geometría de los departamentos', () {
      expect(map.isEmpty, isFalse);
      expect(map.width, 513);
      expect(map.height, 694);
      expect(map.departments.length, greaterThanOrEqualTo(30));
      for (final department in map.departments) {
        expect(department.polygons, isNotEmpty, reason: department.name);
      }
    });

    test('todos los puntos están dentro del encuadre', () {
      for (final department in map.departments) {
        for (final polygon in department.polygons) {
          for (final point in polygon) {
            expect(point.x, inInclusiveRange(0, map.width));
            expect(point.y, inInclusiveRange(0, map.height));
          }
        }
      }
    });

    test('las 10 ciudades con sede tienen posición y departamento', () {
      expect(
        map.cities.keys,
        containsAll(<String>[
          'Medellín',
          'Rionegro',
          'Apartadó',
          'Cali',
          'Barranquilla',
          'Bucaramanga',
          'Bogotá',
          'Montería',
          'Villavicencio',
          'Cartagena',
        ]),
      );
      for (final city in map.cities.keys) {
        expect(map.departmentOf(city), isNotNull, reason: city);
      }
    });

    test(
      'Bogotá cae dentro del recuadro del departamento de Cundinamarca/Bogotá',
      () {
        final city = map.cities['Bogotá']!;
        final department = map.departmentOf('Bogotá')!;
        final xs = [for (final p in department.polygons.expand((q) => q)) p.x];
        final ys = [for (final p in department.polygons.expand((q) => q)) p.y];
        expect(
          city.x,
          inInclusiveRange(
            xs.reduce((a, b) => a < b ? a : b),
            xs.reduce((a, b) => a > b ? a : b),
          ),
        );
        expect(
          city.y,
          inInclusiveRange(
            ys.reduce((a, b) => a < b ? a : b),
            ys.reduce((a, b) => a > b ? a : b),
          ),
        );
      },
    );
  });
}
