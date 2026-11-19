import 'dart:io';

import 'src/coverage_check.dart';

/// `dart run ci/check_coverage.dart [coverage/lcov.info]` — umbrales de QG
/// (≥ 70 % global, ≥ 90 % en módulos críticos). Excluye código generado. Los
/// módulos críticos que aún no existen (se crean en M3–M5) se informan como
/// "pendientes" y pasan a exigirse en cuanto exista su carpeta.
void main(List<String> args) {
  final path = args.isEmpty ? 'coverage/lcov.info' : args.first;
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln(
      'check_coverage: no existe $path (ejecuta flutter test --coverage)',
    );
    exitCode = 2;
    return;
  }
  final report = evaluateCoverage(
    parseLcov(file.readAsStringSync()),
    projectRoot: '.',
  );
  stdout.writeln(
    'Cobertura global (sin código generado): ${report.global.toStringAsFixed(1)} %',
  );
  report.modules.forEach((module, pct) {
    stdout.writeln('  $module: ${pct.toStringAsFixed(1)} %');
  });
  for (final module in report.skipped) {
    stdout.writeln('  $module: pendiente (aún sin código)');
  }
  if (report.failures.isEmpty) {
    stdout.writeln('check_coverage: OK');
    return;
  }
  stderr.writeln('check_coverage: FALLA');
  for (final failure in report.failures) {
    stderr.writeln('  - $failure');
  }
  exitCode = 1;
}
