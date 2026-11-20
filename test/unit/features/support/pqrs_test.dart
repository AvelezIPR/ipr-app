import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/support/data/datasources/pqrs_remote_datasource.dart';
import 'package:ipr_mobile/features/support/domain/entities/pqrs.dart';
import 'package:ipr_mobile/features/support/domain/repositories/pqrs_repository.dart';
import 'package:ipr_mobile/features/support/domain/rules/pqrs_validation.dart';
import 'package:ipr_mobile/features/support/presentation/controllers/pqrs_controller.dart';
import 'package:ipr_mobile/features/support/support_providers.dart';

import '../../../mocks/fake_http_adapter.dart';
import '../../../mocks/test_clients.dart';

final class _FakePqrsRepository implements PqrsRepository {
  final List<({PqrsSubmission submission, String key})> calls = [];
  Future<Result<PqrsReceipt>> Function()? onSubmit;

  @override
  Future<Result<PqrsReceipt>> submit({
    required PqrsSubmission submission,
    required String idempotencyKey,
    RequestCancellation? cancel,
  }) {
    calls.add((submission: submission, key: idempotencyKey));
    return onSubmit?.call() ??
        Future.value(
          Ok(PqrsReceipt(status: 'received', receivedAt: DateTime.utc(2026))),
        );
  }
}

void main() {
  group('TC-129 · AC-096-2 · validación de campos PQRS', () {
    test('verifica límites exactos de nombre, correo, celular, pedido, mensaje y política', () {
      expect(PqrsValidation.isValidName('Ab'), isFalse);
      expect(PqrsValidation.isValidName('Ana'), isTrue);
      expect(PqrsValidation.isValidName('a' * 120), isTrue);
      expect(PqrsValidation.isValidName('a' * 121), isFalse);

      expect(PqrsValidation.isValidEmail('sin-arroba'), isFalse);
      expect(PqrsValidation.isValidEmail('${'a' * 249}@b.co'), isTrue);
      expect(PqrsValidation.isValidEmail('${'a' * 250}@b.co'), isFalse);

      expect(PqrsValidation.isValidPhone('123456'), isFalse);
      expect(PqrsValidation.isValidPhone('1234567'), isTrue);
      expect(PqrsValidation.isValidPhone('1' * 20), isTrue);
      expect(PqrsValidation.isValidPhone('1' * 21), isFalse);
      expect(PqrsValidation.isValidPhone('300abc1234'), isFalse);

      expect(PqrsValidation.isValidOrderReference('x' * 60), isTrue);
      expect(PqrsValidation.isValidOrderReference('x' * 61), isFalse);

      expect(PqrsValidation.isValidMessage(''), isFalse);
      expect(PqrsValidation.isValidMessage(' '), isFalse);
      expect(PqrsValidation.isValidMessage('a'), isTrue);
      expect(PqrsValidation.isValidMessage('a' * 1000), isTrue);
      expect(PqrsValidation.isValidMessage('a' * 1001), isFalse);

      final errors = PqrsValidation.validate(
        name: 'Ab',
        email: 'bad',
        phone: '123',
        orderReference: 'x' * 61,
        message: '',
        acceptsDataPolicy: false,
      );
      expect(errors.keys, containsAll(PqrsField.values));
    });

    test('AC-096-12 · PqrsSubmission.toString no imprime PII', () {
      const sub = PqrsSubmission(
        type: PqrsType.queja,
        name: 'Ana Prueba',
        email: 'ana@example.invalid',
        phone: '3000000001',
        message: 'Mensaje secreto',
        acceptsDataPolicy: true,
      );
      expect(sub.toString(), 'PqrsSubmission(type: queja)');
    });
  });

  group('TC-130 · AC-096-4/5/6 · datasource y PqrsController', () {
    test(
      'POST /pqrs envía Idempotency-Key sin Authorization y decodifica 202',
      () async {
        final adapter = FakeHttpAdapter()
          ..enqueue((req) {
            expect(req.headers['Idempotency-Key'], 'key-1');
            expect(req.headers.containsKey('Authorization'), isFalse);
            return FakeHttpAdapter.json({
              'data': {
                'status': 'received',
                'receivedAt': '2026-11-20T16:00:00Z',
              },
            }, status: 202);
          });
        final ds = PqrsRemoteDataSource(
          buildTestClient(adapter: adapter).client,
        );
        final res = await ds.submit(
          submission: const PqrsSubmission(
            type: PqrsType.peticion,
            name: 'Ana Prueba',
            email: 'ana@example.invalid',
            phone: '3000000001',
            message: 'Consulta de prueba.',
            acceptsDataPolicy: true,
          ),
          idempotencyKey: 'key-1',
        );
        expect(res, isA<Ok<PqrsReceipt>>());
        expect((res as Ok<PqrsReceipt>).value.status, 'received');
      },
    );

    test(
      'TC-130 · AC-096-5 · doble toque en curso emite una sola solicitud',
      () async {
        final repo = _FakePqrsRepository();
        final completer = Completer<Result<PqrsReceipt>>();
        repo.onSubmit = () => completer.future;

        var uuidCount = 0;
        final container = ProviderContainer(
          overrides: [
            pqrsRepositoryProvider.overrideWithValue(repo),
            supportUuidProvider.overrideWithValue(() => 'uuid-${++uuidCount}'),
          ],
        );
        addTearDown(container.dispose);

        final ctrl = container.read(pqrsControllerProvider.notifier);
        final first = ctrl.submit(
          type: PqrsType.peticion,
          name: 'Ana Prueba',
          email: 'ana@example.invalid',
          phone: '3000000001',
          orderReference: '',
          message: 'Mensaje válido de prueba.',
          acceptsDataPolicy: true,
        );
        final second = await ctrl.submit(
          type: PqrsType.peticion,
          name: 'Ana Prueba',
          email: 'ana@example.invalid',
          phone: '3000000001',
          orderReference: '',
          message: 'Mensaje válido de prueba.',
          acceptsDataPolicy: true,
        );
        expect(second, isFalse);
        expect(repo.calls, hasLength(1));

        completer.complete(
          Ok(PqrsReceipt(status: 'received', receivedAt: DateTime.utc(2026))),
        );
        expect(await first, isTrue);
        expect(container.read(pqrsControllerProvider).receipt, isNotNull);
      },
    );

    test('AC-096-7/8 · reintento tras 500 reutiliza Idempotency-Key', () async {
      final repo = _FakePqrsRepository()
        ..onSubmit = () async => const Err(ServerFailure());
      var uuidCount = 0;
      final container = ProviderContainer(
        overrides: [
          pqrsRepositoryProvider.overrideWithValue(repo),
          supportUuidProvider.overrideWithValue(() => 'uuid-${++uuidCount}'),
        ],
      );
      addTearDown(container.dispose);

      final ctrl = container.read(pqrsControllerProvider.notifier);
      await ctrl.submit(
        type: PqrsType.queja,
        name: 'Ana Prueba',
        email: 'ana@example.invalid',
        phone: '3000000001',
        orderReference: '',
        message: 'Fallo temporal',
        acceptsDataPolicy: true,
      );
      expect(repo.calls.last.key, 'uuid-1');

      repo.onSubmit = () async =>
          Ok(PqrsReceipt(status: 'received', receivedAt: DateTime.utc(2026)));
      await ctrl.submit(
        type: PqrsType.queja,
        name: 'Ana Prueba',
        email: 'ana@example.invalid',
        phone: '3000000001',
        orderReference: '',
        message: 'Fallo temporal',
        acceptsDataPolicy: true,
      );
      expect(repo.calls.last.key, 'uuid-1');
    });
  });
}
