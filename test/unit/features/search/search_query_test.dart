import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/features/search/domain/entities/search_query.dart';

void main() {
  group('M1 · RF-020 · AC-020-3/4 · SearchQuery.normalize', () {
    test('recorta y colapsa espacios (AC-022-2)', () {
      expect(SearchQuery.normalize('  QA-0001  '), 'QA-0001');
      expect(
        SearchQuery.normalize('válvula   1/4\t\ttubo'),
        'válvula 1/4 tubo',
      );
    });

    test('vacío o solo espacios queda vacío (AC-020-3)', () {
      expect(SearchQuery.normalize(''), isEmpty);
      expect(SearchQuery.normalize('   \n\t '), isEmpty);
    });

    test('conserva signos especiales y tildes (se codifican al enviar)', () {
      const raw = '\' " < > % & # válvula';
      expect(SearchQuery.normalize(raw), raw);
    });

    test('quita etiquetas HTML y caracteres de control', () {
      expect(
        SearchQuery.normalize('<script>alert(1)</script>bomba'),
        'alert(1) bomba',
      );
      expect(SearchQuery.normalize('ab\u0000c\u0007d'), 'ab c d');
      expect(SearchQuery.normalize('<b>QA-1</b>'), 'QA-1');
    });

    test('limita a 120 caracteres sin partir un emoji', () {
      final long = 'a' * 300;
      expect(SearchQuery.normalize(long).length, SearchQuery.maxLength);
      final emoji = '${'a' * 119}😀resto';
      final out = SearchQuery.normalize(emoji);
      expect(out, 'a' * 119);
      expect(out.length, lessThanOrEqualTo(SearchQuery.maxLength));
    });

    test('isSuggestible exige 2 caracteres (contrato minLength: 2)', () {
      expect(SearchQuery.isSuggestible(''), isFalse);
      expect(SearchQuery.isSuggestible('a'), isFalse);
      expect(SearchQuery.isSuggestible('ab'), isTrue);
    });
  });

  group('RequestCancellation', () {
    test('cancel avisa una sola vez y es idempotente', () {
      final c = RequestCancellation();
      var calls = 0;
      c.onCancel(() => calls++);
      expect(c.isCancelled, isFalse);
      c
        ..cancel()
        ..cancel();
      expect(c.isCancelled, isTrue);
      expect(calls, 1);
    });

    test('un oyente tardío se invoca de inmediato', () {
      final c = RequestCancellation()..cancel();
      var called = false;
      c.onCancel(() => called = true);
      expect(called, isTrue);
    });
  });
}
