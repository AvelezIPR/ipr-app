import 'package:meta/meta.dart';

/// Un punto del mapa, en las unidades del `viewBox` del asset.
typedef MapPoint = ({double x, double y});

/// Departamento del mapa: uno o varios polígonos cerrados (islas incluidas).
@immutable
final class MapDepartment {
  const new({required this.code, required this.name, required this.polygons});

  /// Código DANE del departamento.
  final String code;
  final String name;
  final List<List<MapPoint>> polygons;

  @override
  bool operator ==(Object other) =>
      other is MapDepartment && other.code == code && other.name == name;

  @override
  int get hashCode => Object.hash(code, name);
}

/// Posición de una ciudad con sede, en las unidades del `viewBox` (clave =
/// nombre de la ciudad tal como llega en `Branch.city`).
@immutable
final class MapCity {
  const new({
    required this.name,
    required this.department,
    required this.x,
    required this.y,
  });

  final String name;
  final String department;
  final double x;
  final double y;

  @override
  bool operator ==(Object other) =>
      other is MapCity &&
      other.name == name &&
      other.department == department &&
      other.x == x &&
      other.y == y;

  @override
  int get hashCode => Object.hash(name, department, x, y);
}

/// Mapa de Colombia por departamentos para ubicar las sedes (W3-03).
///
/// La geometría es la del mapa de la web (límites del DANE, MGN 2018, ya
/// proyectados y simplificados) y se empaqueta como asset: la app no
/// depende de ningún SDK de mapas ni pide permisos de ubicación. La lectura
/// es **tolerante**: lo ilegible se descarta y nunca lanza.
@immutable
final class ColombiaMap {
  const new({
    required this.width,
    required this.height,
    required this.departments,
    required this.cities,
  });

  /// Lee el JSON del asset (`assets/map/colombia_map.json`).
  factory fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return empty;
    final box = json['viewBox'];
    if (box is! Map<String, dynamic>) return empty;
    final width = _number(box['width']);
    final height = _number(box['height']);
    if (width == null || height == null || width <= 0 || height <= 0) {
      return empty;
    }

    final departments = <MapDepartment>[];
    final rawDepartments = json['departments'];
    if (rawDepartments is List<Object?>) {
      for (final item in rawDepartments) {
        if (item is! Map<String, dynamic>) continue;
        final code = item['code'];
        final name = item['name'];
        final d = item['d'];
        if (code is! String || name is! String || d is! String) continue;
        final polygons = parsePolygons(d);
        if (polygons.isEmpty) continue;
        departments.add(
          MapDepartment(code: code, name: name, polygons: polygons),
        );
      }
    }

    final cities = <String, MapCity>{};
    final rawCities = json['cities'];
    if (rawCities is Map<String, dynamic>) {
      for (final entry in rawCities.entries) {
        final value = entry.value;
        if (value is! Map<String, dynamic>) continue;
        final x = _number(value['x']);
        final y = _number(value['y']);
        // Una ciudad fuera del encuadre no se dibuja.
        if (x == null || y == null) continue;
        if (x < 0 || y < 0 || x > width || y > height) continue;
        cities[entry.key] = MapCity(
          name: entry.key,
          department: value['dept'] is String ? value['dept']! as String : '',
          x: x,
          y: y,
        );
      }
    }

    return ColombiaMap(
      width: width,
      height: height,
      departments: List.unmodifiable(departments),
      cities: Map.unmodifiable(cities),
    );
  }

  /// Sin geometría: la pantalla de Sedes sigue funcionando solo con la lista.
  static const empty = ColombiaMap(
    width: 0,
    height: 0,
    departments: [],
    cities: {},
  );

  final double width;
  final double height;
  final List<MapDepartment> departments;
  final Map<String, MapCity> cities;

  bool get isEmpty => departments.isEmpty;

  /// Departamento al que pertenece [city], si se conoce.
  MapDepartment? departmentOf(String city) {
    final code = cities[city]?.department;
    if (code == null) return null;
    for (final department in departments) {
      if (department.code == code) return department;
    }
    return null;
  }

  /// Lee un path SVG de comandos absolutos `M`, `L` y `Z` (los únicos que
  /// usa el asset) como una lista de polígonos. Cualquier otro comando o un
  /// número ilegible deja ese path vacío: nunca se dibuja una forma a medias.
  static List<List<MapPoint>> parsePolygons(String d) {
    final tokens = _token.allMatches(d).map((m) => m.group(0)!).toList();
    final polygons = <List<MapPoint>>[];
    var current = <MapPoint>[];

    void close() {
      if (current.length >= 3) polygons.add(List.unmodifiable(current));
      current = <MapPoint>[];
    }

    var i = 0;
    while (i < tokens.length) {
      final token = tokens[i];
      switch (token) {
        case 'M':
          close();
          final point = _point(tokens, i + 1);
          if (point == null) return const [];
          current.add(point);
          i += 3;
        case 'L':
          final point = _point(tokens, i + 1);
          if (point == null) return const [];
          current.add(point);
          i += 3;
        case 'Z':
          close();
          i++;
        default:
          // Un número suelto (coordenadas repetidas tras L) o un comando no
          // soportado: no se interpreta.
          return const [];
      }
    }
    close();
    return List.unmodifiable(polygons);
  }

  static final _token = RegExp(r'[A-Za-z]|-?\d+(?:\.\d+)?');

  static MapPoint? _point(List<String> tokens, int at) {
    if (at + 1 >= tokens.length) return null;
    final x = double.tryParse(tokens[at]);
    final y = double.tryParse(tokens[at + 1]);
    if (x == null || y == null) return null;
    return (x: x, y: y);
  }

  static double? _number(Object? raw) => raw is num ? raw.toDouble() : null;
}
