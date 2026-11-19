import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/network/api_request.dart';
import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';

import '../../../mocks/fake_http_adapter.dart';
import '../../../mocks/test_clients.dart';

void main() {
  group('M1 · RNF · RequestCancellation', () {
    test('cancel es idempotente y avisa una sola vez', () {
      final c = RequestCancellation();
      var calls = 0;
      c
        ..onCancel(() => calls++)
        ..cancel()
        ..cancel();
      expect(calls, 1);
      expect(c.isCancelled, isTrue);
    });

    test('un listener registrado tras cancelar se invoca de inmediato', () {
      final c = RequestCancellation()..cancel();
      var called = false;
      c.onCancel(() => called = true);
      expect(called, isTrue);
    });

    test('ApiClient aborta la petición cuando se cancela', () async {
      final adapter = FakeHttpAdapter();
      final harness = buildTestClient(adapter: adapter);
      final c = RequestCancellation()..cancel();
      final result = await harness.client.send(
        const ApiRequest.get('/categories'),
        cancellation: c,
      );
      expect(result, isA<Err<ApiResponse>>());
      expect(adapter.requests, isEmpty, reason: 'no llega a la red');
    });
  });
}
