import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/config/app_config.dart';
import 'package:ipr_mobile/core/observability/analytics_sink.dart';
import 'package:ipr_mobile/core/observability/app_logger.dart';
import 'package:ipr_mobile/core/observability/crash_reporter.dart';
import 'package:ipr_mobile/core/observability/pii_scrubber.dart';

final class _Recording implements CrashReporter {
  final errors = <String>[];
  final stacks = <String?>[];
  final logs = <String>[];

  @override
  Future<void> log(String message) async => logs.add(message);

  @override
  Future<void> recordError(
    String message, {
    String? stackTrace,
    bool fatal = false,
  }) async {
    errors.add(message);
    stacks.add(stackTrace);
  }
}

final class _Throwing implements CrashReporter {
  @override
  Future<void> log(String message) async => throw StateError('x');

  @override
  Future<void> recordError(
    String message, {
    String? stackTrace,
    bool fatal = false,
  }) async => throw StateError('x');
}

void main() {
  const scrubber = PiiScrubber();

  group('SC-044 · PiiScrubber', () {
    test('elimina tokens de la app, Bearer y JWT', () {
      final out = scrubber.scrub(
        'fallo con ipra_AbC123-_xyz y iprr_QwErTy y Authorization: Bearer abc.def-ghi '
        'y eyJhbGciOi.eyJzdWIiOi.firma',
      );
      expect(out, isNot(contains('AbC123')));
      expect(out, isNot(contains('QwErTy')));
      expect(out, isNot(contains('abc.def-ghi')));
      expect(out, isNot(contains('eyJhbGciOi')));
      expect(out, contains('<token>'));
    });

    test('elimina correos y teléfonos', () {
      final out = scrubber.scrub(
        'usuario ana.perez@example.com cel +57 301 402 1882 doc 1.020.304.050',
      );
      expect(out, isNot(contains('ana.perez')));
      expect(out, isNot(contains('402 1882')));
      expect(out, isNot(contains('1.020.304')));
      expect(out, contains('<email>'));
      expect(out, contains('<number>'));
    });

    test('elimina la consulta de las URL (términos de búsqueda, tokens)', () {
      final out = scrubber.scrub(
        'GET https://x.com/search?q=compresor&token=abc123 falló',
      );
      expect(out, isNot(contains('compresor')));
      expect(out, isNot(contains('abc123')));
      expect(out, contains('?<query>'));
    });

    test('deja intacto el texto sin datos sensibles', () {
      expect(
        scrubber.scrub('NoSuchMethodError en CartController'),
        'NoSuchMethodError en CartController',
      );
    });

    test(
      'ScrubbingCrashReporter nunca entrega PII ni tokens al proveedor',
      () async {
        final inner = _Recording();
        final reporter = ScrubbingCrashReporter(inner);
        await reporter.recordError(
          StateError('falló para ana@example.com con ipra_secreto123'),
          StackTrace.fromString('#0 f (https://x.com/a?token=zzz)'),
          fatal: true,
        );
        await reporter.log('migas: ipra_otro y 3014021882');
        expect(inner.errors.single, isNot(contains('ana@example.com')));
        expect(inner.errors.single, isNot(contains('secreto123')));
        expect(inner.stacks.single, isNot(contains('zzz')));
        expect(inner.logs.single, isNot(contains('ipra_otro')));
        expect(inner.logs.single, isNot(contains('3014021882')));
      },
    );

    test(
      'un reporte sin pila y un proveedor que falla no tumban la app',
      () async {
        await ScrubbingCrashReporter(_Recording())
            .recordError(StateError('x'), null);
        final failing = ScrubbingCrashReporter(_Throwing());
        await failing.recordError(StateError('x'), StackTrace.current);
        await failing.log('x');
      },
    );

    test('NoOp y analítica por defecto no hacen nada (DN-02, PA-08)', () async {
      await const NoOpCrashReporter().recordError('x');
      await const NoOpCrashReporter().log('x');
      await const NoOpAnalyticsSink().track('evento', parameters: {'a': 'b'});
    });

    test('el marcador de falla cerrada no contiene el texto original', () {
      expect(PiiScrubber.redacted, isNot(contains('secreto')));
    });
  });

  group('SC-045 · AppLogger', () {
    test('desactivado en prod, activo en dev y staging', () {
      expect(AppLogger.forEnvironment(AppEnvironment.prod).enabled, isFalse);
      expect(AppLogger.forEnvironment(AppEnvironment.dev).enabled, isTrue);
      expect(AppLogger.forEnvironment(AppEnvironment.staging).enabled, isTrue);
      const AppLogger(enabled: false).debug('no se registra');
      const AppLogger(enabled: true).debug('se registra');
    });
  });
}
