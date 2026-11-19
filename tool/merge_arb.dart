import 'dart:convert';
import 'dart:io';

/// Fusiona `l10n/parts/*.arb` en `l10n/app_es.arb` (la plantilla de gen-l10n).
///
/// Cada feature escribe SUS textos en `l10n/parts/<NN>_<nombre>.arb` con claves
/// que empiezan por `<nombre>` (p. ej. `catalog…`), de modo que varios agentes
/// o personas puedan trabajar en paralelo sin editar el mismo archivo. La
/// parte `00_core.arb` aporta `@@locale` y no exige prefijo.
///
/// Uso: `dart run tool/merge_arb.dart` (escribe) o `--check` (falla si
/// `app_es.arb` no está al día; para CI).
void main(List<String> args) {
  final check = args.contains('--check');
  final dir = Directory('l10n/parts');
  final parts =
      dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.arb'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  if (parts.isEmpty) {
    stderr.writeln('merge_arb: no hay archivos en l10n/parts/');
    exitCode = 2;
    return;
  }

  final merged = <String, Object?>{};
  final owner = <String, String>{};
  final problems = <String>[];

  for (final file in parts) {
    final name = file.uri.pathSegments.last.replaceAll('.arb', '');
    final prefix = name.replaceFirst(RegExp(r'^\d+_'), '');
    final isCore = prefix == 'core';
    final Object? decoded;
    try {
      decoded = jsonDecode(file.readAsStringSync());
    } on FormatException catch (e) {
      problems.add('$name: JSON inválido (${e.message})');
      continue;
    }
    if (decoded is! Map<String, dynamic>) {
      problems.add('$name: debe ser un objeto');
      continue;
    }
    for (final entry in decoded.entries) {
      final key = entry.key;
      if (key == '@@locale') {
        if (isCore) merged[key] = entry.value;
        continue;
      }
      if (key.startsWith('@@')) continue;
      final messageKey = key.startsWith('@') ? key.substring(1) : key;
      if (!isCore && !messageKey.startsWith(prefix)) {
        problems.add(
          '$name: la clave "$messageKey" debe empezar por "$prefix"',
        );
      }
      if (!key.startsWith('@')) {
        final previous = owner[key];
        if (previous != null) {
          problems.add('$name: la clave "$key" ya existe en $previous');
          continue;
        }
        owner[key] = name;
      }
      merged[key] = entry.value;
    }
  }

  if (problems.isNotEmpty) {
    stderr.writeln('merge_arb: ${problems.length} problema(s):');
    for (final p in problems) {
      stderr.writeln('  - $p');
    }
    exitCode = 1;
    return;
  }

  merged['@@x-generado'] = 'GENERADO por tool/merge_arb.dart desde l10n/parts/*.arb. No editar a mano.';
  final output = '${const JsonEncoder.withIndent('  ').convert(merged)}\n';
  final target = File('l10n/app_es.arb');
  if (check) {
    if (!target.existsSync() || target.readAsStringSync() != output) {
      stderr.writeln(
        'merge_arb: l10n/app_es.arb no está al día. Ejecuta dart run tool/merge_arb.dart',
      );
      exitCode = 1;
      return;
    }
    stdout.writeln(
      'merge_arb: l10n/app_es.arb está al día (${owner.length} textos).',
    );
    return;
  }
  target.writeAsStringSync(output);
  stdout.writeln(
    'merge_arb: ${owner.length} textos de ${parts.length} partes → l10n/app_es.arb',
  );
}
