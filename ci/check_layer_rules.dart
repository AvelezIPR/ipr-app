import 'dart:io';

import 'src/layer_rules.dart';

/// `dart run ci/check_layer_rules.dart` — verifica D1–D6 (QG-M03, ST-002).
/// Sale con código 1 si hay violaciones.
void main() {
  final violations = checkLayerRules('.');
  if (violations.isEmpty) {
    stdout.writeln(
      'check_layer_rules: 0 violaciones (D1–D6, features del MVP, paquetes prohibidos).',
    );
    return;
  }
  stderr.writeln('check_layer_rules: ${violations.length} violación(es):');
  for (final v in violations) {
    stderr.writeln('  $v');
  }
  exitCode = 1;
}
