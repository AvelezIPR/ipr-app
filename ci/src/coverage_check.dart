import 'dart:io';

/// Cobertura de un archivo (líneas ejecutables y líneas cubiertas).
final class FileCoverage {
  const new(this.path, this.found, this.hit);

  final String path;
  final int found;
  final int hit;
}

/// Umbrales de QG (RNF-089): ≥ 70 % global y ≥ 90 % en módulos críticos.
const globalThreshold = 70.0;
const criticalThreshold = 90.0;
const criticalModules = [
  'lib/core/session',
  'lib/core/network',
  'lib/features/cart/domain',
  'lib/features/checkout/domain',
  'lib/shared/formatting',
  'lib/features/technical_tools/domain',
];

/// El código generado no cuenta (no se escribe a mano ni se prueba).
bool isGenerated(String path) =>
    path.endsWith('.g.dart') ||
    path.endsWith('.freezed.dart') ||
    path.contains('lib/l10n/app_localizations');

/// Lee `lcov.info` y devuelve la cobertura por archivo (rutas relativas con `/`).
List<FileCoverage> parseLcov(String content) {
  final files = <FileCoverage>[];
  String? current;
  var found = 0;
  var hit = 0;
  for (final line in content.split('\n')) {
    if (line.startsWith('SF:')) {
      current = line.substring(3).trim().replaceAll(r'\', '/');
      found = 0;
      hit = 0;
    } else if (line.startsWith('LF:')) {
      found = int.parse(line.substring(3).trim());
    } else if (line.startsWith('LH:')) {
      hit = int.parse(line.substring(3).trim());
    } else if (line.startsWith('end_of_record') && current != null) {
      files.add(FileCoverage(current, found, hit));
      current = null;
    }
  }
  return files;
}

/// Resultado de evaluar un conjunto de archivos.
final class CoverageReport {
  new(this.global, this.modules, this.failures, this.skipped);

  final double global;
  final Map<String, double> modules;
  final List<String> failures;
  final List<String> skipped;
}

double _percent(Iterable<FileCoverage> files) {
  final found = files.fold<int>(0, (a, f) => a + f.found);
  final hit = files.fold<int>(0, (a, f) => a + f.hit);
  return found == 0 ? 100 : hit * 100 / found;
}

/// Evalúa [files] y comprueba que **todo `lib/*.dart` no generado** esté
/// importado por `test/coverage_helper_test.dart` (generado por
/// `ci/gen_coverage_helper.dart`). Sin eso `flutter test --coverage` no
/// instrumenta el archivo y la cobertura se inflaría. Un archivo importado por
/// el auxiliar que no sale en `lcov.info` no tiene líneas ejecutables
/// (solo constantes, enums o interfaces) y no cuenta.
CoverageReport evaluateCoverage(
  List<FileCoverage> files, {
  required String projectRoot,
}) {
  final relevant = files
      .where((f) => f.path.startsWith('lib/') && !isGenerated(f.path))
      .toList();
  final failures = <String>[];

  // Cada archivo de lib/ debe estar importado por el auxiliar de cobertura.
  final helper = File('$projectRoot/test/coverage_helper_test.dart');
  final helperImports = helper.existsSync()
      ? RegExp("import 'package:ipr_mobile/([^']+)'")
            .allMatches(helper.readAsStringSync())
            .map((m) => 'lib/${m.group(1)}')
            .toSet()
      : <String>{};
  if (!helper.existsSync()) {
    failures.add(
      'falta test/coverage_helper_test.dart (ejecuta dart run '
      'ci/gen_coverage_helper.dart antes de flutter test --coverage)',
    );
  }
  final lib = Directory('$projectRoot/lib');
  if (lib.existsSync() && helper.existsSync()) {
    for (final f in lib.listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final rel =
          'lib/${f.path.replaceAll(r'\', '/').substring(lib.path.replaceAll(r'\', '/').length + 1)}';
      if (!isGenerated(rel) && !helperImports.contains(rel)) {
        failures.add(
          '$rel no está importado en test/coverage_helper_test.dart '
          '(su cobertura no se mediría)',
        );
      }
    }
  }

  final global = _percent(relevant);
  if (global < globalThreshold) {
    failures.add(
      'cobertura global ${global.toStringAsFixed(1)} % < $globalThreshold %',
    );
  }

  final modules = <String, double>{};
  final skipped = <String>[];
  for (final module in criticalModules) {
    final inModule = relevant
        .where((f) => f.path.startsWith('$module/'))
        .toList();
    if (inModule.isEmpty) {
      skipped.add(module);
      continue;
    }
    final pct = _percent(inModule);
    modules[module] = pct;
    if (pct < criticalThreshold) {
      failures.add(
        '$module ${pct.toStringAsFixed(1)} % < $criticalThreshold %',
      );
    }
  }
  return CoverageReport(global, modules, failures, skipped);
}
