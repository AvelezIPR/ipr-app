import 'dart:convert';

import 'package:dio/dio.dart' show ResponseBody;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/config/app_config.dart';
import 'package:ipr_mobile/core/config/app_version.dart';
import 'package:ipr_mobile/core/config/remote_config.dart';
import 'package:ipr_mobile/core/config/remote_config_controller.dart';
import 'package:ipr_mobile/core/config/remote_config_dto.dart';
import 'package:ipr_mobile/core/config/remote_config_repository.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/storage/cache_store.dart';

import '../../../mocks/fake_http_adapter.dart';
import '../../../mocks/test_clients.dart';

const Map<String, Map<String, Object>> _configJson = {
  'data': {
    'minSupportedVersion': {'android': '1.0.0', 'ios': '1.2.0'},
    'recommendedVersion': {'android': '1.1.0', 'ios': '1.3.0'},
    'features': {
      'checkoutEnabled': true,
      'pqrsEnabled': true,
      'btuCalculatorEnabled': false,
    },
    'contact': {
      'whatsapp': {'number': '573014021882', 'defaultMessage': 'Hola'},
      'phone': {'display': '(604) 3604440', 'dial': '+576043604440'},
      'salesEmail': 'ventas@example.invalid',
    },
    'checkout': {
      'allowedHosts': ['IPRPartesyRepuestos.com'],
      'returnPathPrefix': '/app/pedido',
    },
    'legal': {
      'terms': {'version': '1', 'url': 'https://x'},
    },
    'campoDesconocidoFuturo': 42,
  },
};

void main() {
  group('AppConfig · ADR-009 (configuración pública por flavor)', () {
    Map<String, String> valid() => {
      'environment': 'prod',
      'apiBaseUrl': 'https://iprpartesyrepuestos.com/mobile/v1',
      'deepLinkHost': 'IPRPartesyRepuestos.com',
      'checkoutAllowedHosts': 'a.com, B.com ,,',
      'mediaHosts': 'img.example.com',
      'supportWhatsApp': '573014021882',
    };

    test('normaliza hosts a minúsculas y descarta vacíos', () {
      final c = AppConfig.fromMap(valid());
      expect(c.environment, AppEnvironment.prod);
      expect(c.deepLinkHost, 'iprpartesyrepuestos.com');
      expect(c.checkoutAllowedHosts, {'a.com', 'b.com'});
    });

    test('falla rápido si falta una clave', () {
      for (final key in valid().keys) {
        final map = valid()..remove(key);
        expect(
          () => AppConfig.fromMap(map),
          throwsFormatException,
          reason: key,
        );
      }
    });

    test('rechaza un entorno desconocido', () {
      expect(
        () => AppConfig.fromMap(valid()..['environment'] = 'qa'),
        throwsFormatException,
      );
    });

    test('exige https fuera de dev; dev admite http local', () {
      expect(
        () => AppConfig.fromMap(
          valid()..['apiBaseUrl'] = 'http://x.com/mobile/v1',
        ),
        throwsFormatException,
      );
      final dev = AppConfig.fromMap(
        valid()
          ..['environment'] = 'dev'
          ..['apiBaseUrl'] = 'http://10.0.2.2:8787/mobile/v1',
      );
      expect(dev.apiBaseUrl.scheme, 'http');
    });

    test('checkoutAllowedHosts no puede quedar vacío', () {
      expect(
        () => AppConfig.fromMap(valid()..['checkoutAllowedHosts'] = ' , '),
        throwsFormatException,
      );
    });

    test('SC-045 · solo dev y staging registran depuración', () {
      expect(AppEnvironment.dev.allowsDebugLogging, isTrue);
      expect(AppEnvironment.staging.allowsDebugLogging, isTrue);
      expect(AppEnvironment.prod.allowsDebugLogging, isFalse);
    });

    test(
      'fromEnvironment sin --dart-define falla con un mensaje accionable',
      () {
        expect(
          AppConfig.fromEnvironment,
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('--dart-define-from-file'),
            ),
          ),
        );
      },
    );
  });

  group('Versiones', () {
    test('compareVersions', () {
      expect(compareVersions('1.2.3', '1.2.3'), 0);
      expect(compareVersions('1.2.4', '1.2.3'), greaterThan(0));
      expect(compareVersions('1.10.0', '1.9.9'), greaterThan(0));
      expect(compareVersions('0.9.0', '1.0.0'), lessThan(0));
      expect(compareVersions('1.2.3+45', '1.2.3'), 0);
      expect(() => compareVersions('1.2', '1.2.3'), throwsFormatException);
    });

    test('isVersionSupported; una versión ilegible se considera soportada', () {
      expect(isVersionSupported(current: '1.2.0', minimum: '1.1.0'), isTrue);
      expect(isVersionSupported(current: '1.0.9', minimum: '1.1.0'), isFalse);
      expect(isVersionSupported(current: 'rara', minimum: '1.1.0'), isTrue);
    });
  });

  group('RemoteConfig · mapeo tolerante', () {
    test('lee la plataforma correcta y normaliza hosts', () {
      final dto = RemoteConfigDto.fromJson(
        _configJson['data']! as Map<String, dynamic>,
      );
      final android = dto.toEntity(platform: 'android');
      final ios = dto.toEntity(platform: 'ios');
      expect(android.minSupportedVersion, '1.0.0');
      expect(ios.minSupportedVersion, '1.2.0');
      expect(android.checkoutEnabled, isTrue);
      expect(
        android.btuCalculatorEnabled,
        isFalse,
        reason: 'D-08 apagada por el servidor',
      );
      expect(android.checkoutAllowedHosts, {'iprpartesyrepuestos.com'});
      expect(android.returnPathPrefix, '/app/pedido');
      expect(android.whatsappNumber, '573014021882');
      expect(android.phoneDial, '+576043604440');
    });

    test('M0 · D-08 · un /config vacío deja TODO apagado (falla cerrado)', () {
      final entity = RemoteConfigDto.fromJson(const {})
          .toEntity(platform: 'android');
      expect(entity.checkoutEnabled, isFalse);
      expect(entity.pqrsEnabled, isFalse);
      expect(entity.btuCalculatorEnabled, isFalse);
      expect(entity.checkoutAllowedHosts, isEmpty);
      expect(entity.minSupportedVersion, isNull);
    });

    test('defaults usa el WhatsApp público del flavor y nada habilitado', () {
      final d = RemoteConfig.defaults(testConfig);
      expect(d.whatsappNumber, '573000000000');
      expect(
        d.checkoutEnabled || d.pqrsEnabled || d.btuCalculatorEnabled,
        isFalse,
      );
    });
  });

  group('RemoteConfigRepository', () {
    RemoteConfigRepository repo(
      FakeHttpAdapter adapter,
      MemoryCacheStore cache,
    ) => RemoteConfigRepository(
      client: buildTestClient(adapter: adapter).client,
      cache: cache,
      platform: 'android',
    );

    test('guarda en caché y devuelve la configuración', () async {
      final cache = MemoryCacheStore();
      final adapter = FakeHttpAdapter([
        (_) => FakeHttpAdapter.json(
          _configJson,
          headers: {
            'etag': ['"v1"'],
          },
        ),
      ]);
      final r = repo(adapter, cache);
      final result = await r.fetch();
      expect(result.valueOrNull!.checkoutEnabled, isTrue);
      expect((await r.readCached())!.pqrsEnabled, isTrue);
    });

    test('envía If-None-Match y un 304 conserva la caché', () async {
      final cache = MemoryCacheStore();
      final adapter = FakeHttpAdapter([
        (_) => FakeHttpAdapter.json(
          _configJson,
          headers: {
            'etag': ['"v1"'],
          },
        ),
        (_) => ResponseBody.fromString('', 304),
      ]);
      final r = repo(adapter, cache);
      await r.fetch();
      final second = await r.fetch();
      expect(adapter.requests.last.headers['If-None-Match'], '"v1"');
      expect(second.valueOrNull!.checkoutEnabled, isTrue);
    });

    test('304 sin caché es un fallo de contrato', () async {
      final adapter = FakeHttpAdapter([
        (_) => ResponseBody.fromString('', 304),
      ]);
      final result = await repo(adapter, MemoryCacheStore()).fetch();
      expect(result.failureOrNull, isA<ContractFailure>());
    });

    test('un fallo de red no toca lo guardado', () async {
      final cache = MemoryCacheStore();
      final adapter = FakeHttpAdapter([
        (_) => FakeHttpAdapter.json(_configJson),
        FakeHttpAdapter.connectionError,
        FakeHttpAdapter.connectionError,
        FakeHttpAdapter.connectionError,
      ]);
      final r = repo(adapter, cache);
      await r.fetch();
      final result = await r.fetch();
      expect(result.failureOrNull, isA<NoConnection>());
      expect(await r.readCached(), isNotNull);
    });

    test('una respuesta sin data es ContractFailure y no se guarda', () async {
      final cache = MemoryCacheStore();
      final adapter = FakeHttpAdapter([
        (_) => FakeHttpAdapter.json({'x': 1}),
      ]);
      final r = repo(adapter, cache);
      expect((await r.fetch()).failureOrNull, isA<ContractFailure>());
      expect(await r.readCached(), isNull);
    });

    test('readCached ignora una entrada corrupta', () async {
      final cache = MemoryCacheStore();
      await cache.write('config.v1', '{no json');
      final r = repo(FakeHttpAdapter(), cache);
      expect(await r.readCached(), isNull);
    });
  });

  group('RemoteConfigController · RNF-029', () {
    ProviderContainer make(FakeHttpAdapter adapter, MemoryCacheStore cache) {
      final client = buildTestClient(adapter: adapter).client;
      return ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(testConfig),
          appVersionProvider.overrideWithValue('1.0.0'),
          remoteConfigRepositoryProvider.overrideWithValue(
            RemoteConfigRepository(
              client: client,
              cache: cache,
              platform: 'android',
            ),
          ),
        ],
      );
    }

    test('arranca con defaults apagados', () {
      final c = make(FakeHttpAdapter(), MemoryCacheStore());
      addTearDown(c.dispose);
      final state = c.read(remoteConfigProvider);
      expect(state.source, RemoteConfigSource.defaults);
      expect(state.config.checkoutEnabled, isFalse);
    });

    test('refresh aplica la configuración de red', () async {
      final adapter = FakeHttpAdapter([
        (_) => FakeHttpAdapter.json(_configJson),
      ]);
      final c = make(adapter, MemoryCacheStore());
      addTearDown(c.dispose);
      await c.read(remoteConfigProvider.notifier).refresh();
      final state = c.read(remoteConfigProvider);
      expect(state.source, RemoteConfigSource.network);
      expect(state.config.checkoutEnabled, isTrue);
      expect(state.fetchedAt, isNotNull);
    });

    test(
      'refreshIfStale no vuelve a pedir antes de 5 minutos y sí después',
      () async {
        var now = DateTime.utc(2026, 11, 19, 12);
        final adapter = FakeHttpAdapter()
          ..fallback = (_) => FakeHttpAdapter.json(_configJson);
        final c = make(adapter, MemoryCacheStore());
        addTearDown(c.dispose);
        final notifier = c.read(remoteConfigProvider.notifier)
          ..clock = () => now;
        await notifier.refreshIfStale();
        await notifier.refreshIfStale();
        expect(adapter.requests, hasLength(1));
        now = now.add(const Duration(minutes: 6));
        await notifier.refreshIfStale();
        expect(adapter.requests, hasLength(2));
      },
    );

    test(
      'sin red se usa el último valor guardado (arranque offline)',
      () async {
        final cache = MemoryCacheStore();
        await cache.write('config.v1', jsonEncode(_configJson['data']));
        final c = make(FakeHttpAdapter(), cache);
        addTearDown(c.dispose);
        await c.read(remoteConfigProvider.notifier).loadCached();
        final state = c.read(remoteConfigProvider);
        expect(state.source, RemoteConfigSource.cache);
        expect(state.config.checkoutEnabled, isTrue);
      },
    );

    test('loadCached sin caché no cambia el estado', () async {
      final c = make(FakeHttpAdapter(), MemoryCacheStore());
      addTearDown(c.dispose);
      await c.read(remoteConfigProvider.notifier).loadCached();
      expect(c.read(remoteConfigProvider).source, RemoteConfigSource.defaults);
    });

    test('un fallo de red en refresh conserva el estado actual', () async {
      final adapter = FakeHttpAdapter()
        ..fallback = FakeHttpAdapter.connectionError;
      final c = make(adapter, MemoryCacheStore());
      addTearDown(c.dispose);
      await c.read(remoteConfigProvider.notifier).refresh();
      expect(c.read(remoteConfigProvider).source, RemoteConfigSource.defaults);
    });

    test(
      'updateRequiredProvider: versión por debajo del mínimo remoto',
      () async {
        final adapter = FakeHttpAdapter([
          (_) => FakeHttpAdapter.json({
            'data': {
              'minSupportedVersion': {'android': '2.0.0', 'ios': '2.0.0'},
            },
          }),
        ]);
        final c = make(adapter, MemoryCacheStore());
        addTearDown(c.dispose);
        expect(c.read(updateRequiredProvider), isFalse);
        await c.read(remoteConfigProvider.notifier).refresh();
        expect(c.read(updateRequiredProvider), isTrue);
      },
    );

    test('updateRequiredProvider: un 426 lo activa', () {
      final c = make(FakeHttpAdapter(), MemoryCacheStore());
      addTearDown(c.dispose);
      c.read(remoteConfigProvider.notifier)
        ..markUpgradeRequired()
        ..markUpgradeRequired();
      expect(c.read(updateRequiredProvider), isTrue);
    });
  });
}
