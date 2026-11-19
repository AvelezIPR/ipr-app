import 'dart:io';

/// Una infracción de las reglas de dependencia.
final class Violation {
  const new(this.rule, this.file, this.line, this.message);

  final String rule;
  final String file;
  final int line;
  final String message;

  @override
  String toString() => '[$rule] $file:$line  $message';
}

/// Paquetes que ninguna feature puede importar directamente (D6): siempre a
/// través de interfaces de `core/` o `shared/`.
const sdkPackages = {
  'dio',
  'hive_ce',
  'flutter_secure_storage',
  'url_launcher',
  'cached_network_image',
  'shared_preferences',
  'package_info_plus',
  'path_provider',
  'firebase_core',
  'firebase_crashlytics',
  'sentry_flutter',
};

/// Paquetes prohibidos en el MVP (`flutter_app_architecture.md` §17.2/§18 y
/// las decisiones de ADR-004/ADR-007/ADR-009/ADR-011).
const prohibitedPackages = {
  'webview_flutter',
  'flutter_dotenv',
  'envied',
  'drift',
  'sqflite',
  'app_links',
  'connectivity_plus',
  'http_certificate_pinning',
  'local_auth',
  'firebase_messaging',
  'golden_toolkit',
  'riverpod_generator',
  'riverpod_annotation',
  'get_it',
};

/// Features de fase 2 que NO deben existir en el MVP (ADR-002).
const phase2Features = {'favorites', 'notifications', 'quotes', 'content'};

/// Las 12 features del MVP.
const mvpFeatures = {
  'authentication',
  'home',
  'catalog',
  'search',
  'product_detail',
  'cart',
  'checkout',
  'orders',
  'branches',
  'technical_tools',
  'support',
  'profile',
};

const _flutterUiPackages = [
  'flutter',
  'material_ui',
  'cupertino_ui',
  'flutter_riverpod',
];

final _importRe = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''');

/// Una ubicación dentro de `lib/`: capa y, si es feature, su nombre y subcapa.
final class _Location {
  new(this.layer, {this.feature, this.sub});

  factory of(String libRelative) {
    final parts = libRelative.split('/');
    if (parts.length == 1) return _Location('root');
    final layer = parts.first;
    if (layer == 'features') {
      final feature = parts.length > 1 ? parts[1] : null;
      final sub = parts.length > 3 ? parts[2] : null; // features/x/<sub>/...
      return _Location('features', feature: feature, sub: sub);
    }
    return _Location(layer);
  }

  final String layer; // app | core | shared | features | l10n | root
  final String? feature;
  final String? sub; // presentation | domain | data | null (API pública)
}

/// Comprueba D1–D6, las features permitidas y los paquetes prohibidos sobre
/// el árbol `lib/` de [projectRoot].
List<Violation> checkLayerRules(String projectRoot) {
  final violations = <Violation>[];
  final lib = Directory('$projectRoot/lib');
  if (!lib.existsSync()) return violations;

  // Features de fase 2 y features desconocidas.
  final featuresDir = Directory('${lib.path}/features');
  if (featuresDir.existsSync()) {
    for (final entity in featuresDir.listSync().whereType<Directory>()) {
      final name = entity.uri.pathSegments.where((s) => s.isNotEmpty).last;
      if (phase2Features.contains(name)) {
        violations.add(
          Violation(
            'ADR-002',
            'lib/features/$name',
            0,
            'feature de fase 2 no permitida en el MVP',
          ),
        );
      } else if (!mvpFeatures.contains(name)) {
        violations.add(
          Violation(
            'ADR-002',
            'lib/features/$name',
            0,
            'feature fuera de las 12 del MVP',
          ),
        );
      }
    }
  }

  // Paquetes prohibidos en pubspec.yaml.
  final pubspec = File('$projectRoot/pubspec.yaml');
  if (pubspec.existsSync()) {
    final lines = pubspec.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final key = RegExp(r'^\s{2}([a-z0-9_]+):').firstMatch(lines[i])?.group(1);
      if (key != null && prohibitedPackages.contains(key)) {
        violations.add(
          Violation(
            'PKG',
            'pubspec.yaml',
            i + 1,
            'paquete prohibido en el MVP: $key',
          ),
        );
      }
    }
  }

  for (final file in lib.listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.dart')) continue;
    final rel = file.path
        .replaceAll(r'\', '/')
        .substring(lib.path.replaceAll(r'\', '/').length + 1);
    if (rel.endsWith('.g.dart') ||
        rel.endsWith('.freezed.dart') ||
        rel.startsWith('l10n/app_localizations')) {
      continue;
    }
    final here = _Location.of(rel);
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final target = _importRe.firstMatch(lines[i])?.group(1);
      if (target == null) continue;
      violations.addAll(_checkImport(rel, here, i + 1, target));
    }
  }
  return violations;
}

List<Violation> _checkImport(
  String rel,
  _Location here,
  int line,
  String target,
) {
  final out = <Violation>[];
  void add(String rule, String message) =>
      out.add(Violation(rule, 'lib/$rel', line, message));

  // Paquetes de terceros prohibidos en cualquier parte.
  final pkg = RegExp('^package:([a-z0-9_]+)/').firstMatch(target)?.group(1);
  if (pkg != null && prohibitedPackages.contains(pkg)) {
    add('PKG', 'import de un paquete prohibido en el MVP: $pkg');
  }

  // Destino interno (package:ipr_mobile/...).
  String? internal;
  if (target.startsWith('package:ipr_mobile/')) {
    internal = target.substring('package:ipr_mobile/'.length);
  } else if (!target.contains(':')) {
    // Importaciones relativas: se resuelven contra el archivo actual.
    final base = rel.split('/')..removeLast();
    for (final seg in target.split('/')) {
      if (seg == '..') {
        if (base.isNotEmpty) base.removeLast();
      } else if (seg != '.') {
        base.add(seg);
      }
    }
    internal = base.join('/');
  }

  // D6: las features no importan SDK de terceros directamente.
  if (here.layer == 'features' && pkg != null && sdkPackages.contains(pkg)) {
    add(
      'D6',
      'la feature importa el SDK $pkg directamente; debe pasar por core/ o shared/',
    );
  }
  // shared tampoco habla con red ni disco directamente.
  if (here.layer == 'shared' &&
      pkg != null &&
      const {'dio', 'hive_ce', 'flutter_secure_storage'}.contains(pkg)) {
    add('D6', 'shared/ importa $pkg; debe pasar por core/');
  }

  // D2: dominio puro.
  final inFeatureDomain = here.layer == 'features' && here.sub == 'domain';
  final inSharedDomain =
      here.layer == 'shared' && rel.startsWith('shared/domain/');
  if (inFeatureDomain || inSharedDomain) {
    if (pkg != null && _flutterUiPackages.contains(pkg)) {
      add('D2', 'el dominio no puede importar Flutter/Riverpod ($pkg)');
    }
    if (pkg != null && const {'dio', 'hive_ce'}.contains(pkg)) {
      add('D2', 'el dominio no puede importar $pkg');
    }
    if (internal != null &&
        (internal.contains('/dtos/') || internal.contains('/data/'))) {
      add('D2', 'el dominio no puede importar data/ ni DTO ($internal)');
    }
  }

  if (internal == null) return out;
  final dest = _Location.of(internal);

  // D1: features → shared → core; app arriba del todo.
  if (here.layer == 'core' &&
      const {'shared', 'features', 'app', 'l10n'}.contains(dest.layer)) {
    add('D1', 'core no puede importar ${dest.layer} ($internal)');
  }
  if (here.layer == 'shared' &&
      const {'features', 'app'}.contains(dest.layer)) {
    add('D1', 'shared no puede importar ${dest.layer} ($internal)');
  }
  if (here.layer == 'features' && dest.layer == 'app') {
    add('D1', 'una feature no puede importar app/ ($internal)');
  }

  if (here.layer == 'features' && dest.layer == 'features') {
    final sameFeature = here.feature == dest.feature;
    if (!sameFeature) {
      // D3: solo el archivo público, y solo product_detail/checkout → cart.dart.
      final isPublicFile =
          internal == 'features/${dest.feature}/${dest.feature}.dart';
      final allowedCart =
          isPublicFile &&
          dest.feature == 'cart' &&
          const {'product_detail', 'checkout'}.contains(here.feature);
      if (!isPublicFile) {
        add('D3', 'importa archivos internos de otra feature ($internal)');
      } else if (!allowedCart) {
        add(
          'D3',
          'dependencia entre features no permitida: ${here.feature} → ${dest.feature}',
        );
      }
    }
  }

  if (here.layer == 'features' && here.sub == 'presentation') {
    // D4: los widgets no llaman a repositorios ni a ApiClient.
    final isController = rel.contains('/presentation/controllers/');
    if (internal.contains('/data/') ||
        internal == 'core/network/api_client.dart') {
      add(
        'D4',
        'presentation no puede importar data/ ni ApiClient ($internal)',
      );
    }
    if (!isController && internal.contains('/domain/repositories/')) {
      add(
        'D4',
        'los widgets no llaman a repositorios; usa un controlador ($internal)',
      );
    }
  }

  // D5: los DTO nunca salen de data/.
  final isDto = internal.contains('/dtos/') || internal.endsWith('_dto.dart');
  if (isDto) {
    final sameData =
        here.layer == 'features' &&
        dest.layer == 'features' &&
        here.feature == dest.feature &&
        here.sub == 'data';
    final sameCoreArea =
        here.layer == 'core' &&
        dest.layer == 'core' &&
        rel.split('/')[1] == internal.split('/')[1];
    if (!sameData && !sameCoreArea) {
      add('D5', 'un DTO se importa fuera de su capa data/ ($internal)');
    }
  }
  return out;
}
