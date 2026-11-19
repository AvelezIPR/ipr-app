import 'dart:io';

import 'mock_bff.dart';

/// `dart run tool/mock_bff/main.dart [puerto]` → BFF simulado en
/// `http://127.0.0.1:<puerto>/mobile/v1` (el emulador Android lo ve como
/// `http://10.0.2.2:<puerto>/mobile/v1`, el valor de `config/dev.json`).
Future<void> main(List<String> args) async {
  final port = args.isEmpty ? 8787 : int.parse(args.first);
  final server = await startMockBff(port: port);
  stdout
    ..writeln('BFF simulado en http://127.0.0.1:${server.port}/mobile/v1')
    ..writeln(
      'Escenarios: cabecera X-Mock-Scenario = error:404|429|503|502|504|426|500 | html403',
    )
    ..writeln('Ctrl+C para detener.');
}
