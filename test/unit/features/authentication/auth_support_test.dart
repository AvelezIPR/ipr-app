import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/app/providers.dart';
import 'package:ipr_mobile/core/storage/cache_store.dart';
import 'package:ipr_mobile/core/storage/durable_store.dart';
import 'package:ipr_mobile/features/authentication/authentication_providers.dart';
import 'package:ipr_mobile/features/authentication/data/repositories/api_auth_repository.dart';
import 'package:ipr_mobile/features/authentication/presentation/screens/auth_routes.dart';
import 'package:ipr_mobile/features/authentication/presentation/widgets/auth_texts.dart';
import 'package:ipr_mobile/shared/navigation/routes.dart';

import '../../../mocks/memory_preferences_store.dart';
import '../../../mocks/memory_secure_key_value.dart';
import '../../../mocks/test_clients.dart';

void main() {
  group('M2 · cableado', () {
    test('authRepositoryProvider entrega el repositorio sobre /mobile/v1', () {
      final container = ProviderContainer(
        overrides: coreOverrides(
          config: testConfig,
          appVersion: '1.0.0',
          platform: 'android',
          secure: InMemorySecureKeyValue(),
          preferences: InMemoryPreferencesStore(),
          cache: MemoryCacheStore(),
          durable: MemoryDurableStore(),
        ),
      );
      addTearDown(container.dispose);
      expect(container.read(authRepositoryProvider), isA<ApiAuthRepository>());
    });
  });

  group('M2 · RF-043 · from entre Login y Registro', () {
    test('sin origen o con origen no válido no se reenvía', () {
      expect(authLocation(Routes.register, null), Routes.register);
      expect(authLocation(Routes.register, ''), Routes.register);
      expect(authLocation(Routes.register, '/'), Routes.register);
      expect(authLocation(Routes.login, 'https://malo.test/x'), Routes.login);
      expect(authLocation(Routes.login, '//malo.test'), Routes.login);
      expect(authLocation(Routes.login, '/ruta-desconocida'), Routes.login);
    });

    test('un origen interno conocido se reenvía codificado', () {
      expect(
        authLocation(Routes.register, '/orders'),
        '${Routes.register}?from=%2Forders',
      );
      expect(
        authLocation(Routes.login, '/checkout?x=1'),
        '${Routes.login}?from=%2Fcheckout%3Fx%3D1',
      );
    });
  });

  group('M2 · formato de la espera', () {
    test('formatWait entrega m:ss', () {
      expect(formatWait(0), '0:00');
      expect(formatWait(7), '0:07');
      expect(formatWait(60), '1:00');
      expect(formatWait(125), '2:05');
      expect(formatWait(3600), '60:00');
      expect(formatWait(-4), '0:00');
    });
  });
}
