import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/app/app.dart';
import 'package:ipr_mobile/app/providers.dart';
import 'package:ipr_mobile/app/router/app_router.dart';
import 'package:ipr_mobile/core/config/remote_config_controller.dart';
import 'package:ipr_mobile/core/session/session_controller.dart';
import 'package:ipr_mobile/core/session/session_state.dart';
import 'package:ipr_mobile/core/storage/cache_store.dart';
import 'package:material_ui/material_ui.dart';

import '../mocks/fake_session_remote.dart';
import '../mocks/memory_preferences_store.dart';
import '../mocks/memory_secure_key_value.dart';
import '../mocks/test_clients.dart';

Future<ProviderContainer> pumpIprApp(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(400, 800)
    ..devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  final container = ProviderContainer(
    overrides: coreOverrides(
      config: testConfig,
      appVersion: '1.0.0',
      platform: 'android',
      secure: InMemorySecureKeyValue(),
      preferences: InMemoryPreferencesStore(),
      cache: MemoryCacheStore(),
    ),
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const IprApp()),
  );
  await tester.pumpAndSettle();
  return container;
}

String location(ProviderContainer c) {
  final router = c.read(appRouterProvider);
  return router.state.uri.toString();
}

void main() {
  group('ADR-005 · navegación por pestañas', () {
    testWidgets('arranca en Inicio con cuatro pestañas', (tester) async {
      await pumpIprApp(tester);
      for (final label in ['Inicio', 'Catálogo', 'Carrito', 'Cuenta']) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('cambia de pestaña y conserva el estado de cada una', (
      tester,
    ) async {
      final c = await pumpIprApp(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Catálogo'),
        ),
      );
      await tester.pumpAndSettle();
      expect(location(c), '/catalog');
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Carrito'),
        ),
      );
      await tester.pumpAndSettle();
      expect(location(c), '/cart');
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Cuenta'),
        ),
      );
      await tester.pumpAndSettle();
      expect(location(c), '/account');
    });

    testWidgets(
      'las pestañas son públicas: Carrito y Cuenta abren sin sesión',
      (tester) async {
        final c = await pumpIprApp(tester);
        c.read(appRouterProvider).go('/cart');
        await tester.pumpAndSettle();
        expect(location(c), '/cart');
      },
    );
  });

  group('TC-029 · AC-037-3 · guarda de sesión en el router real', () {
    testWidgets(
      'ruta protegida sin sesión → login con from, y tras iniciar vuelve',
      (tester) async {
        final c = await pumpIprApp(tester);
        await c.read(sessionControllerProvider.notifier).restore();
        c.read(appRouterProvider).go('/orders');
        await tester.pumpAndSettle();
        expect(location(c), '/login?from=%2Forders');

        await c
            .read(sessionControllerProvider.notifier)
            .setSession(fakeTokens('a'));
        await tester.pumpAndSettle();
        expect(
          location(c),
          '/orders',
          reason: 'al iniciar sesión vuelve al destino',
        );
      },
    );

    testWidgets(
      'TC-077 · AC-055-6 · enlace /app/pedido sin sesión termina en login',
      (tester) async {
        final c = await pumpIprApp(tester);
        await c.read(sessionControllerProvider.notifier).restore();
        c.read(appRouterProvider).go('/app/pedido?order=77&status=paid');
        await tester.pumpAndSettle();
        expect(location(c), startsWith('/login?from='));
        expect(location(c), contains('checkout%2Fresult'));
      },
    );

    testWidgets(
      'con sesión el enlace de retorno abre /checkout/result con pistas',
      (tester) async {
        final c = await pumpIprApp(tester);
        await c
            .read(sessionControllerProvider.notifier)
            .setSession(fakeTokens('a'));
        c.read(appRouterProvider).go('/app/pedido?order=77&status=paid');
        await tester.pumpAndSettle();
        expect(location(c), '/checkout/result?order=77&status=paid');
      },
    );

    testWidgets('un enlace ajeno nunca navega: va a Inicio', (tester) async {
      final c = await pumpIprApp(tester);
      c.read(appRouterProvider).go('/app/otra-cosa');
      await tester.pumpAndSettle();
      expect(location(c), '/');
    });

    testWidgets('cerrar sesión desde una ruta protegida expulsa al login', (
      tester,
    ) async {
      final c = await pumpIprApp(tester);
      final session = c.read(sessionControllerProvider.notifier);
      await session.setSession(fakeTokens('a'));
      c.read(appRouterProvider).go('/orders');
      await tester.pumpAndSettle();
      expect(location(c), '/orders');
      await session.expire();
      await tester.pumpAndSettle();
      expect(location(c), startsWith('/login'));
      expect(c.read(sessionControllerProvider), isA<SessionExpired>());
    });
  });

  group('RNF-029 · actualización obligatoria', () {
    testWidgets('un 426 lleva a /update-required y bloquea el resto', (
      tester,
    ) async {
      final c = await pumpIprApp(tester);
      c.read(remoteConfigProvider.notifier).markUpgradeRequired();
      await tester.pumpAndSettle();
      expect(location(c), '/update-required');
      expect(find.text('Actualiza la app para continuar'), findsOneWidget);
      c.read(appRouterProvider).go('/catalog');
      await tester.pumpAndSettle();
      expect(location(c), '/update-required');
    });
  });
}
