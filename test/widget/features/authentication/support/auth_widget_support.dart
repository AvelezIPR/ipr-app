import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ipr_mobile/app/providers.dart';
import 'package:ipr_mobile/core/config/remote_config.dart';
import 'package:ipr_mobile/core/config/remote_config_controller.dart';
import 'package:ipr_mobile/core/external/screen_protection.dart';
import 'package:ipr_mobile/core/providers.dart';
import 'package:ipr_mobile/core/session/session_controller.dart';
import 'package:ipr_mobile/core/storage/cache_store.dart';
import 'package:ipr_mobile/core/storage/durable_store.dart';
import 'package:ipr_mobile/features/authentication/authentication.dart';
import 'package:ipr_mobile/features/authentication/authentication_providers.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/ipr_localizations.dart';
import 'package:ipr_mobile/shared/design_system/ipr_theme.dart';
import 'package:ipr_mobile/shared/navigation/routes.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../mocks/memory_preferences_store.dart';
import '../../../../mocks/memory_secure_key_value.dart';
import '../../../../mocks/test_clients.dart';
import '../../../../unit/features/authentication/support/auth_fakes.dart';

/// Registra la protección de captura (SC-035).
final class FakeScreenProtection implements ScreenProtection {
  int enabled = 0;
  int disabled = 0;

  @override
  Future<void> enable() async => enabled++;

  @override
  Future<void> disable() async => disabled++;
}

/// Lo que devuelve [pumpAuth]: el repositorio falso, los almacenes (para
/// comprobar qué se guardó) y el router.
final class AuthWidgetHarness {
  new({
    required this.repo,
    required this.router,
    required this.secure,
    required this.preferences,
    required this.cache,
    required this.protection,
    required this.remoteConfig,
  });

  final FakeAuthRepository repo;
  final GoRouter router;
  final InMemorySecureKeyValue secure;
  final InMemoryPreferencesStore preferences;
  final MemoryCacheStore cache;
  final FakeScreenProtection protection;
  final FakeRemoteConfigController remoteConfig;

  /// Contenedor de Riverpod de la app montada.
  ProviderContainer container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(Navigator).first));

  SessionController session(WidgetTester tester) =>
      container(tester).read(sessionControllerProvider.notifier);
}

/// Monta las pantallas de autenticación dentro de un `GoRouter` mínimo: `/`
/// (inicio), las tres pantallas y `Routes.legal` (la construye otra feature).
/// Empieza en `/` y empuja [start], de modo que hay a dónde volver.
Future<AuthWidgetHarness> pumpAuth(
  WidgetTester tester, {
  required String start,
  FakeAuthRepository? repo,
  RemoteConfig config = legalConfig,
  double textScale = 1,
  Size size = const Size(360, 800),
}) async {
  final fake = repo ?? FakeAuthRepository();
  final secure = InMemorySecureKeyValue();
  final preferences = InMemoryPreferencesStore();
  final cache = MemoryCacheStore();
  final protection = FakeScreenProtection();
  final remoteConfig = FakeRemoteConfigController(config);

  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view
      ..resetPhysicalSize()
      ..resetDevicePixelRatio()
      ..resetViewInsets();
    tester.platformDispatcher.clearAllTestValues();
  });

  final router = GoRouter(
    routes: [
      GoRoute(
        path: Routes.home,
        builder: (_, _) => const Scaffold(body: Text('PANTALLA INICIO')),
      ),
      GoRoute(
        path: Routes.login,
        builder: (_, state) =>
            LoginScreen(from: state.uri.queryParameters['from']),
      ),
      GoRoute(
        path: Routes.register,
        builder: (_, state) =>
            RegisterScreen(from: state.uri.queryParameters['from']),
      ),
      GoRoute(
        path: Routes.passwordRecovery,
        builder: (_, _) => const PasswordRecoveryScreen(),
      ),
      GoRoute(
        path: Routes.legal,
        builder: (_, _) => const Scaffold(body: Text('PANTALLA LEGAL')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...coreOverrides(
          config: testConfig,
          appVersion: '1.0.0',
          platform: 'android',
          secure: secure,
          preferences: preferences,
          cache: cache,
          durable: MemoryDurableStore(),
        ),
        authRepositoryProvider.overrideWithValue(fake),
        remoteConfigProvider.overrideWith(() => remoteConfig),
        screenProtectionProvider.overrideWithValue(protection),
      ],
      child: MaterialApp.router(
        theme: IprTheme.light(),
        locale: iprLocale,
        localizationsDelegates: iprLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pump();
  unawaited_(router.push(start));
  await tester.pumpAndSettle();

  return AuthWidgetHarness(
    repo: fake,
    router: router,
    secure: secure,
    preferences: preferences,
    cache: cache,
    protection: protection,
    remoteConfig: remoteConfig,
  );
}

void unawaited_(Future<Object?> future) => future.ignore();

/// Campo de texto por su etiqueta exacta.
Finder fieldLabeled(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
  description: 'TextField "$label"',
);

/// Botón principal (el `FilledButton` de la pantalla).
Finder get submitButton => find.byType(FilledButton);

bool isEnabled(WidgetTester tester, Finder button) =>
    tester.widget<FilledButton>(button).onPressed != null;

/// ¿Está enmascarado el campo con esa etiqueta?
bool isObscured(WidgetTester tester, String label) => tester
    .widget<EditableText>(
      find.descendant(
        of: fieldLabeled(label),
        matching: find.byType(EditableText),
      ),
    )
    .obscureText;

Future<void> type(WidgetTester tester, String label, String text) async {
  final finder = fieldLabeled(label);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.enterText(finder, text);
  await tester.pump();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

/// Pulsa el botón principal y deja que se resuelvan las respuestas simples.
Future<void> submit(WidgetTester tester) async {
  await tapVisible(tester, submitButton);
  await tester.pump();
}
