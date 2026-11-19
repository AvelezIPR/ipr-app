import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// Claves permitidas, exactamente estas (ADR-009).
const allowedConfigKeys = {
  'environment',
  'apiBaseUrl',
  'deepLinkHost',
  'checkoutAllowedHosts',
  'mediaHosts',
  'supportWhatsApp',
};

final _secretKeyName = RegExp(
  'secret|token|passw|credential|api[_-]?key|private|signing|keystore',
  caseSensitive: false,
);
final _secretValue = RegExp(
  r'(sk_(live|test)_|-----BEGIN|bearer\s|ipr[ar]_[A-Za-z0-9_-]{10,}|[A-Za-z0-9+/_-]{32,}={0,2}$)',
  caseSensitive: false,
);

/// Verifica que `config/<flavor>.json` sea público y consistente (SC-038,
/// RNF-036): solo las claves esperadas, sin nombres ni valores de secretos,
/// entorno igual al nombre del archivo, https fuera de dev. También comprueba
/// que no haya `.env` ni assets de entorno y que la copia fijada del contrato
/// coincida con su huella SHA-256.
List<String> checkPublicConfig(String projectRoot) {
  final problems = <String>[];
  final dir = Directory('$projectRoot/config');
  if (!dir.existsSync()) return ['no existe la carpeta config/'];

  for (final flavor in ['dev', 'staging', 'prod']) {
    final file = File('${dir.path}/$flavor.json');
    if (!file.existsSync()) {
      problems.add('falta config/$flavor.json');
      continue;
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(file.readAsStringSync());
    } on FormatException catch (e) {
      problems.add('config/$flavor.json no es JSON válido: ${e.message}');
      continue;
    }
    if (decoded is! Map<String, dynamic>) {
      problems.add('config/$flavor.json debe ser un objeto');
      continue;
    }
    for (final key in decoded.keys) {
      if (!allowedConfigKeys.contains(key)) {
        problems.add('config/$flavor.json: clave no permitida "$key"');
      }
      if (_secretKeyName.hasMatch(key)) {
        problems.add('config/$flavor.json: el nombre "$key" parece un secreto');
      }
    }
    for (final key in allowedConfigKeys) {
      if (!decoded.containsKey(key)) {
        problems.add('config/$flavor.json: falta "$key"');
      }
    }
    for (final entry in decoded.entries) {
      final value = '${entry.value}';
      if (entry.key == 'apiBaseUrl') continue; // las URL largas no son secretos
      if (_secretValue.hasMatch(value)) {
        problems.add(
          'config/$flavor.json: el valor de "${entry.key}" parece un secreto',
        );
      }
    }
    if (decoded['environment'] != flavor) {
      problems.add('config/$flavor.json: environment debe ser "$flavor"');
    }
    final api = Uri.tryParse('${decoded['apiBaseUrl']}');
    if (api == null || !api.hasScheme || api.host.isEmpty) {
      problems.add('config/$flavor.json: apiBaseUrl inválida');
    } else if (flavor != 'dev' && api.scheme != 'https') {
      problems.add('config/$flavor.json: apiBaseUrl debe ser https');
    }
    if (flavor == 'prod') {
      final host = '${decoded['deepLinkHost']}';
      final hosts = '${decoded['checkoutAllowedHosts']}'
          .split(',')
          .map((h) => h.trim());
      if (!hosts.contains(host)) {
        problems.add(
          'config/prod.json: deepLinkHost debe estar en checkoutAllowedHosts',
        );
      }
      if (host.endsWith('.invalid') || host.contains('localhost')) {
        problems.add(
          'config/prod.json: deepLinkHost de producción no puede ser de pruebas',
        );
      }
    }
  }

  // Ningún .env en el repositorio ni como asset.
  for (final entity in Directory(projectRoot).listSync()) {
    final name = entity.uri.pathSegments.where((s) => s.isNotEmpty).last;
    if (name == '.env' || name.startsWith('.env.')) {
      problems.add(
        'archivo de entorno en el repositorio: $name (prohibido, ADR-009)',
      );
    }
  }
  final pubspec = File('$projectRoot/pubspec.yaml');
  if (pubspec.existsSync() &&
      RegExp(
        r'^\s*-\s*\.env',
        multiLine: true,
      ).hasMatch(pubspec.readAsStringSync())) {
    problems.add('pubspec.yaml empaqueta un .env como asset (prohibido)');
  }

  // Copia fijada del contrato.
  final contract = File('$projectRoot/contract/openapi.yaml');
  final pin = File('$projectRoot/contract/openapi.yaml.sha256');
  if (!contract.existsSync() || !pin.existsSync()) {
    problems.add('falta contract/openapi.yaml o su huella .sha256');
  } else {
    final actual = sha256.convert(contract.readAsBytesSync()).toString();
    final expected = pin.readAsStringSync().trim();
    if (actual != expected) {
      problems.add(
        'contract/openapi.yaml no coincide con su huella (¿cambió sin actualizar el pin?)',
      );
    }
  }
  return problems;
}
