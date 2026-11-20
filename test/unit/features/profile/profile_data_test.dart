import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/core/session/session_gateway.dart';
import 'package:ipr_mobile/core/session/session_tokens.dart';
import 'package:ipr_mobile/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:ipr_mobile/features/profile/data/dtos/profile_dtos.dart';
import 'package:ipr_mobile/features/profile/data/repositories/api_profile_repository.dart';
import 'package:ipr_mobile/features/profile/domain/entities/profile_entities.dart';

import '../../../mocks/fake_http_adapter.dart';
import '../../../mocks/test_clients.dart';

final class _FakeGateway implements SessionGateway {
  @override
  String? get accessToken => 'ipra_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  @override
  Future<bool> hasRefreshToken() async => true;

  @override
  Future<RefreshOutcome> refresh() async => RefreshOutcome.expired;

  @override
  Future<void> expire() async {}
}

Map<String, Object?> _profileJson({
  String email = 'qa@example.test',
  String firstName = 'Ana',
  String lastName = 'Prueba',
}) => {
  'data': {
    'id': 42,
    'email': email,
    'firstName': firstName,
    'lastName': lastName,
    'displayName': '$firstName $lastName',
    'billing': {
      'firstName': firstName,
      'lastName': lastName,
      'company': '',
      'nationalId': '000-000-001',
      'address1': 'Calle 10 # 20-30',
      'address2': '',
      'department': 'ANT',
      'city': 'Medellín',
      'postcode': '',
      'phone': '3000000000',
    },
    'shipping': null,
  },
};

Map<String, Object?> _sessionJson(String tag) => {
  'accessToken': 'ipra_${tag.padRight(43, 'x')}',
  'accessTokenExpiresIn': 900,
  'refreshToken': 'iprr_${tag.padRight(43, 'y')}',
  'refreshTokenExpiresAt': '2026-12-20T00:00:00Z',
  'tokenType': 'Bearer',
  'sessionId': '3f2b8c1e-5a4d-4e6f-9b7a-1c2d3e4f5a6b',
};

void main() {
  group('M4 · profile DTOs sin PII en toString y minimización', () {
    test(
      'toString de DTOs de petición y respuesta nunca imprime secretos ni PII',
      () {
        const emailReq = ChangeEmailRequestDto(
          newEmail: 'secreto@example.test',
          currentPassword: 'MiPasswordSecreto123',
        );
        const passReq = ChangePasswordRequestDto(
          currentPassword: 'MiPasswordSecreto123',
          newPassword: 'NuevoPassword456',
        );
        const delReq = AccountDeletionRequestDto(
          currentPassword: 'MiPasswordSecreto123',
        );
        const addrReq = AddressInputDto(
          firstName: 'Ana',
          lastName: 'Secreta',
          address1: 'Calle Secreta 123',
          department: 'ANT',
          city: 'Medellín',
          nationalId: '999999999',
          phone: '3111111111',
        );

        for (final text in [
          emailReq.toString(),
          passReq.toString(),
          delReq.toString(),
          addrReq.toString(),
        ]) {
          expect(text, isNot(contains('MiPasswordSecreto123')));
          expect(text, isNot(contains('NuevoPassword456')));
          expect(text, isNot(contains('secreto@example.test')));
          expect(text, isNot(contains('999999999')));
          expect(text, isNot(contains('3111111111')));
        }
      },
    );

    test('AC-110-13 · AccountDeletionRequestDto no contiene id de cuenta', () {
      const dto = AccountDeletionRequestDto(currentPassword: 'QaPassword123');
      expect(dto.toJson(), {
        'currentPassword': 'QaPassword123',
        'confirm': true,
      });
    });

    test('AddressInputDto omite opcionales vacíos para cumplir minLength del contrato', () {
      const dto = AddressInputDto(
        firstName: 'Ana',
        lastName: 'Prueba',
        address1: 'Calle 10',
        department: 'BOG',
        city: 'Bogotá',
      );
      expect(dto.toJson(), {
        'firstName': 'Ana',
        'lastName': 'Prueba',
        'address1': 'Calle 10',
        'department': 'BOG',
        'city': 'Bogotá',
      });
    });
  });

  group('M4 · ApiProfileRepository', () {
    test('getMe y updateNames envían Bearer y decodifican el perfil', () async {
      final adapter = FakeHttpAdapter([
        (_) => FakeHttpAdapter.json(_profileJson()),
        (_) => FakeHttpAdapter.json(_profileJson(lastName: 'Editada')),
      ]);
      final repo = ApiProfileRepository(
        ProfileRemoteDataSource(
          buildTestClient(adapter: adapter, gateway: _FakeGateway()).client,
        ),
      );

      final me = (await repo.getMe() as Ok<UserProfile>).value;
      expect(me.email, 'qa@example.test');
      expect(me.billing?.city, 'Medellín');

      final updated = (await repo.updateNames(
        firstName: 'Ana',
        lastName: 'Editada',
      ) as Ok<UserProfile>).value;
      expect(updated.lastName, 'Editada');
      expect(adapter.requests[1].method, 'PATCH');
      expect(adapter.requests[1].path, '/me');
    });

    test('AC-104-4 · AC-105-5 · changeEmail y changePassword rotan sesión; 403 → Validation(currentPassword)', () async {
      final adapter = FakeHttpAdapter([
        (_) => FakeHttpAdapter.json({
          'data': {
            'session': _sessionJson('e'),
            'user': _profileJson(email: 'nuevo@example.test')['data'],
          },
        }),
        (_) => FakeHttpAdapter.json({
          'data': {'session': _sessionJson('p')},
        }),
        (_) => FakeHttpAdapter.problem(403, 'current_password_invalid'),
        (_) => FakeHttpAdapter.problem(409, 'email_in_use'),
      ]);
      final repo = ApiProfileRepository(
        ProfileRemoteDataSource(
          buildTestClient(adapter: adapter, gateway: _FakeGateway()).client,
        ),
      );

      final emailRes = (await repo.changeEmail(
        newEmail: 'nuevo@example.test',
        currentPassword: 'QaPassword123',
      ) as Ok<EmailChangeResult>).value;
      expect(emailRes.tokens.accessToken, startsWith('ipra_e'));
      expect(emailRes.profile.email, 'nuevo@example.test');

      final passRes = (await repo.changePassword(
        currentPassword: 'QaPassword123',
        newPassword: 'QaNewPassword123',
      ) as Ok<SessionTokens>).value;
      expect(passRes.accessToken, startsWith('ipra_p'));

      final badPass = (await repo.changePassword(
        currentPassword: 'Wrong',
        newPassword: 'QaNewPassword123',
      ) as Err).failure;
      expect(badPass, isA<Validation>());
      expect((badPass as Validation).fields.single.field, 'currentPassword');

      final conflict = (await repo.changeEmail(
        newEmail: 'otro@example.test',
        currentPassword: 'QaPassword123',
      ) as Err).failure;
      expect(conflict, isA<Conflict>());
      expect((conflict as Conflict).code, 'email_in_use');
    });

    test('PUT /me/addresses/{type} envía el tipo correcto', () async {
      final adapter = FakeHttpAdapter([
        (_) => FakeHttpAdapter.json(_profileJson()),
      ]);
      final repo = ApiProfileRepository(
        ProfileRemoteDataSource(
          buildTestClient(adapter: adapter, gateway: _FakeGateway()).client,
        ),
      );
      final res = await repo.putAddress(
        type: AddressType.shipping,
        input: const AddressInput(
          firstName: 'Ana',
          lastName: 'Prueba',
          address1: 'Carrera 50',
          department: 'BOG',
          city: 'Bogotá',
        ),
      );
      expect(res, isA<Ok<UserProfile>>());
      expect(adapter.requests.single.method, 'PUT');
      expect(adapter.requests.single.path, '/me/addresses/shipping');
    });

    test('TC-088 · CR-005 · POST /me/deletion envía Idempotency-Key y sin id de cuenta', () async {
      final adapter = FakeHttpAdapter([
        (_) => FakeHttpAdapter.json({
          'data': {
            'requestId': '3f2b8c1e-5a4d-4e6f-9b7a-1c2d3e4f5a6b',
            'status': 'scheduled',
            'completeBy': '2026-12-10T23:59:59-05:00',
          },
        }, status: 202),
      ]);
      final repo = ApiProfileRepository(
        ProfileRemoteDataSource(
          buildTestClient(adapter: adapter, gateway: _FakeGateway()).client,
        ),
      );
      final res = await repo.requestDeletion(
        currentPassword: 'QaPassword123',
        idempotencyKey: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      );
      expect(
        (res as Ok<AccountDeletionStatus>).value.status,
        AccountDeletionState.scheduled,
      );
      final req = adapter.requests.single;
      expect(
        req.headers['Idempotency-Key'],
        'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      );
      final body = req.data is String
          ? jsonDecode(req.data as String)
          : req.data;
      expect(body, {'currentPassword': 'QaPassword123', 'confirm': true});
    });
  });
}
