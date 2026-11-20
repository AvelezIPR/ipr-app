import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ipr_mobile/core/config/remote_config_controller.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/core/providers.dart';
import 'package:ipr_mobile/core/session/session_controller.dart';
import 'package:ipr_mobile/core/session/session_remote.dart';
import 'package:ipr_mobile/core/session/session_tokens.dart';
import 'package:ipr_mobile/core/session/token_store.dart';
import 'package:ipr_mobile/core/storage/cache_store.dart';
import 'package:ipr_mobile/features/profile/profile.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/ipr_localizations.dart';
import 'package:ipr_mobile/shared/design_system/ipr_theme.dart';
import 'package:material_ui/material_ui.dart';

import '../../../mocks/fake_http_adapter.dart';
import '../../../mocks/fake_session_remote.dart';
import '../../../mocks/memory_preferences_store.dart';
import '../../../mocks/memory_secure_key_value.dart';
import '../../../mocks/test_clients.dart';
import '../../../mocks/test_providers.dart';

const _marker = 'DESTINO ';

/// Destinos que la pestaña Cuenta puede abrir (cada uno pinta un marcador).
const _destinations = [
  '/login',
  '/register',
  '/orders',
  '/account/profile',
  '/account/addresses',
  '/account/data-rights',
  '/account/delete',
  '/support/legal',
];

/// [SessionRemote] cuyo `logout` espera una compuerta y cuenta las llamadas
/// (para probar el doble toque, TC-014) o falla con lo guionado.
final class GatedSessionRemote implements SessionRemote {
  new({this.logoutGate, this.logoutResult, this.logoutThrows = false});

  final Future<void>? logoutGate;
  final Result<void>? logoutResult;
  final bool logoutThrows;
  final List<String> logoutCalls = [];

  @override
  Future<Result<SessionTokens>> refresh(String refreshToken) async =>
      const Err(NoConnection());

  @override
  Future<Result<void>> logout({
    required String accessToken,
    bool all = false,
  }) async {
    logoutCalls.add(accessToken);
    if (logoutGate != null) await logoutGate;
    if (logoutThrows) throw StateError('fallo local simulado');
    return logoutResult ?? const Ok(null);
  }
}

/// Lo que una prueba necesita de la pestaña Cuenta montada.
final class AccountEnv {
  const new({
    required this.container,
    required this.secure,
    required this.adapter,
    required this.launcher,
  });

  final ProviderContainer container;
  final InMemorySecureKeyValue secure;
  final FakeHttpAdapter adapter;
  final FakeExternalLauncher launcher;

  SessionController get session =>
      container.read(sessionControllerProvider.notifier);

  /// Marca la sesión como iniciada (token de acceso en memoria).
  Future<void> signIn({int? userId}) =>
      session.setSession(fakeTokens('a'), userId: userId);

  /// Sin sesión (almacén vacío).
  Future<void> signedOut() => session.restore();
}

/// Monta [AccountScreen] en un `GoRouter` con destinos marcadores. La sesión
/// queda en `SessionUnknown` hasta que la prueba la fije con [AccountEnv].
Future<AccountEnv> pumpAccount(
  WidgetTester tester, {
  SessionRemote? remote,
  double textScale = 1,
  Size size = const Size(360, 800),
  List<Override> extra = const [],
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearAllTestValues();
  });

  final secure = InMemorySecureKeyValue();
  final adapter = FakeHttpAdapter();
  final launcher = FakeExternalLauncher();
  final client = buildTestClient(adapter: adapter).client;

  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: AccountScreen()),
      ),
      for (final path in _destinations)
        GoRoute(
          path: path,
          builder: (context, state) =>
              Scaffold(body: Center(child: Text('$_marker${state.uri}'))),
        ),
    ],
  );
  addTearDown(router.dispose);

  late ProviderContainer container;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(testConfig),
        appVersionProvider.overrideWithValue('1.0.0'),
        platformProvider.overrideWithValue('android'),
        secureKeyValueProvider.overrideWithValue(secure),
        preferencesStoreProvider.overrideWithValue(InMemoryPreferencesStore()),
        cacheStoreProvider.overrideWithValue(MemoryCacheStore()),
        apiClientProvider.overrideWithValue(client),
        externalLauncherProvider.overrideWithValue(launcher),
        sessionDependenciesProvider.overrideWithValue(
          SessionDependencies(
            tokenStore: TokenStore(secure),
            remote: remote ?? FakeSessionRemote(),
            sleep: (_) async {},
          ),
        ),
        ...extra,
      ],
      child: Builder(
        builder: (context) {
          container = ProviderScope.containerOf(context);
          return MaterialApp.router(
            theme: IprTheme.light(),
            locale: iprLocale,
            localizationsDelegates: iprLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          );
        },
      ),
    ),
  );
  await tester.pump();
  return AccountEnv(
    container: container,
    secure: secure,
    adapter: adapter,
    launcher: launcher,
  );
}

/// Destino abierto (lo pinta el marcador de cada ruta de prueba).
String destinationOf(WidgetTester tester) {
  final texts = tester
      .widgetList<Text>(find.textContaining(_marker))
      .map((t) => t.data!)
      .toList();
  expect(texts, hasLength(1), reason: 'se esperaba un solo destino abierto');
  return texts.single.substring(_marker.length);
}
