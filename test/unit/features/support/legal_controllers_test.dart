import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/config/remote_config.dart';
import 'package:ipr_mobile/core/config/remote_config_controller.dart';
import 'package:ipr_mobile/core/config/remote_config_repository.dart'
    show RemoteConfigSource;
import 'package:ipr_mobile/features/support/domain/entities/legal_document.dart';
import 'package:ipr_mobile/features/support/domain/repositories/legal_opener.dart';
import 'package:ipr_mobile/features/support/presentation/controllers/legal_controllers.dart';
import 'package:ipr_mobile/features/support/support_providers.dart';

import '../../../mocks/fake_http_adapter.dart';
import '../../../mocks/test_providers.dart';
import 'support_fakes.dart';

final class _ScriptedOpener implements LegalOpener {
  new({this.gate, this.throws = false});

  final Future<void>? gate;
  final bool throws;
  int calls = 0;

  @override
  Future<LegalOpenResult> open(LegalDocument document) async {
    calls++;
    if (gate != null) await gate;
    if (throws) throw StateError('fallo inesperado');
    return LegalOpenResult.opened;
  }
}

const _doc = LegalDocument(
  kind: LegalDocumentKind.terms,
  url: 'https://x.test',
);

void main() {
  ProviderContainer make({
    FakeHttpAdapter? adapter,
    FakeExternalLauncher? launcher,
    LegalOpener? opener,
    bool withLegal = false,
  }) {
    final container = ProviderContainer(
      overrides: [
        ...supportOverrides(
          config: withLegal ? fullLegalConfig : const RemoteConfig(),
          adapter: adapter ?? FakeHttpAdapter(),
          launcher: launcher,
        ),
        if (opener != null) legalOpenerProvider.overrideWithValue(opener),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('M2 · RF-099 · LegalOpenController', () {
    test('devuelve el resultado del abridor', () async {
      final opener = _ScriptedOpener();
      final container = make(opener: opener);
      final result = await container
          .read(legalOpenControllerProvider.notifier)
          .open(_doc);
      expect(result, LegalOpenResult.opened);
      expect(container.read(legalOpenControllerProvider), isFalse);
    });

    test('una apertura en curso ignora la siguiente (null)', () async {
      final gate = Completer<void>();
      final opener = _ScriptedOpener(gate: gate.future);
      final container = make(opener: opener);
      final controller = container.read(legalOpenControllerProvider.notifier);

      final first = controller.open(_doc);
      expect(container.read(legalOpenControllerProvider), isTrue);
      expect(await controller.open(_doc), isNull);

      gate.complete();
      expect(await first, LegalOpenResult.opened);
      expect(opener.calls, 1);
    });

    test('una excepción del abridor se vuelve failed, no se propaga', () async {
      final container = make(opener: _ScriptedOpener(throws: true));
      expect(
        await container.read(legalOpenControllerProvider.notifier).open(_doc),
        LegalOpenResult.failed,
      );
      expect(container.read(legalOpenControllerProvider), isFalse);
    });

    test('openEmail intenta mailto: con el lanzador de core', () async {
      final launcher = FakeExternalLauncher();
      final container = make(launcher: launcher);
      final opened = await container
          .read(legalOpenControllerProvider.notifier)
          .openEmail('datos@staging.invalid');
      expect(opened, isTrue);
      expect(launcher.opened.single.toString(), 'mailto:datos@staging.invalid');
    });

    test(
      'openEmail devuelve false si la política/sistema no lo abre',
      () async {
        final container = make(launcher: FakeExternalLauncher(result: false));
        expect(
          await container
              .read(legalOpenControllerProvider.notifier)
              .openEmail('a@x.test'),
          isFalse,
        );
      },
    );
  });

  group('M2 · RF-099 · LegalRetryController (falla cerrado)', () {
    test('sin documentos, reintentar los obtiene de /config', () async {
      final adapter = FakeHttpAdapter([
        (_) => FakeHttpAdapter.json(configBody()),
      ]);
      final container = make(adapter: adapter);
      expect(container.read(legalDocumentsProvider), isEmpty);

      final found = await container
          .read(legalRetryControllerProvider.notifier)
          .retry();

      expect(found, isTrue);
      expect(container.read(legalDocumentsProvider), hasLength(3));
      expect(
        container.read(remoteConfigProvider).source,
        RemoteConfigSource.network,
      );
      expect(container.read(accountDeletionNoticeProvider), isNotNull);
      expect(container.read(legalRetryControllerProvider), isFalse);
    });

    test('si /config sigue sin documentos devuelve false', () async {
      final adapter = FakeHttpAdapter([
        (_) => FakeHttpAdapter.json(configBody(withLegal: false)),
      ]);
      final container = make(adapter: adapter);
      expect(
        await container.read(legalRetryControllerProvider.notifier).retry(),
        isFalse,
      );
      expect(container.read(legalDocumentsProvider), isEmpty);
    });

    test('un fallo de red conserva el estado vacío y no lanza', () async {
      final adapter = FakeHttpAdapter()
        ..fallback = (_) => FakeHttpAdapter.problem(503, 'service_unavailable');
      final container = make(adapter: adapter);
      expect(
        await container.read(legalRetryControllerProvider.notifier).retry(),
        isFalse,
      );
      expect(container.read(legalRetryControllerProvider), isFalse);
    });

    test('un fallo de red no borra los documentos que ya había', () async {
      final adapter = FakeHttpAdapter()
        ..fallback = (_) => FakeHttpAdapter.problem(503, 'service_unavailable');
      final container = make(adapter: adapter, withLegal: true);
      expect(
        await container.read(legalRetryControllerProvider.notifier).retry(),
        isTrue,
      );
      expect(container.read(legalDocumentsProvider), hasLength(3));
    });

    test('un reintento en curso ignora el siguiente', () async {
      final gate = Completer<void>();
      final adapter = FakeHttpAdapter([
        (_) async {
          await gate.future;
          return FakeHttpAdapter.json(configBody());
        },
      ]);
      final container = make(adapter: adapter);
      final controller = container.read(legalRetryControllerProvider.notifier);

      final first = controller.retry();
      await Future<void>.delayed(Duration.zero);
      expect(container.read(legalRetryControllerProvider), isTrue);
      expect(await controller.retry(), isFalse);

      gate.complete();
      expect(await first, isTrue);
      expect(adapter.requests, hasLength(1));
    });
  });
}
