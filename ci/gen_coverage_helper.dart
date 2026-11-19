import 'dart:io';

/// Genera `test/coverage_helper_test.dart`, que importa TODOS los archivos de
/// `lib/` no generados. Sin esto `flutter test --coverage` solo incluye lo que
/// alguna prueba importa y la cobertura global saldría inflada.
///
/// Uso: `dart run ci/gen_coverage_helper.dart` antes de `flutter test --coverage`.
/// El archivo generado no se versiona (`.gitignore`).
void main() {
  final lib = Directory('lib');
  final imports = <String>[];
  for (final f in lib.listSync(recursive: true).whereType<File>()) {
    final rel = f.path.replaceAll(r'\', '/');
    if (!rel.endsWith('.dart')) continue;
    if (rel.endsWith('.g.dart') ||
        rel.endsWith('.freezed.dart') ||
        rel.contains('lib/l10n/app_localizations')) {
      continue;
    }
    imports.add("import 'package:ipr_mobile/${rel.substring('lib/'.length)}';");
  }
  imports.sort();
  File('test/coverage_helper_test.dart').writeAsStringSync(
    '// GENERADO por ci/gen_coverage_helper.dart: no editar ni versionar.\n'
    '// ignore_for_file: unused_import, directives_ordering\n'
    "import 'package:flutter_test/flutter_test.dart';\n"
    '${imports.join('\n')}\n\n'
    "void main() => test('coverage helper (importa todo lib/)', () {});\n",
  );
  stdout.writeln(
    'coverage_helper_test.dart: ${imports.length} archivos de lib/ importados.',
  );
}
