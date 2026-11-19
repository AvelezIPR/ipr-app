import 'dart:io';

import 'package:yaml/yaml.dart';

/// Lectura del contrato `/mobile/v1` (OpenAPI 3.1) con un validador de
/// esquemas mínimo y un sintetizador de ejemplos. Lo usan el BFF simulado y
/// `ci/check_openapi_fixtures.dart`.
///
/// **Alcance del validador** (el subconjunto de JSON Schema que usa
/// `openapi.yaml`): `$ref` local, `allOf`, `oneOf`, `anyOf`, `type` (también
/// listas con `null`), `const`, `enum`, `required`, `properties`,
/// `additionalProperties: false`, `items`, `minItems`/`maxItems`,
/// `minLength`/`maxLength`, `pattern`, `minimum`/`maximum` y los formatos
/// `uuid`, `date-time`, `uri` y `email`. No es un validador completo de JSON
/// Schema 2020-12.
final class OpenApiContract {
  new(this.doc);

  factory load(String path) {
    final yaml = loadYaml(File(path).readAsStringSync());
    return OpenApiContract(_plain(yaml)! as Map<String, dynamic>);
  }

  final Map<String, dynamic> doc;

  static Object? _plain(Object? value) {
    if (value is YamlMap) {
      return {for (final e in value.entries) e.key.toString(): _plain(e.value)};
    }
    if (value is YamlList) return [for (final v in value) _plain(v)];
    return value;
  }

  /// ¿La operación exige `Authorization`? `security: [{}, {bearerAuth: []}]`
  /// significa autenticación OPCIONAL (p. ej. `/pqrs`): no es privada.
  static bool requiresAuth(Map<String, dynamic> operation) {
    final security = operation['security'];
    if (security is! List<dynamic> || security.isEmpty) return false;
    return !security.any((e) => e is Map<String, dynamic> && e.isEmpty);
  }

  Map<String, dynamic> get paths => doc['paths'] as Map<String, dynamic>;

  Map<String, dynamic> get components =>
      doc['components'] as Map<String, dynamic>;

  Map<String, dynamic> get schemas =>
      components['schemas'] as Map<String, dynamic>;

  /// Esquema por nombre (`components.schemas.<name>`).
  Map<String, dynamic> schema(String name) {
    final s = schemas[name];
    if (s is! Map<String, dynamic>) {
      throw ArgumentError('Esquema inexistente en el contrato: $name');
    }
    return s;
  }

  /// Sigue `$ref` locales (`#/components/...`).
  Map<String, dynamic> resolve(Map<String, dynamic> node) {
    var current = node;
    var guard = 0;
    while (current.containsKey(r'$ref')) {
      if (++guard > 20) throw StateError(r'$ref circular');
      final ref = current[r'$ref'] as String;
      if (!ref.startsWith('#/')) {
        throw UnsupportedError('Referencia no local: $ref');
      }
      Object? target = doc;
      for (final part in ref.substring(2).split('/')) {
        target = (target! as Map<String, dynamic>)[part];
      }
      current = target! as Map<String, dynamic>;
    }
    return current;
  }

  // ── Validación ───────────────────────────────────────────────────────────

  /// Errores de [value] frente a [schemaNode]; vacío si es válido.
  List<String> validate(
    Object? value,
    Map<String, dynamic> schemaNode, [
    String at = r'$',
  ]) {
    final s = resolve(schemaNode);
    final errors = <String>[];

    final allOf = s['allOf'];
    if (allOf is List<dynamic>) {
      for (final sub in allOf) {
        errors.addAll(validate(value, sub as Map<String, dynamic>, at));
      }
    }
    final oneOf = s['oneOf'];
    if (oneOf is List<dynamic>) {
      final passing = oneOf
          .where(
            (sub) => validate(value, sub as Map<String, dynamic>, at).isEmpty,
          )
          .length;
      if (passing != 1) {
        errors.add(
          '$at: debe cumplir exactamente una de oneOf (cumple $passing)',
        );
      }
    }
    final anyOf = s['anyOf'];
    if (anyOf is List<dynamic> &&
        !anyOf.any(
          (sub) => validate(value, sub as Map<String, dynamic>, at).isEmpty,
        )) {
      errors.add('$at: no cumple ninguna de anyOf');
    }

    if (s.containsKey('const') && s['const'] != value) {
      errors.add('$at: debe ser ${s['const']}');
    }
    final enumValues = s['enum'];
    if (enumValues is List<dynamic> && !enumValues.contains(value)) {
      errors.add('$at: "$value" no está en $enumValues');
    }

    final type = s['type'];
    if (type != null) {
      final types = type is List<dynamic>
          ? type.cast<String>()
          : [type as String];
      if (!types.any((t) => _isType(value, t))) {
        errors.add(
          '$at: tipo ${_typeName(value)} no permitido (${types.join('|')})',
        );
        return errors;
      }
    }

    if (value is String) _validateString(value, s, at, errors);
    if (value is num) {
      final min = s['minimum'];
      final max = s['maximum'];
      if (min is num && value < min) errors.add('$at: $value < mínimo $min');
      if (max is num && value > max) errors.add('$at: $value > máximo $max');
    }
    if (value is List<dynamic>) {
      final min = s['minItems'];
      final max = s['maxItems'];
      if (min is int && value.length < min) {
        errors.add('$at: menos de $min elementos');
      }
      if (max is int && value.length > max) {
        errors.add('$at: más de $max elementos');
      }
      final items = s['items'];
      if (items is Map<String, dynamic>) {
        for (var i = 0; i < value.length; i++) {
          errors.addAll(validate(value[i], items, '$at[$i]'));
        }
      }
    }
    if (value is Map<String, dynamic>) _validateObject(value, s, at, errors);
    return errors;
  }

  void _validateString(
    String value,
    Map<String, dynamic> s,
    String at,
    List<String> errors,
  ) {
    final minLength = s['minLength'];
    final maxLength = s['maxLength'];
    if (minLength is int && value.length < minLength) {
      errors.add('$at: longitud < $minLength');
    }
    if (maxLength is int && value.length > maxLength) {
      errors.add('$at: longitud > $maxLength');
    }
    final pattern = s['pattern'];
    if (pattern is String && !RegExp(pattern).hasMatch(value)) {
      errors.add('$at: no cumple el patrón $pattern');
    }
    final format = s['format'];
    final ok = switch (format) {
      'uuid' => RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(value),
      'date-time' => DateTime.tryParse(value) != null && value.contains('T'),
      'uri' => Uri.tryParse(value)?.hasScheme ?? false,
      'email' => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value),
      _ => true,
    };
    if (!ok) errors.add('$at: formato $format inválido');
  }

  void _validateObject(
    Map<String, dynamic> value,
    Map<String, dynamic> s,
    String at,
    List<String> errors,
  ) {
    final required = s['required'];
    if (required is List<dynamic>) {
      for (final key in required.cast<String>()) {
        if (!value.containsKey(key)) errors.add('$at: falta "$key"');
      }
    }
    final props = s['properties'];
    if (props is Map<String, dynamic>) {
      for (final entry in props.entries) {
        if (value.containsKey(entry.key)) {
          errors.addAll(
            validate(
              value[entry.key],
              entry.value as Map<String, dynamic>,
              '$at.${entry.key}',
            ),
          );
        }
      }
      if (s['additionalProperties'] == false) {
        for (final key in value.keys) {
          if (!props.containsKey(key)) {
            errors.add('$at: propiedad no permitida "$key"');
          }
        }
      }
    }
  }

  static bool _isType(Object? v, String t) => switch (t) {
    'object' => v is Map<String, dynamic>,
    'array' => v is List<dynamic>,
    'string' => v is String,
    'integer' => v is int || (v is double && v == v.truncateToDouble()),
    'number' => v is num,
    'boolean' => v is bool,
    'null' => v == null,
    _ => false,
  };

  static String _typeName(Object? v) =>
      v == null ? 'null' : v.runtimeType.toString();

  // ── Sintetizador de ejemplos ─────────────────────────────────────────────

  /// Ejemplo válido de [schemaNode] (usa `example`, `const`, `enum` y valores
  /// por formato/patrón). Lanza [StateError] si no consigue uno válido.
  Object? example(Map<String, dynamic> schemaNode, [int depth = 0]) {
    if (depth > 12) return null;
    final s = resolve(schemaNode);
    if (s.containsKey('example')) return s['example'];
    final examples = s['examples'];
    if (examples is List<dynamic> && examples.isNotEmpty) return examples.first;
    if (s.containsKey('const')) return s['const'];
    final enumValues = s['enum'];
    if (enumValues is List<dynamic> && enumValues.isNotEmpty) {
      return enumValues.first;
    }

    final allOf = s['allOf'];
    if (allOf is List<dynamic>) {
      final merged = <String, dynamic>{};
      for (final sub in allOf) {
        final part = example(sub as Map<String, dynamic>, depth + 1);
        if (part is Map<String, dynamic>) merged.addAll(part);
      }
      return merged;
    }
    for (final key in ['oneOf', 'anyOf']) {
      final alts = s[key];
      if (alts is List<dynamic> && alts.isNotEmpty) {
        // Preferir una alternativa no nula.
        final nonNull = alts.cast<Map<String, dynamic>>().firstWhere(
          (a) => resolve(a)['type'] != 'null',
          orElse: () => alts.first as Map<String, dynamic>,
        );
        return example(nonNull, depth + 1);
      }
    }

    final rawType = s['type'];
    final types = rawType is List<dynamic>
        ? rawType.cast<String>()
        : [if (rawType != null) rawType as String];
    final type = types.firstWhere(
      (t) => t != 'null',
      orElse: () => types.isEmpty ? 'object' : 'null',
    );
    switch (type) {
      case 'object':
        final out = <String, dynamic>{};
        final props = s['properties'];
        if (props is Map<String, dynamic>) {
          for (final e in props.entries) {
            out[e.key] = example(e.value as Map<String, dynamic>, depth + 1);
          }
        }
        return out;
      case 'array':
        final items = s['items'];
        final max = s['maxItems'];
        // En esquemas recursivos (p. ej. Category.children) se corta pronto.
        if (items is! Map<String, dynamic> || max == 0 || depth > 6) {
          return <dynamic>[];
        }
        return [example(items, depth + 1)];
      case 'integer':
        final min = s['minimum'];
        return min is num ? min.toInt().clamp(min.toInt(), 1 << 30) : 1;
      case 'number':
        final min = s['minimum'];
        return min is num ? min : 1;
      case 'boolean':
        return true;
      case 'null':
        return null;
      default:
        return _exampleString(s);
    }
  }

  String _exampleString(Map<String, dynamic> s) {
    switch (s['format']) {
      case 'uuid':
        return '3f2b8c1e-5a4d-4e6f-9b7a-1c2d3e4f5a6b';
      case 'date-time':
        return '2026-11-19T12:00:00Z';
      case 'uri':
        return 'https://iprpartesyrepuestos.com/ejemplo';
      case 'email':
        return 'ejemplo@example.invalid';
    }
    final pattern = s['pattern'] as String?;
    final minLength = (s['minLength'] as int?) ?? 0;
    final maxLength = (s['maxLength'] as int?) ?? 1 << 20;
    if (pattern != null) {
      // Patrones de tokens con longitud fija: ipra_/iprr_ + 43 caracteres.
      final token = RegExp(r'^\^(ipr[ar]_)\[A-Za-z0-9_-\]\{43\}\$$')
          .firstMatch(pattern);
      if (token != null) return '${token.group(1)}${'A' * 43}';
      final re = RegExp(pattern);
      for (final candidate in [
        'ejemplo',
        '1.0.0',
        '3014021882',
        '123456789',
        '1',
        'A',
        '/app/pedido',
      ]) {
        final padded = candidate.padRight(minLength, candidate[0]);
        if (padded.length <= maxLength && re.hasMatch(padded)) return padded;
      }
      throw StateError(
        'No se pudo sintetizar un valor para el patrón $pattern',
      );
    }
    const base = 'ejemplo';
    final value = base.padRight(minLength, 'x');
    return value.length > maxLength ? value.substring(0, maxLength) : value;
  }
}
