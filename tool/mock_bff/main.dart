import 'dart:io';

import 'mock_bff.dart';

/// `dart run tool/mock_bff/main.dart [puerto] [--demo]` → BFF simulado en
/// `http://127.0.0.1:<puerto>/mobile/v1` (el emulador Android lo ve como
/// `http://10.0.2.2:<puerto>/mobile/v1`, el valor de `config/dev.json`).
///
/// `--demo` sirve categorías, marcas, productos, búsqueda y sedes de
/// demostración parecidos a los reales (ver `demo_data.dart`).
Future<void> main(List<String> args) async {
  final demo = args.contains('--demo');
  final positional = args.where((a) => !a.startsWith('--')).toList();
  final port = positional.isEmpty ? 8787 : int.parse(positional.first);
  final server = await startMockBff(port: port, demo: demo);
  stdout
    ..writeln('BFF simulado en http://127.0.0.1:${server.port}/mobile/v1')
    ..writeln(
      demo
          ? 'Modo demostración: catálogo, marcas y sedes parecidos a los reales.'
          : 'Ejemplos sintetizados del contrato (usa --demo para datos reales).',
    )
    ..writeln(
      'Escenarios: cabecera X-Mock-Scenario = error:404|429|503|502|504|426|500 | html403',
    )
    ..writeln('Ctrl+C para detener.');
}
