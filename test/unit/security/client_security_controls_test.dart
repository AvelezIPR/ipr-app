import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/app/flavor.dart';
import 'package:ipr_mobile/app/router/app_router.dart';
import 'package:ipr_mobile/app/router/deep_link_policy.dart';
import 'package:ipr_mobile/app/router/routes.dart';
import 'package:ipr_mobile/core/config/app_config.dart';
import 'package:ipr_mobile/core/config/remote_config_controller.dart';
import 'package:ipr_mobile/core/external/external_url_policy.dart';
import 'package:ipr_mobile/core/external/media_host_policy.dart';
import 'package:ipr_mobile/core/external/secure_browser.dart';
import 'package:ipr_mobile/core/network/api_client.dart';
import 'package:ipr_mobile/core/network/api_request.dart';
import 'package:ipr_mobile/core/network/interceptors/debug_log_interceptor.dart';
import 'package:ipr_mobile/core/network/uuid_v4.dart';
import 'package:ipr_mobile/core/observability/app_logger.dart';
import 'package:ipr_mobile/core/observability/crash_reporter.dart';
import 'package:ipr_mobile/core/observability/pii_scrubber.dart';
import 'package:ipr_mobile/core/providers.dart';
import 'package:ipr_mobile/core/session/session_controller.dart';
import 'package:ipr_mobile/core/session/session_state.dart';
import 'package:ipr_mobile/core/session/session_tokens.dart';
import 'package:ipr_mobile/core/session/token_store.dart';
import 'package:ipr_mobile/core/storage/cache_store.dart';
import 'package:ipr_mobile/core/storage/hive_bootstrap.dart';
import 'package:ipr_mobile/core/storage/preferences_store.dart';
import 'package:ipr_mobile/core/storage/secure_key_value.dart';
import 'package:ipr_mobile/features/authentication/data/dtos/auth_dtos.dart';
import 'package:ipr_mobile/features/authentication/domain/entities/authenticated_session.dart';
import 'package:ipr_mobile/features/authentication/domain/entities/login_credentials.dart';
import 'package:ipr_mobile/features/authentication/domain/entities/registration.dart';
import 'package:ipr_mobile/features/checkout/data/datasources/checkout_remote_datasource.dart';
import 'package:ipr_mobile/features/checkout/data/dtos/checkout_dtos.dart'
    as checkout_dtos;
import 'package:ipr_mobile/features/checkout/data/repositories/api_checkout_repository.dart';
import 'package:ipr_mobile/features/checkout/data/repositories/cache_pending_checkout_store.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/checkout_ticket.dart';
import 'package:ipr_mobile/features/checkout/domain/rules/checkout_flow.dart';
import 'package:ipr_mobile/features/checkout/presentation/controllers/checkout_controller.dart';
import 'package:ipr_mobile/features/orders/data/dtos/orders_dtos.dart';
import 'package:ipr_mobile/features/orders/domain/entities/order_entities.dart';
import 'package:ipr_mobile/features/product_detail/domain/rules/html_sanitizer.dart';
import 'package:ipr_mobile/features/profile/data/dtos/profile_dtos.dart';
import 'package:ipr_mobile/features/profile/domain/entities/profile_entities.dart';
import 'package:ipr_mobile/features/support/domain/entities/pqrs.dart';
import 'package:ipr_mobile/shared/domain/image_ref.dart';
import 'package:ipr_mobile/shared/domain/money.dart';
import 'package:yaml/yaml.dart';

import '../../../ci/src/layer_rules.dart';
import '../../../ci/src/public_config_check.dart';
import '../../mocks/fake_http_adapter.dart';
import '../../mocks/fake_session_remote.dart';
import '../../mocks/memory_secure_key_value.dart';
import '../../mocks/test_clients.dart';
import '../features/checkout/support/checkout_fakes.dart';

/// Valores canario sintéticos de `docs/06_security/security_testing.md` §0.
abstract final class _Canaries {
  static const email = 'canario.pii@ejemplo.test';
  static const nationalId = 'CANARIO-9990001';
  static const nationalIdDigits = '9990001';
  static const phone = '3000000999';
  static const address = 'Calle Canario 99';
  static const password = 'Canario-Pass-0001';
  static const firstName = 'CanarioNombre';
  static const lastName = 'CanarioApellido';
  static const company = 'CanarioEmpresaSAS';
  static const accessToken = 'ipra_canarioAccessToken9990001Secret';
  static const refreshToken = 'iprr_canarioRefreshToken9990001Secret';
  static const ticketSecret = 'CanarioTicketSecret9990001AbCdEf';
  static const checkoutUrl =
      'https://staging.invalid/?ipr_ticket=$ticketSecret';

  static const List<String> sensitiveFragments = [
    email,
    nationalId,
    nationalIdDigits,
    phone,
    address,
    password,
    firstName,
    lastName,
    company,
    accessToken,
    refreshToken,
    'ipra_',
    'iprr_',
    ticketSecret,
    'ipr_ticket',
  ];
}

final class _RecordingCrashReporter implements CrashReporter {
  final List<String> errors = [];
  final List<String?> stackTraces = [];
  final List<String> logs = [];

  @override
  Future<void> log(String message) async => logs.add(message);

  @override
  Future<void> recordError(
    String message, {
    String? stackTrace,
    bool fatal = false,
  }) async {
    errors.add(message);
    stackTraces.add(stackTrace);
  }
}

List<File> _dartFilesInLib() {
  final lib = Directory('lib');
  return lib.listSync(recursive: true).whereType<File>().where((f) {
    final p = f.path.replaceAll(r'\', '/');
    return p.endsWith('.dart') &&
        !p.endsWith('.g.dart') &&
        !p.endsWith('.freezed.dart') &&
        !p.startsWith('lib/l10n/app_localizations');
  }).toList()..sort((a, b) => a.path.compareTo(b.path));
}

/// Elimina comentarios Dart (`//` y `/* ... */`) respetando literales de cadena.
String _stripDartComments(String source) {
  final out = StringBuffer();
  final n = source.length;
  var i = 0;

  while (i < n) {
    final c = source[i];
    final next = i + 1 < n ? source[i + 1] : '';

    if (c == '/' && next == '/') {
      i += 2;
      while (i < n && source[i] != '\n') {
        i++;
      }
      continue;
    }
    if (c == '/' && next == '*') {
      i += 2;
      while (i < n) {
        if (source[i] == '*' && i + 1 < n && source[i + 1] == '/') {
          i += 2;
          break;
        }
        if (source[i] == '\n') out.write('\n');
        i++;
      }
      continue;
    }

    // Cadena cruda `r'...'` / `r"..."` / triples.
    if (c == 'r' && (next == "'" || next == '"')) {
      final quote = next;
      final isTriple =
          i + 3 < n && source[i + 2] == quote && source[i + 3] == quote;
      final delim = isTriple ? '$quote$quote$quote' : quote;
      out
        ..write(c)
        ..write(delim);
      i += 1 + delim.length;
      while (i < n) {
        if (isTriple) {
          if (source.startsWith(delim, i)) {
            out.write(delim);
            i += delim.length;
            break;
          }
        } else if (source[i] == quote) {
          out.write(quote);
          i++;
          break;
        }
        out.write(source[i]);
        i++;
      }
      continue;
    }

    // Cadena normal `'...'` / `"..."` / triples.
    if (c == "'" || c == '"') {
      final quote = c;
      final isTriple =
          i + 2 < n && source[i + 1] == quote && source[i + 2] == quote;
      final delim = isTriple ? '$quote$quote$quote' : quote;
      out.write(delim);
      i += delim.length;
      while (i < n) {
        if (source[i] == r'\' && i + 1 < n) {
          out
            ..write(source[i])
            ..write(source[i + 1]);
          i += 2;
          continue;
        }
        if (isTriple) {
          if (source.startsWith(delim, i)) {
            out.write(delim);
            i += delim.length;
            break;
          }
        } else if (source[i] == quote) {
          out.write(quote);
          i++;
          break;
        }
        out.write(source[i]);
        i++;
      }
      continue;
    }

    out.write(c);
    i++;
  }
  return out.toString();
}

String _stripXmlComments(String xml) =>
    xml.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');

Map<String, String> _loadFlavorMap(String flavor) {
  final raw = jsonDecode(File('config/$flavor.json').readAsStringSync());
  final map = raw as Map<String, dynamic>;
  return {for (final e in map.entries) e.key: '${e.value}'};
}

AppConfig _loadFlavorConfig(String flavor) =>
    AppConfig.fromMap(_loadFlavorMap(flavor));

void main() {
  group('ST-001 · ST-121(a) · SAST y patrones prohibidos en Dart', () {
    test('ST-001 · pubspec.yaml no declara webview_flutter ni paquetes prohibidos y cumple D1–D6', () {
      final raw = File('pubspec.yaml').readAsStringSync();
      final doc = loadYaml(raw) as YamlMap;
      final declared = <String>{};
      for (final section in const [
        'dependencies',
        'dev_dependencies',
        'dependency_overrides',
      ]) {
        final block = doc[section];
        if (block is YamlMap) {
          for (final key in block.keys) {
            declared.add('$key');
          }
        }
      }
      expect(declared, isNot(contains('webview_flutter')));
      for (final pkg in prohibitedPackages) {
        expect(
          declared,
          isNot(contains(pkg)),
          reason: 'paquete prohibido en pubspec.yaml: $pkg',
        );
      }
      expect(checkLayerRules('.'), isEmpty);
    });

    test('ST-001 · ST-121(a) · lib/ sin badCertificateCallback, LaunchMode.inAppWebView ni print/debugPrint sin kDebugMode', () {
      final badCertHits = <String>[];
      final inAppWebViewHits = <String>[];
      final unguardedPrintHits = <String>[];
      final sharedPrefsImports = <String>[];
      final printCallRe = RegExp(r'\b(?:print|debugPrint)\s*\(');

      for (final file in _dartFilesInLib()) {
        final rel = file.path.replaceAll(r'\', '/');
        final code = _stripDartComments(file.readAsStringSync());
        final lines = code.split('\n');

        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.contains('badCertificateCallback')) {
            badCertHits.add('$rel:${i + 1}');
          }
          if (line.contains('LaunchMode.inAppWebView') ||
              line.contains('inAppWebView')) {
            inAppWebViewHits.add('$rel:${i + 1}');
          }
          if (printCallRe.hasMatch(line)) {
            final start = i >= 3 ? i - 3 : 0;
            final end = i + 1 < lines.length ? i + 2 : lines.length;
            final window = lines.sublist(start, end).join('\n');
            if (!window.contains('kDebugMode')) {
              unguardedPrintHits.add('$rel:${i + 1}: ${line.trim()}');
            }
          }
          if (line.contains('package:shared_preferences/')) {
            sharedPrefsImports.add(rel);
          }
        }
      }

      expect(badCertHits, isEmpty);
      expect(inAppWebViewHits, isEmpty);
      expect(unguardedPrintHits, isEmpty);
      expect(
        sharedPrefsImports.toSet(),
        {'lib/app/bootstrap.dart', 'lib/core/storage/preferences_store.dart'},
        reason: 'solo bootstrap y PreferencesStore pueden importar shared_preferences',
      );
    });
  });

  group('ST-021 · ST-022 · Escaneo de secretos en código y configuración', () {
    test('ST-021 · ST-022 · config/*.json, lib/, assets/, android/app/src/ e ios/Runner/ sin secretos ni .env', () {
      expect(checkPublicConfig('.'), isEmpty);

      // 0 archivos .env* en el árbol del proyecto.
      final envFiles = <String>[];
      for (final entity in Directory('.').listSync(recursive: true)) {
        if (entity is! File) continue;
        final rel = entity.path.replaceAll(r'\', '/');
        if (rel.startsWith('./.dart_tool/') ||
            rel.startsWith('./.git/') ||
            rel.startsWith('./build/')) {
          continue;
        }
        final name = rel.split('/').last;
        if (name == '.env' || name.startsWith('.env.')) {
          envFiles.add(rel);
        }
      }
      expect(envFiles, isEmpty);

      final secretPatterns = <(String, RegExp)>[
        ('wc_consumer_key', RegExp(r'\bck_[A-Za-z0-9_]+')),
        ('wc_consumer_secret', RegExp(r'\bcs_[A-Za-z0-9_]+')),
        ('handoff_secret', RegExp('HANDOFF_SECRET', caseSensitive: false)),
        ('x_ipr_secret', RegExp('X-IPR-(?:BFF-)?Secret', caseSensitive: false)),
        ('ipr_bff_secret', RegExp('IPR_BFF_SECRET', caseSensitive: false)),
        ('ipr_access_token_literal', RegExp(r'\bipra_[A-Za-z0-9_\-]+')),
        ('ipr_refresh_token_literal', RegExp(r'\biprr_[A-Za-z0-9_\-]+')),
        ('private_key_pem', RegExp('-----BEGIN [A-Z ]*PRIVATE KEY-----')),
        (
          'dotenv_ref',
          RegExp(r'(?:^|[^A-Za-z0-9_])\.env(?:\.[A-Za-z0-9_]+)?\b'),
        ),
      ];

      final roots = [
        Directory('config'),
        Directory('lib'),
        Directory('assets'),
        Directory('android/app/src'),
        Directory('ios/Runner'),
      ];

      final hits = <String>[];
      for (final root in roots) {
        expect(root.existsSync(), isTrue, reason: 'falta ${root.path}');
        for (final file in root.listSync(recursive: true).whereType<File>()) {
          final rel = file.path.replaceAll(r'\', '/');
          final content = utf8.decode(
            file.readAsBytesSync(),
            allowMalformed: true,
          );
          for (final (label, pattern) in secretPatterns) {
            if (pattern.hasMatch(content)) {
              hits.add('$label -> $rel');
            }
          }
        }
      }
      expect(hits, isEmpty);
    });
  });

  group('ST-088 · ST-122 · ST-124 · ST-127 · ST-171 · Batería hostil de políticas', () {
    test('ST-088 · CheckoutUrlPolicy rechaza HTTP, userinfo, puerto != 443, subdominio engañoso y esquemas peligrosos', () {
      const policy = CheckoutUrlPolicy(
        localHosts: {'iprpartesyrepuestos.com', 'ipr.iprpartesyrepuestos.com'},
      );
      const remote = {'iprpartesyrepuestos.com', 'ipr.iprpartesyrepuestos.com'};

      expect(
        policy.isAllowed(
          Uri.parse('https://iprpartesyrepuestos.com/?ipr_ticket=abc123'),
          remoteHosts: remote,
        ),
        isTrue,
      );
      expect(
        policy.isAllowed(
          Uri.parse('https://ipr.iprpartesyrepuestos.com:443/?ipr_ticket=1'),
          remoteHosts: remote,
        ),
        isTrue,
      );

      final hostileUrls = [
        'http://iprpartesyrepuestos.com/?ipr_ticket=abc',
        'https://user:pass@iprpartesyrepuestos.com/?ipr_ticket=abc',
        'https://evil.com@iprpartesyrepuestos.com/?ipr_ticket=abc',
        'https://iprpartesyrepuestos.com:8443/?ipr_ticket=abc',
        'https://iprpartesyrepuestos.com:80/?ipr_ticket=abc',
        'https://iprpartesyrepuestos.com:0/?ipr_ticket=abc',
        'https://iprpartesyrepuestos.com.evil.com/?ipr_ticket=abc',
        'https://evil-iprpartesyrepuestos.com/?ipr_ticket=abc',
        'https://evil.iprpartesyrepuestos.com/?ipr_ticket=abc',
        'https://iprpartesyrepuestos.com./?ipr_ticket=abc',
        'https://iprpartesyrepuestos.сom/?ipr_ticket=abc',
        'intent://iprpartesyrepuestos.com/#Intent;scheme=https;end',
        'javascript:alert(1)',
        'file:///etc/passwd',
        'content://co.ipr.app/checkout',
        'data:text/html,<script>alert(1)</script>',
        'https:///sin-host',
      ];
      for (final raw in hostileUrls) {
        expect(
          policy.isAllowed(Uri.parse(raw), remoteHosts: remote),
          isFalse,
          reason: raw,
        );
      }

      // Compromiso de servidor: nunca amplía la lista local ni vacía.
      expect(
        policy.isAllowed(
          Uri.parse('https://atacante.invalid/?ipr_ticket=abc'),
          remoteHosts: {'atacante.invalid', ...remote},
        ),
        isFalse,
      );
      expect(
        policy.isAllowed(
          Uri.parse('https://iprpartesyrepuestos.com/?ipr_ticket=abc'),
          remoteHosts: const {},
        ),
        isFalse,
      );
    });

    test('ST-122 · ExternalUrlPolicy bloquea esquemas peligrosos, userinfo, puertos != 443 y dominios engañosos', () {
      const policy = ExternalUrlPolicy(
        extraHttpsHosts: {'iprpartesyrepuestos.com'},
      );

      final hostileUrls = [
        'http://wa.me/573014021882',
        'http://iprpartesyrepuestos.com/terminos',
        'https://user:pass@wa.me/573014021882',
        'https://wa.me@evil.com/573014021882',
        'https://wa.me:8443/573014021882',
        'https://maps.google.com:8080/?q=6.2,-75.5',
        'https://iprpartesyrepuestos.com:8443/legal',
        'https://wa.me.evil.com/573014021882',
        'https://evil-wa.me/573014021882',
        'https://sub.wa.me/573014021882',
        'https://iprpartesyrepuestos.com.evil.com/legal',
        'https://evil.iprpartesyrepuestos.com/legal',
        'https://www.google.com/search?q=x',
        'https://www.google.com/url?q=https://evil.com',
        'https://www.google.com/maps-evil',
        'https://www.google.com/maps/%2e%2e/search',
        'intent://scan/#Intent;scheme=zxing;end',
        'javascript:alert(1)',
        'JAVASCRIPT:alert(document.cookie)',
        'file:///etc/passwd',
        'content://com.android.contacts/contacts',
        'data:text/html,<script>alert(1)</script>',
        'mailto:ventas@iprpartesyrepuestos.com',
        'sms:+573000000999',
        'whatsapp://evil/send',
        'tel:123',
        'tel:+57abc',
        'geo:javascript:alert(1)',
      ];
      for (final raw in hostileUrls) {
        expect(policy.isAllowed(Uri.parse(raw)), isFalse, reason: raw);
      }
      expect(
        policy.isAllowed(
          Uri(
            scheme: 'https',
            host: 'www.google.com',
            path: '/maps/../../search',
          ),
        ),
        isFalse,
      );

      for (final allowedMap in const [
        'https://www.google.com/maps',
        'https://www.google.com/maps/dir/?api=1',
        'https://www.google.com/maps/search/?api=1&query=Medellin',
      ]) {
        expect(
          policy.isAllowed(Uri.parse(allowedMap)),
          isTrue,
          reason: allowedMap,
        );
      }

      const mixedCaseExtra = ExternalUrlPolicy(
        extraHttpsHosts: {'Staging.Invalid'},
      );
      expect(
        mixedCaseExtra.isAllowed(Uri.parse('https://staging.invalid/legal')),
        isTrue,
      );
    });

    test('ST-124 · DeepLinkPolicy resiste variantes hostiles, unicode, largos y parámetros repetidos en /app/pedido', () {
      const policy = DeepLinkPolicy(allowedHost: 'iprpartesyrepuestos.com');

      final hostileLinks = [
        'http://iprpartesyrepuestos.com/app/pedido?order=1&status=paid',
        'https://user:pass@iprpartesyrepuestos.com/app/pedido',
        'https://evil.com@iprpartesyrepuestos.com/app/pedido',
        'https://iprpartesyrepuestos.com:8443/app/pedido',
        'https://iprpartesyrepuestos.com:80/app/pedido',
        'https://iprpartesyrepuestos.com.evil.com/app/pedido',
        'https://sub.iprpartesyrepuestos.com/app/pedido',
        'https://evil-iprpartesyrepuestos.com/app/pedido',
        'https://iprpartesyrepuestos.сom/app/pedido',
        'https://iprpartesyrepuestos.com%40evil.com/app/pedido',
        'intent://iprpartesyrepuestos.com/app/pedido#Intent;scheme=https;end',
        'javascript:alert(1)',
        'file:///app/pedido',
        'file:///orders',
        'content://co.ipr.app/app/pedido',
        'data:text/html,/app/pedido',
        'ipr://app/pedido',
        'https://iprpartesyrepuestos.com/app',
        'https://iprpartesyrepuestos.com/app/',
        'https://iprpartesyrepuestos.com/app/*',
        'https://iprpartesyrepuestos.com/app/pedido/extra',
        'https://iprpartesyrepuestos.com/app/pedido/../orders',
        'https://iprpartesyrepuestos.com/app/pedido/%2e%2e/orders',
        'https://iprpartesyrepuestos.com/app/pedido%2fextra',
        'https://iprpartesyrepuestos.com/APP/PEDIDO',
        '//evil.com/app/pedido',
      ];
      for (final raw in hostileLinks) {
        final uri = Uri.parse(raw);
        expect(policy.isDeepLink(uri), isTrue, reason: raw);
        expect(policy.decide(uri), isA<DeepLinkRejected>(), reason: raw);
        expect(
          computeRedirect(
            uri: uri,
            deepLinks: policy,
            updateRequired: false,
            session: const SessionAuthenticated(userId: 1),
          ),
          Routes.home,
          reason: 'computeRedirect debe enviar a Inicio: $raw',
        );
      }

      // Fuzzing: unicode, cadenas enormes, parámetros repetidos e inyección de rutas.
      final fuzzed = <String>[
        'https://iprpartesyrepuestos.com/app/pedido?order=${'9' * 5000}&q=${'A' * 10000}',
        'https://iprpartesyrepuestos.com/app/pedido?order=١٢٣&status=paid\u200B',
        'https://iprpartesyrepuestos.com/app/pedido?order=123\u0000&status=<script>',
        'https://iprpartesyrepuestos.com/app/pedido?order=10&order=evil&status=paid&status=fake',
        'https://iprpartesyrepuestos.com/app/pedido?next=https://evil.com&redirect=//evil.com&token=ipra_x',
        'https://iprpartesyrepuestos.com/app/pedido?${List.generate(250, (i) => 'p$i=v$i').join('&')}&order=777&status=paid',
        'https://iprpartesyrepuestos.com/app/pedido?extra=${Uri.encodeComponent('🔥💯ñáéíóú/../')}',
      ];
      for (final raw in fuzzed) {
        final decision = policy.decide(Uri.parse(raw));
        expect(decision, isA<DeepLinkAccepted>(), reason: raw);
        final location = (decision as DeepLinkAccepted).location;
        expect(location, startsWith(Routes.checkoutResult));
        expect(location, isNot(contains('evil')));
        expect(location, isNot(contains('ipra_')));
        expect(location, isNot(contains('<script>')));
      }

      // Parámetros repetidos válidos conservan solo pistas válidas acotadas.
      final repeated = policy.decide(
        Uri.parse(
          'https://iprpartesyrepuestos.com/app/pedido?order=11&order=22&status=pending&status=paid',
        ),
      );
      expect(
        (repeated as DeepLinkAccepted).location,
        '/checkout/result?order=22&status=paid',
      );
    });

    test('ST-171 · MediaHostPolicy y HtmlSanitizer bloquean medios fuera de lista blanca y esquemas inseguros', () {
      const policy = MediaHostPolicy(
        allowedHosts: {
          'iprpartesyrepuestos.com',
          'ipr.iprpartesyrepuestos.com',
        },
      );

      expect(
        policy.isAllowed(
          'https://ipr.iprpartesyrepuestos.com/wp-content/a.webp',
        ),
        isTrue,
      );
      expect(
        policy.isAllowed('https://iprpartesyrepuestos.com:443/a.png'),
        isTrue,
      );

      final hostileMedia = <String?>[
        null,
        '',
        'http://iprpartesyrepuestos.com/img.jpg',
        'https://user:pass@iprpartesyrepuestos.com/img.jpg',
        'https://evil.com@iprpartesyrepuestos.com/img.jpg',
        'https://iprpartesyrepuestos.com:8443/img.jpg',
        'https://iprpartesyrepuestos.com:80/img.jpg',
        'https://iprpartesyrepuestos.com.evil.com/img.jpg',
        'https://cdn.iprpartesyrepuestos.com/img.jpg',
        'https://evil-iprpartesyrepuestos.com/img.jpg',
        'https://iprpartesyrepuestos.сom/img.jpg',
        'intent://iprpartesyrepuestos.com/img.jpg#Intent;scheme=https;end',
        'javascript:alert(1)',
        'file:///sdcard/secret.jpg',
        'content://media/external/images/media/1',
        'data:image/svg+xml,<svg onload=alert(1)>',
        '//iprpartesyrepuestos.com/img.jpg',
      ];
      for (final raw in hostileMedia) {
        expect(policy.isAllowed(raw), isFalse, reason: '$raw');
      }

      final sanitizer = HtmlSanitizer(isImageUrlAllowed: policy.isAllowed);
      final sanitized = sanitizer.sanitize(
        const [
          '<p>Texto</p>',
          '<img src="https://tracker.evil.com/pixel.png" alt="bad">',
          '<img src="http://iprpartesyrepuestos.com/insecure.png">',
          '<img src="data:image/png;base64,AAAA">',
          '<a href="javascript:alert(1)">js</a>',
          '<a href="intent://scan">intent</a>',
          '<img src="https://ipr.iprpartesyrepuestos.com/ok.png" alt="ok">',
        ].join(),
      );
      expect(sanitized, isNot(contains('tracker.evil.com')));
      expect(sanitized, isNot(contains('insecure.png')));
      expect(sanitized, isNot(contains('data:image')));
      expect(sanitized, isNot(contains('javascript:')));
      expect(sanitized, isNot(contains('intent:')));
      expect(sanitized, contains('https://ipr.iprpartesyrepuestos.com/ok.png'));
    });

    test('ST-127 · Aislamiento estricto entre flavors dev, staging y prod', () {
      final configs = {
        for (final f in const ['dev', 'staging', 'prod'])
          f: _loadFlavorConfig(f),
      };

      expect(configs['dev']!.environment, Flavor.dev.environment);
      expect(configs['staging']!.environment, Flavor.staging.environment);
      expect(configs['prod']!.environment, Flavor.prod.environment);

      expect(configs['staging']!.apiBaseUrl.scheme, 'https');
      expect(configs['prod']!.apiBaseUrl.scheme, 'https');
      expect(configs['prod']!.environment.allowsDebugLogging, isFalse);

      // staging y prod fallan rápido si alguien configura http:// en apiBaseUrl.
      for (final env in const ['staging', 'prod']) {
        final map = _loadFlavorMap(env)
          ..['apiBaseUrl'] = 'http://example.invalid/mobile/v1';
        expect(() => AppConfig.fromMap(map), throwsFormatException);
      }

      // Aislamiento cruzado de DeepLinkPolicy, CheckoutUrlPolicy, MediaHostPolicy y ExternalUrlPolicy.
      for (final owner in configs.keys) {
        final ownCfg = configs[owner]!;
        final deepLink = DeepLinkPolicy(allowedHost: ownCfg.deepLinkHost);
        final checkout = CheckoutUrlPolicy(
          localHosts: ownCfg.checkoutAllowedHosts,
        );
        final media = MediaHostPolicy(allowedHosts: ownCfg.mediaHosts);
        final external = ExternalUrlPolicy(
          extraHttpsHosts: {ownCfg.deepLinkHost},
        );

        // Acepta su propio host.
        expect(
          deepLink.decide(
            Uri.parse('https://${ownCfg.deepLinkHost}/app/pedido'),
          ),
          isA<DeepLinkAccepted>(),
        );

        for (final other in configs.keys) {
          if (other == owner) continue;
          final otherCfg = configs[other]!;

          expect(
            ownCfg.deepLinkHost,
            isNot(otherCfg.deepLinkHost),
            reason: '$owner y $other no pueden compartir deepLinkHost',
          );
          expect(
            ownCfg.checkoutAllowedHosts.intersection(
              otherCfg.checkoutAllowedHosts,
            ),
            isEmpty,
            reason: '$owner y $other no pueden compartir checkoutAllowedHosts',
          );
          expect(
            ownCfg.mediaHosts.intersection(otherCfg.mediaHosts),
            isEmpty,
            reason: '$owner y $other no pueden compartir mediaHosts',
          );

          expect(
            deepLink.decide(
              Uri.parse('https://${otherCfg.deepLinkHost}/app/pedido'),
            ),
            isA<DeepLinkRejected>(),
            reason: '$owner no debe aceptar deep link de $other',
          );
          expect(
            external.isAllowed(Uri.parse('https://${otherCfg.deepLinkHost}/')),
            isFalse,
            reason: '$owner ExternalUrlPolicy no debe aceptar host de $other',
          );
          for (final h in otherCfg.checkoutAllowedHosts) {
            expect(
              checkout.isAllowed(
                Uri.parse('https://$h/?ipr_ticket=x'),
                remoteHosts: otherCfg.checkoutAllowedHosts,
              ),
              isFalse,
              reason: '$owner CheckoutUrlPolicy no debe aceptar $h de $other',
            );
          }
          for (final h in otherCfg.mediaHosts) {
            expect(
              media.isAllowed('https://$h/img.png'),
              isFalse,
              reason: '$owner MediaHostPolicy no debe aceptar $h de $other',
            );
          }
        }
      }
    });
  });

  group('ST-102 · ST-108 · ST-109 · ST-110 · Canarios, logs, fallos y UUID v4', () {
    test('ST-102 · ST-108 · toString() de entidades y DTOs sensibles no filtran valores canario ni tokens', () {
      const tokens = SessionTokens(
        accessToken: _Canaries.accessToken,
        accessTokenExpiresIn: 900,
        refreshToken: _Canaries.refreshToken,
        sessionId: '3f2b8c1e-5a4d-4e6f-9b7a-1c2d3e4f5a6b',
      );

      const address = Address(
        firstName: _Canaries.firstName,
        lastName: _Canaries.lastName,
        company: _Canaries.company,
        nationalId: _Canaries.nationalId,
        address1: _Canaries.address,
        address2: 'Apto 101',
        department: 'ANT',
        city: 'Medellín',
        postcode: '050021',
        phone: _Canaries.phone,
      );

      const addressInput = AddressInput(
        firstName: _Canaries.firstName,
        lastName: _Canaries.lastName,
        company: _Canaries.company,
        nationalId: _Canaries.nationalId,
        address1: _Canaries.address,
        department: 'ANT',
        city: 'Medellín',
        phone: _Canaries.phone,
      );

      const userProfile = UserProfile(
        id: 42,
        email: _Canaries.email,
        firstName: _Canaries.firstName,
        lastName: _Canaries.lastName,
        displayName: '${_Canaries.firstName} ${_Canaries.lastName}',
        billing: address,
        shipping: address,
      );

      const emailChangeResult = EmailChangeResult(
        tokens: tokens,
        profile: userProfile,
      );

      final deletionStatus = AccountDeletionStatus(
        requestId: '3f2b8c1e-5a4d-4e6f-9b7a-1c2d3e4f5a6b',
        status: AccountDeletionState.scheduled,
        completeBy: DateTime.utc(2026, 12, 31),
      );

      const addressDto = AddressDto(
        firstName: _Canaries.firstName,
        lastName: _Canaries.lastName,
        company: _Canaries.company,
        nationalId: _Canaries.nationalId,
        address1: _Canaries.address,
        address2: '',
        department: 'ANT',
        city: 'Medellín',
        postcode: '',
        phone: _Canaries.phone,
      );

      const userProfileDto = UserProfileDto(
        id: 42,
        email: _Canaries.email,
        firstName: _Canaries.firstName,
        lastName: _Canaries.lastName,
        displayName: '${_Canaries.firstName} ${_Canaries.lastName}',
        billing: addressDto,
        shipping: addressDto,
      );

      const updateProfileDto = UpdateProfileRequestDto(
        firstName: _Canaries.firstName,
        lastName: _Canaries.lastName,
      );
      const changeEmailReqDto = ChangeEmailRequestDto(
        newEmail: _Canaries.email,
        currentPassword: _Canaries.password,
      );
      const changeEmailResDto = ChangeEmailResponseDto(
        tokens: tokens,
        user: userProfileDto,
      );
      const changePasswordReqDto = ChangePasswordRequestDto(
        currentPassword: _Canaries.password,
        newPassword: '${_Canaries.password}-Nueva',
      );
      const changePasswordResDto = ChangePasswordResponseDto(tokens: tokens);
      const addressInputDto = AddressInputDto(
        firstName: _Canaries.firstName,
        lastName: _Canaries.lastName,
        company: _Canaries.company,
        nationalId: _Canaries.nationalId,
        address1: _Canaries.address,
        department: 'ANT',
        city: 'Medellín',
        phone: _Canaries.phone,
      );
      const deletionReqDto = AccountDeletionRequestDto(
        currentPassword: _Canaries.password,
      );
      const deletionStatusDto = AccountDeletionStatusDto(
        requestId: _Canaries.nationalId,
        status: 'scheduled',
        completeBy: null,
      );

      final orderSummary = OrderSummary(
        id: 42,
        number: _Canaries.nationalId,
        status: 'processing',
        statusLabel: _Canaries.address,
        paymentState: OrderPaymentState.paid,
        createdAt: DateTime.utc(2026, 11, 23),
        currency: 'COP',
        total: const Money(150000),
        itemCount: 1,
      );
      final orderPage = OrderPage(
        items: [orderSummary],
        page: 1,
        perPage: 10,
        total: 1,
        totalPages: 1,
        hasMore: false,
      );
      const orderItem = OrderItem(
        productId: 10,
        name: _Canaries.firstName,
        sku: _Canaries.nationalId,
        quantity: 1,
        total: Money(150000),
        image: ImageRef(url: 'https://staging.invalid/a.jpg', alt: 'a'),
      );
      final orderDetail = OrderDetail(
        summary: orderSummary,
        subtotal: const Money(150000),
        shippingTotal: Money.zero,
        discountTotal: null,
        taxTotal: null,
        paymentMethodTitle: _Canaries.company,
        items: const [orderItem],
      );

      const orderSummaryDto = OrderSummaryDto(
        id: 42,
        number: _Canaries.nationalId,
        status: 'processing',
        statusLabel: _Canaries.address,
        paymentState: 'paid',
        createdAt: '2026-11-23T00:00:00Z',
        currency: 'COP',
        total: 150000,
        itemCount: 1,
      );
      const orderPageDto = OrderPageDto(
        items: [orderSummaryDto],
        page: 1,
        perPage: 10,
        total: 1,
        totalPages: 1,
        hasMore: false,
      );
      const orderItemDto = OrderItemDto(
        productId: 10,
        name: _Canaries.firstName,
        sku: _Canaries.nationalId,
        quantity: 1,
        total: 150000,
        imageUrl: 'https://staging.invalid/a.jpg',
      );
      const orderDetailDto = OrderDetailDto(
        summary: orderSummaryDto,
        subtotal: 150000,
        shippingTotal: 0,
        discountTotal: null,
        taxTotal: null,
        paymentMethodTitle: _Canaries.company,
        items: [orderItemDto],
      );

      const loginCreds = LoginCredentials(
        login: _Canaries.email,
        password: _Canaries.password,
      );
      const regForm = RegistrationForm(
        email: _Canaries.email,
        firstName: _Canaries.firstName,
        lastName: _Canaries.lastName,
        password: _Canaries.password,
        confirmPassword: _Canaries.password,
        acceptedLegal: true,
      );
      final acceptance = LegalAcceptance.tryCreate(
        termsVersion: '2026-01',
        privacyPolicyVersion: '2026-01',
      )!;
      final regReq = RegistrationRequest(
        email: _Canaries.email,
        firstName: _Canaries.firstName,
        lastName: _Canaries.lastName,
        password: _Canaries.password,
        acceptance: acceptance,
      );
      const authSession = AuthenticatedSession(tokens: tokens, userId: 42);
      const authSessionDto = AuthSessionDto(tokens: tokens, userId: 42);
      const loginReqDto = LoginRequestDto(
        login: _Canaries.email,
        password: _Canaries.password,
      );
      const registerReqDto = RegisterRequestDto(
        email: _Canaries.email,
        firstName: _Canaries.firstName,
        lastName: _Canaries.lastName,
        password: _Canaries.password,
        termsVersion: '2026-01',
        privacyPolicyVersion: '2026-01',
      );
      const forgotReqDto = ForgotPasswordRequestDto(email: _Canaries.email);

      const pqrs = PqrsSubmission(
        type: PqrsType.reclamo,
        name: '${_Canaries.firstName} ${_Canaries.lastName}',
        email: _Canaries.email,
        phone: _Canaries.phone,
        orderReference: _Canaries.nationalId,
        message: '${_Canaries.address} ${_Canaries.password}',
        acceptsDataPolicy: true,
      );

      final checkoutTicket = CheckoutTicket(
        checkoutRef: '3f2b8c1e-5a4d-4e6f-9b7a-1c2d3e4f5a6b',
        checkoutUrl: Uri.parse(_Canaries.checkoutUrl),
        allowedHosts: const {'staging.invalid'},
      );
      const checkoutSessionDto = checkout_dtos.CheckoutSessionDto(
        checkoutRef: '3f2b8c1e-5a4d-4e6f-9b7a-1c2d3e4f5a6b',
        checkoutUrl: _Canaries.checkoutUrl,
        allowedHosts: ['staging.invalid'],
      );

      final objects = <Object>[
        tokens,
        address,
        addressInput,
        userProfile,
        emailChangeResult,
        deletionStatus,
        addressDto,
        userProfileDto,
        updateProfileDto,
        changeEmailReqDto,
        changeEmailResDto,
        changePasswordReqDto,
        changePasswordResDto,
        addressInputDto,
        deletionReqDto,
        deletionStatusDto,
        orderSummary,
        orderPage,
        orderItem,
        orderDetail,
        orderSummaryDto,
        orderPageDto,
        orderItemDto,
        orderDetailDto,
        loginCreds,
        regForm,
        regReq,
        authSession,
        authSessionDto,
        loginReqDto,
        registerReqDto,
        forgotReqDto,
        pqrs,
        checkoutTicket,
        checkoutSessionDto,
      ];

      for (final obj in objects) {
        final dumped = obj.toString();
        for (final fragment in _Canaries.sensitiveFragments) {
          expect(
            dumped,
            isNot(contains(fragment)),
            reason: '${obj.runtimeType}.toString() filtró "$fragment": $dumped',
          );
        }
      }
    });

    test('ST-108 · DebugLogInterceptor no registra cabeceras, query, cuerpos ni canarios y está apagado en prod', () async {
      expect(AppEnvironment.prod.allowsDebugLogging, isFalse);
      expect(AppLogger.forEnvironment(AppEnvironment.prod).enabled, isFalse);

      // En prod apiClientProvider y bareApiClientProvider no adjuntan DebugLogInterceptor.
      for (final flavor in const ['prod', 'staging']) {
        final container = ProviderContainer(
          overrides: [
            appConfigProvider.overrideWithValue(_loadFlavorConfig(flavor)),
            appVersionProvider.overrideWithValue('1.0.0'),
            platformProvider.overrideWithValue('android'),
            secureKeyValueProvider.overrideWithValue(InMemorySecureKeyValue()),
            sessionDependenciesProvider.overrideWithValue(
              SessionDependencies(
                tokenStore: TokenStore(InMemorySecureKeyValue()),
                remote: FakeSessionRemote(),
              ),
            ),
          ],
        );
        final apiInterceptors = container
            .read(apiClientProvider)
            .dio
            .interceptors;
        final bareInterceptors = container
            .read(bareApiClientProvider)
            .dio
            .interceptors;
        final hasDebugInApi = apiInterceptors.any(
          (i) => i is DebugLogInterceptor,
        );
        final hasDebugInBare = bareInterceptors.any(
          (i) => i is DebugLogInterceptor,
        );
        expect(hasDebugInApi, flavor != 'prod', reason: flavor);
        expect(hasDebugInBare, flavor != 'prod', reason: flavor);
        container.dispose();
      }

      final logs = <String>[];
      final adapter = FakeHttpAdapter([
        (_) => FakeHttpAdapter.json({
          'data': {
            'email': _Canaries.email,
            'nationalId': _Canaries.nationalId,
            'phone': _Canaries.phone,
            'address': _Canaries.address,
            'accessToken': _Canaries.accessToken,
            'refreshToken': _Canaries.refreshToken,
          },
        }),
        (_) => FakeHttpAdapter.problem(401, 'unauthorized'),
        FakeHttpAdapter.connectionError,
      ]);

      final client = ApiClient.build(
        config: testConfig,
        adapter: adapter,
        interceptors: (_) => [DebugLogInterceptor(logs.add)],
      );

      await client.send(
        const ApiRequest(
          method: 'POST',
          path: '/auth/login',
          headers: {'Authorization': 'Bearer ${_Canaries.accessToken}'},
          query: {
            'email': _Canaries.email,
            'doc': _Canaries.nationalId,
            'phone': _Canaries.phone,
            'address': _Canaries.address,
            'password': _Canaries.password,
            'token': _Canaries.refreshToken,
          },
          body: {
            'login': _Canaries.email,
            'password': _Canaries.password,
            'address': _Canaries.address,
            'phone': _Canaries.phone,
            'nationalId': _Canaries.nationalId,
            'refreshToken': _Canaries.refreshToken,
          },
        ),
      );
      await client.send(
        const ApiRequest.get(
          '/me',
          headers: {'Authorization': 'Bearer ${_Canaries.accessToken}'},
          query: {'token': _Canaries.accessToken},
        ),
      );
      await client.send(
        const ApiRequest.get('/orders', query: {'q': _Canaries.address}),
      );

      expect(logs, hasLength(3));
      expect(logs[0], startsWith('POST /mobile/v1/auth/login -> 200'));
      expect(logs[1], startsWith('GET /mobile/v1/me -> 401'));
      expect(logs[2], startsWith('GET /mobile/v1/orders -> connectionError'));

      final joined = logs.join('\n');
      for (final fragment in _Canaries.sensitiveFragments) {
        expect(joined, isNot(contains(fragment)));
      }
    });

    test('ST-109 · ScrubbingCrashReporter depura canarios estructurados, tokens, consultas y entidades redactadas', () async {
      final inner = _RecordingCrashReporter();
      final reporter = ScrubbingCrashReporter(inner);

      const address = Address(
        firstName: _Canaries.firstName,
        lastName: _Canaries.lastName,
        company: _Canaries.company,
        nationalId: _Canaries.nationalId,
        address1: _Canaries.address,
        address2: '',
        department: 'ANT',
        city: 'Medellín',
        postcode: '',
        phone: _Canaries.phone,
      );
      const creds = LoginCredentials(
        login: _Canaries.email,
        password: _Canaries.password,
      );
      const pqrs = PqrsSubmission(
        type: PqrsType.queja,
        name: _Canaries.firstName,
        email: _Canaries.email,
        phone: _Canaries.phone,
        message: _Canaries.address,
        acceptsDataPolicy: true,
      );

      await reporter.recordError(
        StateError(
          'Fallo usuario ${_Canaries.email} doc ${_Canaries.nationalId} '
          'tel ${_Canaries.phone} token ${_Canaries.accessToken} '
          'refresh ${_Canaries.refreshToken} '
          'Bearer ${_Canaries.accessToken} '
          'obj=$address/$creds/$pqrs',
        ),
        StackTrace.fromString(
          '#0 fn (https://staging.invalid/me?email=${_Canaries.email}'
          '&address=${Uri.encodeComponent(_Canaries.address)}'
          '&password=${_Canaries.password}'
          '&token=${_Canaries.refreshToken})',
        ),
        fatal: true,
      );
      await reporter.log(
        'Breadcrumb ${_Canaries.email} ${_Canaries.phone} '
        '${_Canaries.nationalId} ${_Canaries.accessToken} '
        'https://staging.invalid/search?q=${Uri.encodeComponent(_Canaries.address)}',
      );

      final captured = [
        inner.errors.single,
        inner.stackTraces.single ?? '',
        inner.logs.single,
      ].join('\n');

      for (final fragment in _Canaries.sensitiveFragments) {
        expect(
          captured,
          isNot(contains(fragment)),
          reason: 'ScrubbingCrashReporter filtró "$fragment"',
        );
      }

      // Falla cerrado en PiiScrubber.
      expect(PiiScrubber.redacted, '<redacted>');

      // DEF-005: documentos y números de 6 dígitos también se depuran.
      expect(
        const PiiScrubber().scrub('Doc 123456 registrado'),
        'Doc <number> registrado',
      );
    });

    test(
      'ST-102 · Almacenamiento local no persiste PII ni accessToken en disco',
      () async {
        expect(HiveBoxes.cache, 'cache');
        expect(HiveBoxes.cart, 'cart');
        expect(PreferenceKeys.installMarker, 'install.marker');

        final secure = InMemorySecureKeyValue();
        final remote = FakeSessionRemote();
        final container = ProviderContainer(
          overrides: [
            sessionDependenciesProvider.overrideWithValue(
              SessionDependencies(
                tokenStore: TokenStore(secure),
                remote: remote,
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(sessionControllerProvider.notifier)
            .setSession(
              const SessionTokens(
                accessToken: _Canaries.accessToken,
                accessTokenExpiresIn: 900,
                refreshToken: _Canaries.refreshToken,
              ),
              userId: 42,
            );

        expect(secure.data.keys, [SecureKeys.refreshToken]);
        expect(secure.data.values, [_Canaries.refreshToken]);
        expect(
          secure.data.values.join('\n'),
          isNot(contains(_Canaries.accessToken)),
          reason: 'el access token vive solo en memoria',
        );
      },
    );

    test('ST-110 · uuidV4() genera UUID v4 aleatorios RFC 4122 sin identificadores de hardware', () {
      final rfc4122V4 = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      final generated = <String>{};
      final nodeSuffixes = <String>{};

      for (var i = 0; i < 500; i++) {
        final id = uuidV4();
        expect(isUuidV4(id), isTrue, reason: id);
        expect(rfc4122V4.hasMatch(id), isTrue, reason: id);
        generated.add(id);
        nodeSuffixes.add(id.substring(24));
      }

      expect(generated, hasLength(500));
      // Sin sufijo de nodo MAC estático compartido entre UUIDs.
      expect(nodeSuffixes.length, greaterThan(490));

      // Ausencia de APIs de identificadores de hardware o tracking en lib/.
      final hardwareIdRe = RegExp(
        r'\b(?:getAndroidId|identifierForVendor|ASIdentifierManager|'
        r'advertisingId|device_info_plus|android_id|imei)\b',
        caseSensitive: false,
      );
      final hits = <String>[];
      for (final file in _dartFilesInLib()) {
        final code = _stripDartComments(file.readAsStringSync());
        if (hardwareIdRe.hasMatch(code)) {
          hits.add(file.path);
        }
      }
      expect(hits, isEmpty);
    });
  });

  group('ST-103 · ST-111 · ST-120 · ST-130 · Manifiestos nativos Android e iOS', () {
    test('ST-103 · ST-111 · ST-120 · ST-130 · AndroidManifest.xml y reglas XML cumplen endurecimiento nativo', () {
      final manifest = _stripXmlComments(
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
      );

      // Permiso único INTERNET.
      final permissions = RegExp(r'<uses-permission\b[^>]*>')
          .allMatches(manifest)
          .map((m) => m.group(0)!)
          .toList();
      expect(permissions, hasLength(1));
      expect(permissions.single, contains('android.permission.INTERNET'));
      expect(manifest, isNot(contains('<uses-feature')));

      // Atributos de seguridad en <application>.
      final appOpenTag =
          RegExp(r'<application\b[^>]*>').firstMatch(manifest)?.group(0) ?? '';
      expect(appOpenTag, contains('android:allowBackup="false"'));
      expect(appOpenTag, contains('android:usesCleartextTraffic="false"'));
      expect(
        appOpenTag,
        contains(
          'android:networkSecurityConfig="@xml/network_security_config"',
        ),
      );
      expect(
        appOpenTag,
        contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
      );
      expect(
        appOpenTag,
        contains('android:fullBackupContent="@xml/backup_rules"'),
      );

      // Solo MainActivity exportada y cero services/receivers/providers.
      final exportedTags = RegExp(r'<[^>]*android:exported\s*=\s*"true"[^>]*>')
          .allMatches(manifest)
          .map((m) => m.group(0)!)
          .toList();
      expect(exportedTags, hasLength(1));
      expect(exportedTags.single, contains('android:name=".MainActivity"'));
      expect(manifest, isNot(contains('<service')));
      expect(manifest, isNot(contains('<receiver')));
      expect(manifest, isNot(contains('<provider')));

      // App Link acotado a https + ${deepLinkHost} + /app/pedido sin comodines.
      final intentFilters = RegExp(
        r'<intent-filter\b[^>]*>[\s\S]*?</intent-filter>',
      ).allMatches(manifest).map((m) => m.group(0)!).toList();
      final appLinkFilters = intentFilters
          .where((f) => f.contains('android.intent.action.VIEW'))
          .toList();
      expect(appLinkFilters, hasLength(1));
      final appLink = appLinkFilters.single;
      expect(appLink, contains('android:autoVerify="true"'));
      expect(appLink, contains('android.intent.category.DEFAULT'));
      expect(appLink, contains('android.intent.category.BROWSABLE'));
      expect(appLink, contains('android:scheme="https"'));
      expect(appLink, contains(r'android:host="${deepLinkHost}"'));
      expect(appLink, contains('android:path="/app/pedido"'));
      expect(appLink, isNot(contains('android:scheme="http"')));
      expect(appLink, isNot(contains('pathPrefix')));
      expect(appLink, isNot(contains('pathPattern')));
      expect(appLink, isNot(contains('*')));

      // debug y profile manifests tampoco añaden otros permisos ni cleartext.
      for (final variant in const ['debug', 'profile']) {
        final variantManifest = _stripXmlComments(
          File('android/app/src/$variant/AndroidManifest.xml')
              .readAsStringSync(),
        );
        final variantPerms = RegExp(r'<uses-permission\b[^>]*>')
            .allMatches(variantManifest)
            .map((m) => m.group(0)!)
            .toList();
        expect(variantPerms, hasLength(1), reason: variant);
        expect(
          variantPerms.single,
          contains('android.permission.INTERNET'),
          reason: variant,
        );
        expect(
          variantManifest,
          isNot(contains('usesCleartextTraffic="true"')),
          reason: variant,
        );
      }

      // network_security_config.xml (release): sin cleartext ni CA de usuario fuera de debug-overrides.
      final releaseNetSec = _stripXmlComments(
        File('android/app/src/main/res/xml/network_security_config.xml')
            .readAsStringSync(),
      );
      final releaseOutsideDebug = releaseNetSec.replaceAll(
        RegExp(r'<debug-overrides>[\s\S]*?</debug-overrides>'),
        '',
      );
      expect(releaseNetSec, contains('cleartextTrafficPermitted="false"'));
      expect(
        releaseOutsideDebug,
        isNot(contains('cleartextTrafficPermitted="true"')),
      );
      expect(releaseOutsideDebug, isNot(contains('<domain-config')));
      expect(releaseOutsideDebug, isNot(contains('src="user"')));
      expect(releaseOutsideDebug, contains('src="system"'));

      // Solo dev puede tener network_security_config específico (para 10.0.2.2).
      final devNetSec = _stripXmlComments(
        File('android/app/src/dev/res/xml/network_security_config.xml')
            .readAsStringSync(),
      );
      expect(devNetSec, contains('cleartextTrafficPermitted="false"'));
      expect(
        devNetSec,
        contains('<domain includeSubdomains="false">10.0.2.2</domain>'),
      );
      final devOutsideDebug = devNetSec.replaceAll(
        RegExp(r'<debug-overrides>[\s\S]*?</debug-overrides>'),
        '',
      );
      expect(devOutsideDebug, isNot(contains('src="user"')));

      final netSecFiles = Directory('android/app/src')
          .listSync(recursive: true)
          .whereType<File>()
          .map((f) => f.path.replaceAll(r'\', '/'))
          .where((p) => p.endsWith('network_security_config.xml'))
          .toSet();
      expect(netSecFiles, {
        'android/app/src/main/res/xml/network_security_config.xml',
        'android/app/src/dev/res/xml/network_security_config.xml',
      });

      // Reglas de exclusión de backup (Android <= 11 y Android 12+).
      final backupRules = _stripXmlComments(
        File('android/app/src/main/res/xml/backup_rules.xml')
            .readAsStringSync(),
      );
      expect(backupRules, isNot(contains('<include')));
      for (final domain in const [
        'root',
        'file',
        'database',
        'sharedpref',
        'external',
      ]) {
        expect(backupRules, contains('<exclude domain="$domain"/>'));
      }

      final extractionRules = _stripXmlComments(
        File('android/app/src/main/res/xml/data_extraction_rules.xml')
            .readAsStringSync(),
      );
      expect(extractionRules, isNot(contains('<include')));
      final cloudBlock =
          RegExp(r'<cloud-backup>[\s\S]*?</cloud-backup>')
              .firstMatch(extractionRules)
              ?.group(0) ??
          '';
      final transferBlock =
          RegExp(r'<device-transfer>[\s\S]*?</device-transfer>')
              .firstMatch(extractionRules)
              ?.group(0) ??
          '';
      for (final domain in const [
        'root',
        'file',
        'database',
        'sharedpref',
        'external',
      ]) {
        expect(cloudBlock, contains('<exclude domain="$domain"/>'));
        expect(transferBlock, contains('<exclude domain="$domain"/>'));
      }

      // build.gradle.kts: release no depurable y con R8.
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();
      expect(gradle, contains('isDebuggable = false'));
      expect(gradle, contains('isMinifyEnabled = true'));
      expect(gradle, contains('isShrinkResources = true'));
    });

    test('ST-111 · ST-130 · ios/Runner/Info.plist sin ATS permisivo, sin permisos sensibles y LSApplicationQueriesSchemes acotado', () {
      final plist = _stripXmlComments(
        File('ios/Runner/Info.plist').readAsStringSync(),
      );

      for (final forbiddenKey in const [
        'NSAppTransportSecurity',
        'NSAllowsArbitraryLoads',
        'NSAllowsArbitraryLoadsInWebContent',
        'NSExceptionAllowsInsecureHTTPLoads',
        'NSLocationWhenInUseUsageDescription',
        'NSLocationAlwaysUsageDescription',
        'NSLocationAlwaysAndWhenInUseUsageDescription',
        'NSCameraUsageDescription',
        'NSContactsUsageDescription',
        'NSMicrophoneUsageDescription',
        'NSPhotoLibraryUsageDescription',
        'NSUserTrackingUsageDescription',
        'CFBundleURLTypes',
      ]) {
        expect(
          plist,
          isNot(contains('<key>$forbiddenKey</key>')),
          reason: 'Info.plist no debe declarar $forbiddenKey',
        );
      }

      final queriesMatch = RegExp(
        r'<key>LSApplicationQueriesSchemes</key>\s*<array>([\s\S]*?)</array>',
      ).firstMatch(plist);
      expect(queriesMatch, isNotNull);
      final schemes = RegExp('<string>(.*?)</string>')
          .allMatches(queriesMatch!.group(1)!)
          .map((m) => m.group(1)!)
          .toList();
      expect(schemes, ['whatsapp', 'tel']);
    });
  });

  group('ST-125 · ST-170 · Well-known App Links y cero precarga del ticket de checkout', () {
    test('ST-125 · deploy/well-known/assetlinks.json y apple-app-site-association válidos y acotados a /app/pedido', () {
      final assetLinksRaw = jsonDecode(
        File('deploy/well-known/assetlinks.json').readAsStringSync(),
      );
      expect(assetLinksRaw, isA<List<dynamic>>());
      final statements = (assetLinksRaw as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(statements, isNotEmpty);
      for (final stmt in statements) {
        expect(
          stmt['relation'],
          contains('delegate_permission/common.handle_all_urls'),
        );
        final target = stmt['target'] as Map<String, dynamic>;
        expect(target['namespace'], 'android_app');
        expect((target['package_name'] as String).trim(), isNotEmpty);
        final fingerprints =
            target['sha256_cert_fingerprints'] as List<dynamic>;
        expect(fingerprints, isNotEmpty);
      }

      final aasaRaw = jsonDecode(
        File('deploy/well-known/apple-app-site-association').readAsStringSync(),
      );
      final aasa = aasaRaw as Map<String, dynamic>;
      final applinks = aasa['applinks'] as Map<String, dynamic>;
      final details = (applinks['details'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(details, isNotEmpty);

      for (final detail in details) {
        expect(detail.containsKey('paths'), isFalse);
        expect(detail['appIDs'] as List<dynamic>, isNotEmpty);
        final components = (detail['components'] as List<dynamic>)
            .cast<Map<String, dynamic>>();
        expect(components, isNotEmpty);
        for (final component in components) {
          final path = component['/'] as String;
          expect(path, '/app/pedido');
          expect(path, isNot(contains('*')));
          expect(path, isNot(contains('?')));
        }
      }
    });

    test('ST-170 · lib/ no usa mayLaunchUrl ni precarga HTTP de checkoutUrl (estático y en CheckoutController)', () async {
      final forbiddenTokens = RegExp(
        r'\b(?:mayLaunchUrl|warmUp|customTabsSession|prefetch)\b',
        caseSensitive: false,
      );
      final hits = <String>[];
      for (final file in _dartFilesInLib()) {
        final code = _stripDartComments(file.readAsStringSync());
        if (forbiddenTokens.hasMatch(code)) {
          hits.add(file.path);
        }
      }
      expect(hits, isEmpty);

      // Dinámico: POST /checkout entrega checkoutUrl SOLO a SecureBrowser.open(),
      // nunca hace GET/HEAD ni lo persiste en caché/estado.
      final adapter = FakeHttpAdapter([
        (_) => FakeHttpAdapter.json({
          'data': {
            'checkoutRef': refA,
            'checkoutUrl': _Canaries.checkoutUrl,
            'allowedHosts': ['staging.invalid'],
            'expiresAt': '2026-11-23T15:05:00Z',
          },
        }, status: 201),
      ]);
      final built = buildTestClient(adapter: adapter);
      final repo = ApiCheckoutRepository(
        CheckoutRemoteDataSource(built.client),
      );

      final browser = FakeSecureBrowser();
      final cache = MemoryCacheStore();
      final container = ProviderContainer(
        overrides: checkoutTestOverrides(
          cart: FakeCheckoutCart(),
          repo: repo,
          browser: browser,
          cache: cache,
          clock: ManualClock(),
          uuids: SequentialUuids(),
          session: FakeSessionController(
            const SessionAuthenticated(userId: 4821),
          ),
          remoteConfig: FakeRemoteConfigController(checkoutOn),
        ),
      );
      addTearDown(container.dispose);

      await container.read(checkoutControllerProvider.notifier).pay();

      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.method, 'POST');
      expect(adapter.requests.single.path, '/checkout');
      expect(browser.opened, [Uri.parse(_Canaries.checkoutUrl)]);
      expect(
        container.read(checkoutControllerProvider).phase,
        CheckoutPhase.awaitingResult,
      );

      // La URL del ticket no queda en caché ni en toString del estado.
      expect(
        container.read(checkoutControllerProvider).toString(),
        isNot(contains(_Canaries.ticketSecret)),
      );
      final storedValues = <String>[];
      for (final key in const [CachePendingCheckoutStore.key, 'config.v1']) {
        final read = await cache.read(key, CachePolicy.listing);
        if (read != null) storedValues.add(read.value);
      }
      expect(storedValues.join('\n'), isNot(contains(_Canaries.ticketSecret)));
    });
  });
}
