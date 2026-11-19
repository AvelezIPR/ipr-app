import 'dart:io';

import 'src/public_config_check.dart';

/// `dart run ci/check_public_config.dart` — la configuración por flavor es
/// pública, consistente y sin secretos (SC-038).
void main() {
  final problems = checkPublicConfig('.');
  if (problems.isEmpty) {
    stdout.writeln(
      'check_public_config: OK (config/{dev,staging,prod}.json y contrato fijado).',
    );
    return;
  }
  stderr.writeln('check_public_config: ${problems.length} problema(s):');
  for (final p in problems) {
    stderr.writeln('  - $p');
  }
  exitCode = 1;
}
