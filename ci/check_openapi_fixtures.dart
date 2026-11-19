import 'dart:convert';
import 'dart:io';

import '../tool/contract/openapi_contract.dart';

/// `dart run ci/check_openapi_fixtures.dart` — los fixtures JSON de
/// `test/fixtures/contract/` cumplen (o incumplen, si se declara) el esquema de
/// la copia fijada `contract/openapi.yaml` (QG-M06, ST-016).
///
/// Además comprueba que el sintetizador del BFF simulado produce ejemplos
/// válidos para TODOS los esquemas del contrato.
void main() {
  final contract = OpenApiContract.load('contract/openapi.yaml');
  final failures = <String>[];
  var checked = 0;

  // Cada carpeta de test/fixtures/ con un manifest.json (contract/ y una por
  // feature) declara sus fixtures, el esquema y si deben ser válidos.
  final manifests = Directory('test/fixtures')
      .listSync()
      .whereType<Directory>()
      .map((d) => File('${d.path}/manifest.json'))
      .where((f) => f.existsSync())
      .toList();
  for (final manifestFile in manifests) {
    final dir = manifestFile.parent.path;
    final manifest =
        jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
    for (final item
        in (manifest['fixtures'] as List<dynamic>)
            .cast<Map<String, dynamic>>()) {
      final file = item['file'] as String;
      var data = jsonDecode(File('$dir/$file').readAsStringSync());
      final inner = item['path'] as String?;
      if (inner != null) data = (data as Map<String, dynamic>)[inner];
      final errors = contract.validate(
        data,
        contract.schema(item['schema'] as String),
      );
      final expectValid = item['valid'] as bool;
      checked++;
      if (expectValid && errors.isNotEmpty) {
        failures.add('$dir/$file debía ser válido: ${errors.first}');
      } else if (!expectValid && errors.isEmpty) {
        failures.add(
          '$dir/$file debía ser INVÁLIDO frente a ${item['schema']} pero pasó',
        );
      }
    }
  }

  var synthesized = 0;
  for (final name in contract.schemas.keys) {
    try {
      final example = contract.example(contract.schema(name));
      final errors = contract.validate(example, contract.schema(name));
      synthesized++;
      if (errors.isNotEmpty) {
        failures.add('ejemplo sintetizado de $name inválido: ${errors.first}');
      }
    } on Object catch (e) {
      failures.add('no se pudo sintetizar $name: $e');
    }
  }

  stdout.writeln(
    'Fixtures comprobados: $checked · esquemas sintetizados: $synthesized',
  );
  if (failures.isEmpty) {
    stdout.writeln('check_openapi_fixtures: OK');
    return;
  }
  stderr.writeln('check_openapi_fixtures: ${failures.length} fallo(s):');
  for (final f in failures) {
    stderr.writeln('  - $f');
  }
  exitCode = 1;
}
