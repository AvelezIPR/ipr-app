import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../ci/src/coverage_check.dart';
import '../../../ci/src/layer_rules.dart';
import '../../../ci/src/public_config_check.dart';

/// Proyecto de prueba en una carpeta temporal.
final class Sandbox {
  new() : root = Directory.systemTemp.createTempSync('ipr_ci_');

  final Directory root;

  void write(String relative, String content) {
    File('${root.path}/$relative')
      ..createSync(recursive: true)
      ..writeAsStringSync(content);
  }

  void dispose() => root.deleteSync(recursive: true);

  List<Violation> check() => checkLayerRules(root.path);

  /// Auxiliar de cobertura con TODOS los archivos de lib/ del sandbox, salvo
  /// [except] (rutas relativas a lib/).
  void writeHelperForAll({Set<String> except = const {}}) {
    final lib = Directory('${root.path}/lib');
    final files = lib
        .listSync(recursive: true)
        .whereType<File>()
        .map(
          (f) => f.path
              .replaceAll(String.fromCharCode(92), '/')
              .split('/lib/')
              .last,
        )
        .where((f) => !except.contains(f))
        .toList();
    writeCoverageHelper(files);
  }

  /// Auxiliar de cobertura que importa los archivos de lib/ indicados.
  void writeCoverageHelper(List<String> libFiles) => write(
    'test/coverage_helper_test.dart',
    libFiles.map((f) => "import 'package:ipr_mobile/$f';").join('\n'),
  );
}

void main() {
  late Sandbox sb;
  setUp(() => sb = Sandbox());
  tearDown(() => sb.dispose());

  group('ST-002 · QG-M03 · check_layer_rules detecta cada regla', () {
    Set<String> rulesOf(List<Violation> v) => v.map((e) => e.rule).toSet();

    test('un proyecto limpio no tiene violaciones', () {
      sb
        ..write('lib/core/a.dart', "import 'dart:io';\n")
        ..write(
          'lib/shared/b.dart',
          "import 'package:ipr_mobile/core/a.dart';\n",
        )
        ..write(
          'lib/features/cart/cart.dart',
          "import 'package:ipr_mobile/shared/b.dart';\n",
        )
        ..write(
          'lib/features/cart/domain/entities/c.dart',
          "import 'package:ipr_mobile/shared/domain/m.dart';\n",
        )
        ..write('lib/shared/domain/m.dart', '\n');
      expect(sb.check(), isEmpty);
    });

    test('D1 · core no importa shared ni features ni app ni l10n', () {
      sb
        ..write(
          'lib/core/a.dart',
          "import 'package:ipr_mobile/shared/x.dart';\n",
        )
        ..write(
          'lib/core/b.dart',
          "import 'package:ipr_mobile/features/cart/cart.dart';\n",
        )
        ..write(
          'lib/core/c.dart',
          "import 'package:ipr_mobile/app/app.dart';\n",
        )
        ..write(
          'lib/core/d.dart',
          "import 'package:ipr_mobile/l10n/app_localizations.dart';\n",
        );
      final v = sb.check();
      expect(v.where((e) => e.rule == 'D1'), hasLength(4));
    });

    test(
      'D1 · shared no importa features/app y una feature no importa app',
      () {
        sb
          ..write(
            'lib/shared/a.dart',
            "import 'package:ipr_mobile/features/home/home.dart';\n",
          )
          ..write(
            'lib/features/home/home.dart',
            "import 'package:ipr_mobile/app/app.dart';\n",
          );
        expect(rulesOf(sb.check()), {'D1'});
        expect(sb.check(), hasLength(2));
      },
    );

    test(
      'D2 · el dominio no importa Flutter, Riverpod, Dio, Hive ni data/DTO',
      () {
        sb
          ..write(
            'lib/features/cart/domain/a.dart',
            "import 'package:flutter/widgets.dart';\n",
          )
          ..write(
            'lib/features/cart/domain/b.dart',
            "import 'package:material_ui/material_ui.dart';\n",
          )
          ..write(
            'lib/features/cart/domain/c.dart',
            "import 'package:flutter_riverpod/flutter_riverpod.dart';\n",
          )
          ..write(
            'lib/features/cart/domain/d.dart',
            "import 'package:dio/dio.dart';\n",
          )
          ..write(
            'lib/features/cart/domain/e.dart',
            "import 'package:hive_ce/hive.dart';\n",
          )
          ..write(
            'lib/features/cart/domain/f.dart',
            "import 'package:ipr_mobile/features/cart/data/dtos/x.dart';\n",
          )
          ..write(
            'lib/shared/domain/g.dart',
            "import 'package:flutter/widgets.dart';\n",
          );
        final d2 = sb.check().where((e) => e.rule == 'D2');
        expect(d2.length, greaterThanOrEqualTo(7));
      },
    );

    test('D3 · no se importan archivos internos de otra feature', () {
      sb.write(
        'lib/features/orders/presentation/a.dart',
        "import 'package:ipr_mobile/features/cart/domain/entities/c.dart';\n",
      );
      expect(sb.check().where((e) => e.rule == 'D3'), hasLength(1));
    });

    test('D3 · solo product_detail y checkout pueden importar cart.dart', () {
      sb
        ..write(
          'lib/features/product_detail/p.dart',
          "import 'package:ipr_mobile/features/cart/cart.dart';\n",
        )
        ..write(
          'lib/features/checkout/c.dart',
          "import 'package:ipr_mobile/features/cart/cart.dart';\n",
        )
        ..write(
          'lib/features/orders/o.dart',
          "import 'package:ipr_mobile/features/cart/cart.dart';\n",
        )
        ..write(
          'lib/features/search/s.dart',
          "import 'package:ipr_mobile/features/catalog/catalog.dart';\n",
        );
      final d3 = sb.check().where((e) => e.rule == 'D3').toList();
      expect(
        d3.map((e) => e.file),
        containsAll([
          'lib/features/orders/o.dart',
          'lib/features/search/s.dart',
        ]),
      );
      expect(d3, hasLength(2));
    });

    test('D3 · resuelve importaciones relativas', () {
      sb.write(
        'lib/features/orders/presentation/a.dart',
        "import '../../cart/domain/entities/c.dart';\n",
      );
      expect(sb.check().where((e) => e.rule == 'D3'), hasLength(1));
    });

    test('D4 · presentation no importa data/ ni ApiClient; los widgets no importan repositorios', () {
      sb
        ..write(
          'lib/features/cart/presentation/screens/a.dart',
          "import 'package:ipr_mobile/features/cart/data/repositories/r.dart';\n",
        )
        ..write(
          'lib/features/cart/presentation/widgets/b.dart',
          "import 'package:ipr_mobile/core/network/api_client.dart';\n",
        )
        ..write(
          'lib/features/cart/presentation/widgets/c.dart',
          "import 'package:ipr_mobile/features/cart/domain/repositories/cart_repository.dart';\n",
        )
        // El controlador SÍ puede usar el repositorio (interfaz de domain).
        ..write(
          'lib/features/cart/presentation/controllers/d.dart',
          "import 'package:ipr_mobile/features/cart/domain/repositories/cart_repository.dart';\n",
        );
      final d4 = sb.check().where((e) => e.rule == 'D4').toList();
      expect(d4, hasLength(3));
      expect(d4.any((e) => e.file.contains('controllers')), isFalse);
    });

    test('D5 · un DTO no sale de data/', () {
      sb
        ..write(
          'lib/features/cart/presentation/screens/a.dart',
          "import 'package:ipr_mobile/features/cart/data/dtos/x_dto.dart';\n",
        )
        ..write(
          'lib/features/cart/data/repositories/ok.dart',
          "import 'package:ipr_mobile/features/cart/data/dtos/x_dto.dart';\n",
        )
        ..write(
          'lib/shared/b.dart',
          "import 'package:ipr_mobile/core/config/remote_config_dto.dart';\n",
        )
        ..write(
          'lib/core/config/ok.dart',
          "import 'package:ipr_mobile/core/config/remote_config_dto.dart';\n",
        );
      final d5 = sb.check().where((e) => e.rule == 'D5').toList();
      expect(
        d5.map((e) => e.file),
        containsAll([
          'lib/features/cart/presentation/screens/a.dart',
          'lib/shared/b.dart',
        ]),
      );
      expect(d5.any((e) => e.file.endsWith('ok.dart')), isFalse);
    });

    test('D6 · las features no importan SDK; shared no importa dio/hive', () {
      sb
        ..write(
          'lib/features/cart/data/a.dart',
          "import 'package:dio/dio.dart';\n",
        )
        ..write(
          'lib/features/cart/data/b.dart',
          "import 'package:url_launcher/url_launcher.dart';\n",
        )
        ..write(
          'lib/features/home/c.dart',
          "import 'package:cached_network_image/cached_network_image.dart';\n",
        )
        ..write('lib/shared/d.dart', "import 'package:hive_ce/hive.dart';\n")
        ..write('lib/core/ok.dart', "import 'package:dio/dio.dart';\n");
      final d6 = sb.check().where((e) => e.rule == 'D6').toList();
      expect(d6, hasLength(4));
      expect(d6.any((e) => e.file.startsWith('lib/core/')), isFalse);
    });

    test(
      'ADR-002 · no se crean features de fase 2 ni fuera de las 12 del MVP',
      () {
        for (final name in [
          'favorites',
          'notifications',
          'quotes',
          'content',
          'inventada',
        ]) {
          sb.write('lib/features/$name/$name.dart', '\n');
        }
        sb.write('lib/features/cart/cart.dart', '\n');
        final adr = sb.check().where((e) => e.rule == 'ADR-002').toList();
        expect(adr, hasLength(5));
      },
    );

    test('PKG · paquetes prohibidos en pubspec.yaml y en imports', () {
      sb
        ..write(
          'pubspec.yaml',
          'dependencies:\n  flutter:\n    sdk: flutter\n  webview_flutter: ^4.0.0\n  get_it: ^7.0.0\n  riverpod_annotation: ^4.0.0\n',
        )
        ..write('lib/core/a.dart', "import 'package:drift/drift.dart';\n");
      final pkg = sb.check().where((e) => e.rule == 'PKG').toList();
      expect(pkg, hasLength(4));
    });

    test('ignora el código generado y comentarios', () {
      sb
        ..write(
          'lib/core/x.g.dart',
          "import 'package:ipr_mobile/shared/x.dart';\n",
        )
        ..write(
          'lib/core/y.dart',
          "// import 'package:ipr_mobile/shared/x.dart';\n",
        );
      expect(sb.check(), isEmpty);
    });

    test('Violation.toString incluye regla, archivo y línea', () {
      const v = Violation('D1', 'lib/core/a.dart', 3, 'msg');
      expect(v.toString(), '[D1] lib/core/a.dart:3  msg');
    });

    test('el árbol REAL del proyecto no tiene violaciones', () {
      expect(checkLayerRules('.'), isEmpty);
    });
  });

  group('QG · check_coverage', () {
    test(r'parseLcov lee archivos, líneas y aciertos (rutas con \ y /)', () {
      final files = parseLcov(
        'SF:lib\\core\\a.dart\nLF:10\nLH:9\nend_of_record\nSF:lib/shared/b.dart\nLF:4\nLH:4\nend_of_record\n',
      );
      expect(files, hasLength(2));
      expect(files.first.path, 'lib/core/a.dart');
      expect(files.first.found, 10);
      expect(files.first.hit, 9);
    });

    test('un archivo importado por el auxiliar pero sin líneas ejecutables no falla', () {
      sb
        ..write('lib/core/solo_constantes.dart', '\n')
        ..write('lib/core/a.dart', '\n')
        ..writeCoverageHelper(['core/solo_constantes.dart', 'core/a.dart']);
      final report = evaluateCoverage([
        const FileCoverage('lib/core/a.dart', 10, 10),
      ], projectRoot: sb.root.path);
      expect(report.failures, isEmpty);
    });

    test('falla si no existe el auxiliar de cobertura', () {
      sb.write('lib/core/a.dart', '\n');
      final report = evaluateCoverage([
        const FileCoverage('lib/core/a.dart', 10, 10),
      ], projectRoot: sb.root.path);
      expect(report.failures.single, contains('coverage_helper_test.dart'));
    });

    test('excluye código generado del cálculo', () {
      expect(isGenerated('lib/core/a.g.dart'), isTrue);
      expect(isGenerated('lib/core/a.freezed.dart'), isTrue);
      expect(isGenerated('lib/l10n/app_localizations_es.dart'), isTrue);
      expect(isGenerated('lib/core/a.dart'), isFalse);
    });

    test('pasa con ≥ 70 % global y ≥ 90 % en el módulo crítico', () {
      sb
        ..write('lib/core/session/a.dart', '\n')
        ..write('lib/shared/b.dart', '\n')
        ..writeHelperForAll();
      final report = evaluateCoverage([
        const FileCoverage('lib/core/session/a.dart', 10, 9),
        const FileCoverage('lib/shared/b.dart', 10, 6),
      ], projectRoot: sb.root.path);
      expect(report.failures, isEmpty);
      expect(report.global, 75);
      expect(report.modules['lib/core/session'], 90);
      expect(report.skipped, contains('lib/features/cart/domain'));
    });

    test('falla si un módulo crítico baja de 90 %', () {
      sb
        ..write('lib/core/network/a.dart', '\n')
        ..writeHelperForAll();
      final report = evaluateCoverage([
        const FileCoverage('lib/core/network/a.dart', 100, 85),
      ], projectRoot: sb.root.path);
      expect(report.failures.single, contains('lib/core/network'));
    });

    test('falla si la cobertura global es < 70 %', () {
      sb
        ..write('lib/shared/b.dart', '\n')
        ..writeHelperForAll();
      final report = evaluateCoverage([
        const FileCoverage('lib/shared/b.dart', 100, 60),
      ], projectRoot: sb.root.path);
      expect(report.failures.single, contains('global'));
    });

    test('falla si un archivo de lib/ no aparece en el informe (cobertura inflada)', () {
      sb
        ..write('lib/core/a.dart', '\n')
        ..write('lib/core/olvidado.dart', '\n')
        ..writeHelperForAll(except: {'core/olvidado.dart'});
      final report = evaluateCoverage([
        const FileCoverage('lib/core/a.dart', 10, 10),
      ], projectRoot: sb.root.path);
      expect(report.failures.single, contains('olvidado.dart'));
    });

    test('un módulo sin líneas ejecutables cuenta como 100 %', () {
      sb
        ..write('lib/core/session/a.dart', '\n')
        ..writeHelperForAll();
      final report = evaluateCoverage([
        const FileCoverage('lib/core/session/a.dart', 0, 0),
      ], projectRoot: sb.root.path);
      expect(report.failures, isEmpty);
    });
  });

  group('SC-038 · check_public_config', () {
    Map<String, String> good(String flavor) => {
      'environment': flavor,
      'apiBaseUrl': flavor == 'dev'
          ? 'http://10.0.2.2:8787/mobile/v1'
          : 'https://$flavor.example.com/mobile/v1',
      'deepLinkHost': '$flavor.example.com',
      'checkoutAllowedHosts': '$flavor.example.com',
      'mediaHosts': '$flavor.example.com',
      'supportWhatsApp': '573000000000',
    };

    void writeProject({
      Map<String, Map<String, String>>? overrides,
      bool pin = true,
    }) {
      for (final flavor in ['dev', 'staging', 'prod']) {
        sb.write(
          'config/$flavor.json',
          jsonEncode(overrides?[flavor] ?? good(flavor)),
        );
      }
      const contract = 'openapi: 3.1.0\n';
      sb
        ..write('contract/openapi.yaml', contract)
        ..write(
          'contract/openapi.yaml.sha256',
          pin
              ? sha256.convert(utf8.encode(contract)).toString()
              : 'huella-incorrecta',
        );
    }

    test('configuración pública y consistente: sin problemas', () {
      writeProject();
      expect(checkPublicConfig(sb.root.path), isEmpty);
    });

    test('rechaza claves extra y nombres que parecen secretos', () {
      writeProject(
        overrides: {
          'prod': {...good('prod'), 'apiSecret': 'x', 'extra': 'y'},
        },
      );
      final p = checkPublicConfig(sb.root.path);
      expect(p.any((e) => e.contains('"apiSecret"')), isTrue);
      expect(p.any((e) => e.contains('parece un secreto')), isTrue);
      expect(p.any((e) => e.contains('clave no permitida "extra"')), isTrue);
    });

    test('rechaza valores que parecen secretos (token largo, Bearer)', () {
      writeProject(
        overrides: {
          'staging': {...good('staging'), 'supportWhatsApp': 'A' * 40},
        },
      );
      expect(
        checkPublicConfig(sb.root.path)
            .any((e) => e.contains('supportWhatsApp')),
        isTrue,
      );
    });

    test('el entorno debe coincidir con el nombre del archivo', () {
      writeProject(
        overrides: {
          'staging': {...good('staging'), 'environment': 'prod'},
        },
      );
      expect(
        checkPublicConfig(sb.root.path)
            .any((e) => e.contains('environment debe ser "staging"')),
        isTrue,
      );
    });

    test('exige https fuera de dev y host de producción real', () {
      writeProject(
        overrides: {
          'prod': {
            ...good('prod'),
            'apiBaseUrl': 'http://prod.example.com/mobile/v1',
          },
          'staging': {...good('staging'), 'apiBaseUrl': 'ftp://x'},
        },
      );
      final p = checkPublicConfig(sb.root.path);
      expect(
        p.any((e) => e.contains('prod.json') && e.contains('https')),
        isTrue,
      );
      expect(p.any((e) => e.contains('staging.json')), isTrue);
    });

    test('prod: deepLinkHost debe estar en los hosts de checkout y no ser de pruebas', () {
      writeProject(
        overrides: {
          'prod': {
            ...good('prod'),
            'deepLinkHost': 'otro.invalid',
            'checkoutAllowedHosts': 'a.example.com',
          },
        },
      );
      final p = checkPublicConfig(sb.root.path);
      expect(
        p.any((e) => e.contains('debe estar en checkoutAllowedHosts')),
        isTrue,
      );
      expect(p.any((e) => e.contains('no puede ser de pruebas')), isTrue);
    });

    test('faltan claves o archivos', () {
      writeProject();
      File('${sb.root.path}/config/dev.json')
          .writeAsStringSync('{"environment":"dev"}');
      File('${sb.root.path}/config/prod.json').deleteSync();
      final p = checkPublicConfig(sb.root.path);
      expect(p.any((e) => e.contains('falta "apiBaseUrl"')), isTrue);
      expect(p.any((e) => e.contains('falta config/prod.json')), isTrue);
    });

    test('JSON inválido o que no es un objeto', () {
      writeProject();
      File('${sb.root.path}/config/dev.json').writeAsStringSync('{no json');
      File('${sb.root.path}/config/staging.json').writeAsStringSync('[1]');
      final p = checkPublicConfig(sb.root.path);
      expect(p.any((e) => e.contains('no es JSON válido')), isTrue);
      expect(p.any((e) => e.contains('debe ser un objeto')), isTrue);
    });

    test('prohíbe .env en el repositorio y como asset', () {
      writeProject();
      sb
        ..write('.env', 'X=1')
        ..write('pubspec.yaml', 'flutter:\n  assets:\n    - .env\n');
      final p = checkPublicConfig(sb.root.path);
      expect(p.any((e) => e.contains('archivo de entorno')), isTrue);
      expect(p.any((e) => e.contains('empaqueta un .env')), isTrue);
    });

    test('la copia del contrato debe coincidir con su huella', () {
      writeProject(pin: false);
      expect(
        checkPublicConfig(sb.root.path)
            .any((e) => e.contains('no coincide con su huella')),
        isTrue,
      );
    });

    test('sin carpeta config o sin contrato', () {
      expect(checkPublicConfig(sb.root.path), ['no existe la carpeta config/']);
      writeProject();
      File('${sb.root.path}/contract/openapi.yaml').deleteSync();
      expect(
        checkPublicConfig(sb.root.path)
            .any((e) => e.contains('falta contract/openapi.yaml')),
        isTrue,
      );
    });

    test('la configuración REAL del proyecto es pública y consistente', () {
      expect(checkPublicConfig('.'), isEmpty);
    });
  });
}
