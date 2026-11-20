import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ipr_mobile/app/providers.dart';
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
import 'package:ipr_mobile/core/session/session_state.dart';
import 'package:ipr_mobile/core/session/session_tokens.dart';
import 'package:ipr_mobile/features/cart/cart.dart';
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

final class _RecordingProtection implements ScreenProtection {
  int enables = 0;
  int disables = 0;

  @override
  Future<void> enable() async => enables++;

  @override
  Future<void> disable() async => disables++;
}

final class _RecordingBrowser implements SecureBrowser {
  final List<Uri> opened = [];

  @override
  Future<bool> open(Uri url) async {
    opened.add(url);
    return true;
  }
}

UserProfile _sampleProfile() => const UserProfile(
  id: 42,
  email: 'qa.cliente@example.test',
  firstName: 'Ana',
  lastName: 'Prueba',
  displayName: 'Ana Prueba',
  billing: Address(
    firstName: 'Ana',
    lastName: 'Prueba',
    company: '',
    nationalId: '000-000-001',
    address1: 'Calle 10 # 20-30',
    address2: '',
    department: 'ANT',
    city: 'Medellín',
    postcode: '',
    phone: '3000000000',
  ),
);

final class _StubProfileRepository implements ProfileRepository {
  int updateNamesCalls = 0;
  int changeEmailCalls = 0;
  int changePasswordCalls = 0;
  int putAddressCalls = 0;
  int deletionCalls = 0;

  FutureOr<Result<UserProfile>> Function()? onGetMe;
  FutureOr<Result<UserProfile>> Function()? onUpdateNames;
  FutureOr<Result<EmailChangeResult>> Function()? onChangeEmail;
  FutureOr<Result<SessionTokens>> Function()? onChangePassword;
  FutureOr<Result<UserProfile>> Function(AddressType, AddressInput)?
  onPutAddress;
  FutureOr<Result<AccountDeletionStatus>> Function()? onDeletion;

  @override
  Future<Result<UserProfile>> getMe({
    RequestCancellation? cancellation,
  }) async => await onGetMe?.call() ?? Ok(_sampleProfile());

  @override
  Future<Result<UserProfile>> updateNames({
    required String firstName,
    required String lastName,
    RequestCancellation? cancellation,
  }) async {
    updateNamesCalls++;
    return await onUpdateNames?.call() ??
        Ok(
          UserProfile(
            id: 42,
            email: 'qa.cliente@example.test',
            firstName: firstName,
            lastName: lastName,
            displayName: '$firstName $lastName',
          ),
        );
  }

  @override
  Future<Result<EmailChangeResult>> changeEmail({
    required String newEmail,
    required String currentPassword,
    RequestCancellation? cancellation,
  }) async {
    changeEmailCalls++;
    return await onChangeEmail?.call() ??
        Ok(
          EmailChangeResult(
            tokens: fakeTokens('email'),
            profile: _sampleProfile(),
          ),
        );
  }

  @override
  Future<Result<SessionTokens>> changePassword({
    required String currentPassword,
    required String newPassword,
    RequestCancellation? cancellation,
  }) async {
    changePasswordCalls++;
    return await onChangePassword?.call() ?? Ok(fakeTokens('pass'));
  }

  @override
  Future<Result<UserProfile>> putAddress({
    required AddressType type,
    required AddressInput input,
    RequestCancellation? cancellation,
  }) async {
    putAddressCalls++;
    return await onPutAddress?.call(type, input) ?? Ok(_sampleProfile());
  }

  @override
  Future<Result<AccountDeletionStatus>> requestDeletion({
    required String currentPassword,
    required String idempotencyKey,
    RequestCancellation? cancellation,
  }) async {
    deletionCalls++;
    return await onDeletion?.call() ??
        Ok(
          AccountDeletionStatus(
            requestId: 'req-1',
            status: AccountDeletionState.scheduled,
            completeBy: DateTime.utc(2026, 12, 10),
          ),
        );
  }
}

final class _FixedRemoteConfig extends RemoteConfigController {
  new(this._fixed);
  final RemoteConfig _fixed;

  @override
  RemoteConfigState build() =>
      RemoteConfigState(config: _fixed, source: RemoteConfigSource.network);
}

Future<
  ({
    ProviderContainer container,
    _RecordingProtection protection,
    _RecordingBrowser browser,
    FakeExternalLauncher launcher,
  })
>
_pumpScreen(
  WidgetTester tester, {
  required String initialLocation,
  _StubProfileRepository? repo,
  RemoteConfig? remoteConfig,
  double textScale = 1,
}) async {
  tester.view
    ..physicalSize = const Size(360, 800)
    ..devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearAllTestValues();
  });

  final protection = _RecordingProtection();
  final browser = _RecordingBrowser();
  final launcher = FakeExternalLauncher();
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: Routes.account, builder: (_, _) => const AccountScreen()),
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
    ],
  );
  addTearDown(router.dispose);

  late ProviderContainer container;
  await tester.pumpWidget(
    ProviderScope(
      overrides: testOverrides(
        launcher: launcher,
        extra: [
          ...integrationOverrides(),
          profileRepositoryProvider.overrideWithValue(
            repo ?? _StubProfileRepository(),
          ),
          screenProtectionProvider.overrideWithValue(protection),
          secureBrowserProvider.overrideWithValue(browser),
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
  await container
      .read(sessionControllerProvider.notifier)
      .setSession(fakeTokens('a'), userId: 42);
  await tester.pumpAndSettle();
  return (
    container: container,
    protection: protection,
    browser: browser,
    launcher: launcher,
  );
}

void main() {
  group('TC-093 · TC-094 · ProfileScreen y ChangePasswordScreen', () {
    testWidgets(
      'carga perfil, edita nombre, valida correo inválido sin emitir y conserva entrada sin red',
      (tester) async {
        final repo = _StubProfileRepository();
        final env = await _pumpScreen(
          tester,
          initialLocation: Routes.profile,
          repo: repo,
        );
        expect(env.protection.enables, greaterThanOrEqualTo(1));
        expect(find.text('qa.cliente@example.test'), findsOneWidget);

        await tester.enterText(find.byType(TextField).at(0), 'María');
        await tester.ensureVisible(find.text('Guardar nombre'));
        await tester.tap(find.text('Guardar nombre'));
        await tester.pumpAndSettle();
        expect(repo.updateNamesCalls, 1);

        await tester.enterText(find.byType(TextField).at(2), 'correo-malo');
        await tester.ensureVisible(find.text('Cambiar correo'));
        await tester.tap(find.text('Cambiar correo'));
        await tester.pumpAndSettle();
        expect(repo.changeEmailCalls, 0);
        expect(find.text('Escribe un correo válido.'), findsOneWidget);

        repo.onChangeEmail = () => const Err(NoConnection());
        await tester.enterText(
          find.byType(TextField).at(2),
          'nuevo@example.test',
        );
        await tester.enterText(find.byType(TextField).at(3), 'QaPassword123');
        await tester.ensureVisible(find.text('Cambiar correo'));
        await tester.tap(find.text('Cambiar correo'));
        await tester.pumpAndSettle();
        expect(find.text('nuevo@example.test'), findsOneWidget);
      },
    );

    testWidgets(
      'AC-105-1 · AC-105-4 · ChangePasswordScreen tiene 3 campos enmascarados y valida longitud/coincidencia',
      (tester) async {
        final repo = _StubProfileRepository();
        await _pumpScreen(
          tester,
          initialLocation: Routes.changePassword,
          repo: repo,
        );

        final fields = tester
            .widgetList<TextField>(find.byType(TextField))
            .toList();
        expect(fields, hasLength(3));
        expect(fields.every((f) => f.obscureText), isTrue);

        await tester.enterText(find.byType(TextField).at(0), 'OldPass123');
        await tester.enterText(find.byType(TextField).at(1), 'Qa12345');
        await tester.enterText(find.byType(TextField).at(2), 'Distinta1');
        await tester.ensureVisible(find.text('Actualizar contraseña'));
        await tester.tap(find.text('Actualizar contraseña'));
        await tester.pumpAndSettle();

        expect(repo.changePasswordCalls, 0);
        expect(find.text('Debe tener al menos 8 caracteres.'), findsOneWidget);
        expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
      },
    );
  });

  group('TC-096 · AddressesScreen', () {
    testWidgets(
      'selector de Colombia y ciudades dependientes del departamento',
      (tester) async {
        final repo = _StubProfileRepository();
        await _pumpScreen(
          tester,
          initialLocation: Routes.addresses,
          repo: repo,
        );

        expect(find.text('País: Colombia'), findsOneWidget);
        expect(find.text('Antioquia'), findsOneWidget);
        expect(find.text('Medellín'), findsOneWidget);

        await tester.ensureVisible(find.text('Envío'));
        await tester.tap(find.text('Envío'));
        await tester.pumpAndSettle();
        expect(find.text('Guardar envío'), findsOneWidget);

        // Cambiar a Bogotá actualiza la lista dependiente de municipios.
        await tester.ensureVisible(find.text('Departamento'));
        await tester.tap(find.text('Departamento'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Bogotá').last);
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Ciudad / municipio'));
        await tester.tap(find.text('Ciudad / municipio'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Bogotá').last);
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField).at(1), 'Ana');
        await tester.enterText(find.byType(TextField).at(2), 'Prueba');
        await tester.enterText(
          find.byType(TextField).at(4),
          'Carrera 10 # 1-2',
        );
        await tester.ensureVisible(find.text('Guardar envío'));
        await tester.tap(find.text('Guardar envío'));
        await tester.pumpAndSettle();
        expect(repo.putAddressCalls, 1);
      },
    );
  });

  group('TC-087 · TC-088 · TC-089 · DeleteAccountScreen', () {
    testWidgets(
      'muestra aviso de /config, cancelar no envía y doble toque emite 1 solicitud',
      (tester) async {
        final gate = Completer<Result<AccountDeletionStatus>>();
        final repo = _StubProfileRepository()..onDeletion = () => gate.future;
        final env = await _pumpScreen(
          tester,
          initialLocation: Routes.deleteAccount,
          repo: repo,
          remoteConfig: const RemoteConfig(
            accountDeletionNotice: 'Aviso legal publicado por el servidor.',
          ),
        );
        await env.container.read(cartProvider.notifier).add(10, 1);

        expect(
          find.text('Aviso legal publicado por el servidor.'),
          findsOneWidget,
        );

        // Sin marcar confirmación ni contraseña no envía.
        await tester.ensureVisible(find.text('Eliminar mi cuenta'));
        await tester.tap(find.text('Eliminar mi cuenta'));
        await tester.pump();
        expect(repo.deletionCalls, 0);

        await tester.ensureVisible(find.byType(CheckboxListTile));
        await tester.tap(find.byType(CheckboxListTile));
        await tester.enterText(find.byType(TextField).first, 'QaPassword123');
        await tester.ensureVisible(find.text('Eliminar mi cuenta'));
        await tester.tap(find.text('Eliminar mi cuenta'));
        await tester.tap(find.text('Eliminar mi cuenta'), warnIfMissed: false);
        await tester.pump();

        expect(repo.deletionCalls, 1);
        gate.complete(
          Ok(
            AccountDeletionStatus(
              requestId: 'req-1',
              status: AccountDeletionState.scheduled,
              completeBy: DateTime.utc(2026, 12, 10),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          env.container.read(sessionControllerProvider),
          isA<SessionAnonymous>(),
        );
        expect(env.container.read(cartProvider).lines, isEmpty);
      },
    );
  });

  group('TC-097 · AC-111 · DataRightsScreen', () {
    testWidgets(
      'informa eliminación en la app y abre portal/correo de /config',
      (tester) async {
        final env = await _pumpScreen(
          tester,
          initialLocation: Routes.dataRights,
          remoteConfig: const RemoteConfig(
            dataRightsUrl: 'https://staging.invalid/derechos',
            dataRightsEmail: 'privacidad@staging.invalid',
          ),
        );

        expect(find.text('Ir a eliminar cuenta'), findsOneWidget);
        await tester.tap(find.text('Abrir canal de derechos en el navegador'));
        await tester.pumpAndSettle();
        expect(
          env.browser.opened.single.toString(),
          'https://staging.invalid/derechos',
        );

        await tester.tap(find.text('Escribir a privacidad@staging.invalid'));
        await tester.pumpAndSettle();
        expect(env.launcher.opened.single.scheme, 'mailto');
      },
    );

    testWidgets('sin canal publicado muestra estado explicativo y Reintentar', (
      tester,
    ) async {
      await _pumpScreen(
        tester,
        initialLocation: Routes.dataRights,
        remoteConfig: const RemoteConfig(),
      );
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.text('Escribir por WhatsApp'), findsOneWidget);
    });
  });

  group('RNF-068..071 · accesibilidad y texto al 200 % en perfil', () {
    for (final route in [
      Routes.profile,
      Routes.changePassword,
      Routes.addresses,
      Routes.deleteAccount,
      Routes.dataRights,
    ]) {
      testWidgets('$route al 200 % sin desbordar y guías de accesibilidad', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await _pumpScreen(
          tester,
          initialLocation: route,
          textScale: 2,
          remoteConfig: const RemoteConfig(
            accountDeletionNotice: 'Aviso de eliminación.',
            dataRightsUrl: 'https://staging.invalid/derechos',
          ),
        );
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });
    }
  });
}
