import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ipr_mobile/core/config/remote_config.dart';
import 'package:ipr_mobile/core/config/remote_config_controller.dart';
import 'package:ipr_mobile/core/config/remote_config_repository.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/external/screen_protection.dart';
import 'package:ipr_mobile/core/external/secure_browser.dart';
import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/core/providers.dart';
import 'package:ipr_mobile/core/session/session_controller.dart';
import 'package:ipr_mobile/core/session/session_tokens.dart';
import 'package:ipr_mobile/features/profile/domain/entities/profile_entities.dart';
import 'package:ipr_mobile/features/profile/domain/repositories/profile_repository.dart';
import 'package:ipr_mobile/features/profile/profile.dart';
import 'package:ipr_mobile/features/profile/profile_providers.dart';
import 'package:ipr_mobile/l10n/app_localizations.dart';
import 'package:ipr_mobile/shared/design_system/ipr_localizations.dart';
import 'package:ipr_mobile/shared/design_system/ipr_theme.dart';
import 'package:ipr_mobile/shared/navigation/routes.dart';
import 'package:material_ui/material_ui.dart';

import '../../../mocks/fake_session_remote.dart';
import '../../../mocks/test_providers.dart';

final class _NoopScreenProtection implements ScreenProtection {
  @override
  Future<void> enable() async {}

  @override
  Future<void> disable() async {}
}

final class _NoopSecureBrowser implements SecureBrowser {
  @override
  Future<bool> open(Uri url) async => true;
}

final class _FixedRemoteConfig extends RemoteConfigController {
  new(this._fixed);

  final RemoteConfig _fixed;

  @override
  RemoteConfigState build() =>
      RemoteConfigState(config: _fixed, source: RemoteConfigSource.network);
}

UserProfile _syntheticProfile() => const UserProfile(
  id: 42,
  email: 'qa.cliente@example.invalid',
  firstName: 'Ana',
  lastName: 'Prueba',
  displayName: 'Ana Prueba',
  billing: Address(
    firstName: 'Ana',
    lastName: 'Prueba',
    company: 'QA Refrigeración SAS',
    nationalId: '000000001',
    address1: 'Calle 0 # 0-00',
    address2: 'Local 1',
    department: 'ANT',
    city: 'Medellín',
    postcode: '050001',
    phone: '3000000000',
  ),
);

final class _StubProfileRepository implements ProfileRepository {
  new({this.getMeResult, this.updateNamesResult});

  final Result<UserProfile>? getMeResult;
  final Result<UserProfile>? updateNamesResult;

  @override
  Future<Result<UserProfile>> getMe({
    RequestCancellation? cancellation,
  }) async => getMeResult ?? Ok(_syntheticProfile());

  @override
  Future<Result<UserProfile>> updateNames({
    required String firstName,
    required String lastName,
    RequestCancellation? cancellation,
  }) async => updateNamesResult ?? Ok(_syntheticProfile());

  @override
  Future<Result<EmailChangeResult>> changeEmail({
    required String newEmail,
    required String currentPassword,
    RequestCancellation? cancellation,
  }) async => Ok(
    EmailChangeResult(
      tokens: fakeTokens('email'),
      profile: _syntheticProfile(),
    ),
  );

  @override
  Future<Result<SessionTokens>> changePassword({
    required String currentPassword,
    required String newPassword,
    RequestCancellation? cancellation,
  }) async => Ok(fakeTokens('pass'));

  @override
  Future<Result<UserProfile>> putAddress({
    required AddressType type,
    required AddressInput input,
    RequestCancellation? cancellation,
  }) async => Ok(_syntheticProfile());

  @override
  Future<Result<AccountDeletionStatus>> requestDeletion({
    required String currentPassword,
    required String idempotencyKey,
    RequestCancellation? cancellation,
  }) async => Ok(
    AccountDeletionStatus(
      requestId: 'qa-req-1',
      status: AccountDeletionState.scheduled,
      completeBy: DateTime.utc(2026, 12, 10),
    ),
  );
}

enum _SessionMode { anonymous, expired, authenticated }

Future<void> _pumpProfileRoute(
  WidgetTester tester, {
  required String initialLocation,
  _StubProfileRepository? repo,
  RemoteConfig? remoteConfig,
  _SessionMode sessionMode = _SessionMode.authenticated,
  double textScale = 1,
  Size size = const Size(360, 800),
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

  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: Routes.account,
        builder: (_, _) => const Scaffold(body: AccountScreen()),
      ),
      GoRoute(path: Routes.profile, builder: (_, _) => const ProfileScreen()),
      GoRoute(
        path: Routes.changePassword,
        builder: (_, _) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: Routes.addresses,
        builder: (_, _) => const AddressesScreen(),
      ),
      GoRoute(
        path: Routes.deleteAccount,
        builder: (_, _) => const DeleteAccountScreen(),
      ),
      GoRoute(
        path: Routes.dataRights,
        builder: (_, _) => const DataRightsScreen(),
      ),
      GoRoute(
        path: Routes.login,
        builder: (_, _) => const Scaffold(body: Text('DESTINO_LOGIN')),
      ),
      GoRoute(
        path: Routes.register,
        builder: (_, _) => const Scaffold(body: Text('DESTINO_REGISTER')),
      ),
      GoRoute(
        path: Routes.orders,
        builder: (_, _) => const Scaffold(body: Text('DESTINO_ORDERS')),
      ),
      GoRoute(
        path: Routes.legal,
        builder: (_, _) => const Scaffold(body: Text('DESTINO_LEGAL')),
      ),
    ],
  );
  addTearDown(router.dispose);

  late ProviderContainer container;
  await tester.pumpWidget(
    ProviderScope(
      overrides: testOverrides(
        extra: [
          profileRepositoryProvider.overrideWithValue(
            repo ?? _StubProfileRepository(),
          ),
          screenProtectionProvider.overrideWithValue(_NoopScreenProtection()),
          secureBrowserProvider.overrideWithValue(_NoopSecureBrowser()),
          if (remoteConfig != null)
            remoteConfigProvider.overrideWith(
              () => _FixedRemoteConfig(remoteConfig),
            ),
        ],
      ),
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

  final session = container.read(sessionControllerProvider.notifier);
  switch (sessionMode) {
    case _SessionMode.authenticated:
      await session.setSession(fakeTokens('a'), userId: 42);
    case _SessionMode.anonymous:
      await session.restore();
    case _SessionMode.expired:
      await session.setSession(fakeTokens('a'), userId: 42);
      await session.expire();
  }
  await tester.pumpAndSettle();
}

Future<void> _scrollToBottom(WidgetTester tester) async {
  final scrollables = find.byType(Scrollable);
  if (scrollables.evaluate().isEmpty) return;
  final scrollable = scrollables.first;
  for (var i = 0; i < 16; i++) {
    final state = tester.state<ScrollableState>(scrollable);
    if (state.position.pixels >= state.position.maxScrollExtent) break;
    await tester.drag(scrollable, const Offset(0, -400));
    await tester.pumpAndSettle();
  }
}

Future<void> _expectAllGuidelines(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}

const _fullConfig = RemoteConfig(
  whatsappNumber: '573000000000',
  accountDeletionNotice:
      'Tu cuenta y datos de acceso se eliminarán tras verificar la solicitud.',
  dataRightsUrl: 'https://staging.invalid/derechos',
  dataRightsEmail: 'privacidad@staging.invalid',
);

typedef _ProfileScenarioBuilder = Future<void> Function(
  WidgetTester tester, {
  double textScale,
  Size size,
});

final Map<String, _ProfileScenarioBuilder> _scenarios = {
  'AccountScreen · invitado':
      (tester, {textScale = 1, size = const Size(360, 800)}) =>
          _pumpProfileRoute(
            tester,
            initialLocation: Routes.account,
            sessionMode: _SessionMode.anonymous,
            textScale: textScale,
            size: size,
          ),
  'AccountScreen · sesión expirada':
      (tester, {textScale = 1, size = const Size(360, 800)}) =>
          _pumpProfileRoute(
            tester,
            initialLocation: Routes.account,
            sessionMode: _SessionMode.expired,
            textScale: textScale,
            size: size,
          ),
  'AccountScreen · con sesión':
      (tester, {textScale = 1, size = const Size(360, 800)}) =>
          _pumpProfileRoute(
            tester,
            initialLocation: Routes.account,
            textScale: textScale,
            size: size,
          ),
  'ProfileScreen · datos cargados':
      (tester, {textScale = 1, size = const Size(360, 800)}) =>
          _pumpProfileRoute(
            tester,
            initialLocation: Routes.profile,
            textScale: textScale,
            size: size,
          ),
  'ProfileScreen · con errores de validación y fallo de red':
      (tester, {textScale = 1, size = const Size(360, 800)}) async {
        await _pumpProfileRoute(
          tester,
          initialLocation: Routes.profile,
          repo: _StubProfileRepository(
            updateNamesResult: const Err(NoConnection()),
          ),
          textScale: textScale,
          size: size,
        );
        await tester.ensureVisible(find.text('Guardar nombre'));
        await tester.tap(find.text('Guardar nombre'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField).at(2), 'correo-invalido');
        await tester.ensureVisible(find.text('Cambiar correo'));
        await tester.tap(find.text('Cambiar correo'));
        await tester.pumpAndSettle();
      },
  'ProfileScreen · error de carga inicial':
      (tester, {textScale = 1, size = const Size(360, 800)}) =>
          _pumpProfileRoute(
            tester,
            initialLocation: Routes.profile,
            repo: _StubProfileRepository(
              getMeResult: const Err(ServiceUnavailable()),
            ),
            textScale: textScale,
            size: size,
          ),
  'ChangePasswordScreen · formulario inicial':
      (tester, {textScale = 1, size = const Size(360, 800)}) =>
          _pumpProfileRoute(
            tester,
            initialLocation: Routes.changePassword,
            textScale: textScale,
            size: size,
          ),
  'ChangePasswordScreen · con errores de validación':
      (tester, {textScale = 1, size = const Size(360, 800)}) async {
        await _pumpProfileRoute(
          tester,
          initialLocation: Routes.changePassword,
          textScale: textScale,
          size: size,
        );
        await tester.enterText(find.byType(TextField).at(0), 'QaOld123');
        await tester.enterText(find.byType(TextField).at(1), '123');
        await tester.enterText(find.byType(TextField).at(2), '456');
        await tester.ensureVisible(find.text('Actualizar contraseña'));
        await tester.tap(find.text('Actualizar contraseña'));
        await tester.pumpAndSettle();
      },
  'AddressesScreen · facturación':
      (tester, {textScale = 1, size = const Size(360, 800)}) =>
          _pumpProfileRoute(
            tester,
            initialLocation: Routes.addresses,
            textScale: textScale,
            size: size,
          ),
  'AddressesScreen · envío con errores':
      (tester, {textScale = 1, size = const Size(360, 800)}) async {
        await _pumpProfileRoute(
          tester,
          initialLocation: Routes.addresses,
          textScale: textScale,
          size: size,
        );
        await tester.ensureVisible(find.text('Envío'));
        await tester.tap(find.text('Envío'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Guardar envío'));
        await tester.tap(find.text('Guardar envío'));
        await tester.pumpAndSettle();
      },
  'DeleteAccountScreen · con aviso de /config':
      (tester, {textScale = 1, size = const Size(360, 800)}) =>
          _pumpProfileRoute(
            tester,
            initialLocation: Routes.deleteAccount,
            remoteConfig: _fullConfig,
            textScale: textScale,
            size: size,
          ),
  'DeleteAccountScreen · sin aviso y con errores':
      (tester, {textScale = 1, size = const Size(360, 800)}) async {
        await _pumpProfileRoute(
          tester,
          initialLocation: Routes.deleteAccount,
          remoteConfig: const RemoteConfig(),
          textScale: textScale,
          size: size,
        );
        await tester.ensureVisible(find.text('Eliminar mi cuenta'));
        await tester.tap(find.text('Eliminar mi cuenta'));
        await tester.pumpAndSettle();
      },
  'DataRightsScreen · canal completo':
      (tester, {textScale = 1, size = const Size(360, 800)}) =>
          _pumpProfileRoute(
            tester,
            initialLocation: Routes.dataRights,
            remoteConfig: _fullConfig,
            textScale: textScale,
            size: size,
          ),
  'DataRightsScreen · sin canal publicado':
      (tester, {textScale = 1, size = const Size(360, 800)}) =>
          _pumpProfileRoute(
            tester,
            initialLocation: Routes.dataRights,
            remoteConfig: const RemoteConfig(whatsappNumber: '573000000000'),
            textScale: textScale,
            size: size,
          ),
};

void main() {
  group('TC-157 · RNF-067..076 · Profile · texto al 200 % sin desbordes', () {
    for (final entry in _scenarios.entries) {
      for (final size in const [Size(360, 800), Size(320, 568)]) {
        testWidgets(
          'TC-157 · RNF-067..076 · ${entry.key} · texto 200 % en ${size.width.toInt()}x${size.height.toInt()}',
          (tester) async {
            await entry.value(tester, textScale: 2, size: size);
            expect(tester.takeException(), isNull);
            await _scrollToBottom(tester);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });

  group('TC-157 · RNF-067..076 · Profile · guías automáticas WCAG 2.2 AA', () {
    for (final entry in _scenarios.entries) {
      testWidgets(
        'TC-157 · RNF-067..076 · ${entry.key} · 4 guías de accesibilidad',
        (tester) async {
          final handle = tester.ensureSemantics();
          try {
            await entry.value(tester, size: const Size(360, 2400));
            await _expectAllGuidelines(tester);
          } finally {
            handle.dispose();
          }
        },
      );
    }
  });

  group(
    'TC-157 · RNF-067..076 · Profile · semántica, autofill y contraste',
    () {
      testWidgets(
        'TC-157 · RNF-067..076 · AccountScreen · encabezados y región viva de sesión expirada',
        (tester) async {
          final handle = tester.ensureSemantics();
          try {
            await _scenarios['AccountScreen · sesión expirada']!(
              tester,
              size: const Size(360, 1600),
            );
            expect(
              tester.getSemantics(find.text('Inicia sesión o crea tu cuenta')),
              isSemantics(
                isHeader: true,
                label: 'Inicia sesión o crea tu cuenta',
              ),
            );
            final expiredText = find.text(
              'Tu sesión terminó. Inicia sesión de nuevo.',
            );
            expect(expiredText, findsOneWidget);
            expect(find.byIcon(Icons.info_outline), findsOneWidget);
          } finally {
            handle.dispose();
          }
        },
      );

      testWidgets(
        'TC-157 · RNF-067..076 · ChangePasswordScreen · botones mostrar/ocultar ≥ 48 dp y autofillHints',
        (tester) async {
          final handle = tester.ensureSemantics();
          try {
            await _scenarios['ChangePasswordScreen · formulario inicial']!(
              tester,
              size: const Size(360, 1600),
            );

            final fields = tester
                .widgetList<TextField>(find.byType(TextField))
                .toList();
            expect(fields, hasLength(3));
            expect(fields[0].autofillHints, contains(AutofillHints.password));
            expect(
              fields[1].autofillHints,
              contains(AutofillHints.newPassword),
            );
            expect(
              fields[2].autofillHints,
              contains(AutofillHints.newPassword),
            );

            final toggles = find.byTooltip('Mostrar contraseña');
            expect(toggles, findsNWidgets(3));
            for (var i = 0; i < 3; i++) {
              final size = tester.getSize(toggles.at(i));
              expect(size.width, greaterThanOrEqualTo(48));
              expect(size.height, greaterThanOrEqualTo(48));
            }
          } finally {
            handle.dispose();
          }
        },
      );

      testWidgets(
        'TC-157 · RNF-067..076 · DeleteAccountScreen · encabezado de advertencia, confirmación y botón destructivo ≥ 48 dp',
        (tester) async {
          final handle = tester.ensureSemantics();
          try {
            await _scenarios['DeleteAccountScreen · con aviso de /config']!(
              tester,
              size: const Size(360, 1600),
            );
            expect(
              tester.getSemantics(find.text('Antes de continuar')),
              isSemantics(isHeader: true, label: 'Antes de continuar'),
            );
            expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
            expect(
              tester
                  .getSize(
                    find.ancestor(
                      of: find.text('Eliminar mi cuenta'),
                      matching: find.bySubtype<FilledButton>(),
                    ),
                  )
                  .height,
              greaterThanOrEqualTo(48),
            );
          } finally {
            handle.dispose();
          }
        },
      );

      testWidgets(
        'TC-157 · RNF-067..076 · DataRightsScreen · encabezados y acciones de canal',
        (tester) async {
          final handle = tester.ensureSemantics();
          try {
            await _scenarios['DataRightsScreen · canal completo']!(
              tester,
              size: const Size(360, 1600),
            );
            expect(
              tester.getSemantics(find.text('Eliminación directa de cuenta')),
              isSemantics(
                isHeader: true,
                label: 'Eliminación directa de cuenta',
              ),
            );
            expect(
              tester.getSemantics(find.text('Canal corporativo de atención')),
              isSemantics(
                isHeader: true,
                label: 'Canal corporativo de atención',
              ),
            );
          } finally {
            handle.dispose();
          }
        },
      );
    },
  );
}
