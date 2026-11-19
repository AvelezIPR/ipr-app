import 'dart:io';

/// Genera TODO lo derivado, **serializado con un candado**: varias personas o
/// agentes pueden pedir la generación a la vez sin que `build_runner` ni
/// `gen-l10n` se pisen.
///
/// Orden: fusiona los textos (`l10n/parts` → `app_es.arb`), `flutter gen-l10n`
/// y `build_runner` (freezed, json_serializable).
///
/// Uso: `dart run tool/codegen.dart` (con `flutter` en el PATH).
Future<void> main() async {
  final lock = Directory('.dart_tool/ipr_codegen.lock');
  final deadline = DateTime.now().add(const Duration(minutes: 15));
  while (true) {
    try {
      lock.createSync(recursive: true);
      // createSync(recursive) no falla si ya existe: usa un archivo dueño.
      final owner = File('${lock.path}/owner');
      if (owner.existsSync()) {
        final age = DateTime.now().difference(owner.lastModifiedSync());
        if (age > const Duration(minutes: 20)) {
          owner.deleteSync(); // candado huérfano
        } else {
          throw const FileSystemException('ocupado');
        }
      }
      owner.createSync(exclusive: true);
      break;
    } on FileSystemException {
      if (DateTime.now().isAfter(deadline)) {
        stderr.writeln('codegen: candado ocupado más de 15 min; abortando');
        exitCode = 1;
        return;
      }
      stdout.writeln('codegen: esperando el candado...');
      await Future<void>.delayed(const Duration(seconds: 3));
    }
  }

  try {
    for (final step in <List<String>>[
      ['dart', 'run', 'tool/merge_arb.dart'],
      ['flutter', 'gen-l10n'],
      ['dart', 'run', 'build_runner', 'build', '--delete-conflicting-outputs'],
    ]) {
      stdout.writeln('codegen: ${step.join(' ')}');
      final result = await Process.run(
        step.first,
        step.sublist(1),
        runInShell: true,
      );
      stdout.write(result.stdout);
      if (result.exitCode != 0) {
        stderr
          ..write(result.stderr)
          ..writeln(
            'codegen: falló "${step.join(' ')}" (código ${result.exitCode})',
          );
        exitCode = result.exitCode;
        return;
      }
    }
    stdout.writeln('codegen: OK');
  } finally {
    final owner = File('${lock.path}/owner');
    if (owner.existsSync()) owner.deleteSync();
  }
}
