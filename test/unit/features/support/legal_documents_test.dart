import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/config/remote_config.dart';
import 'package:ipr_mobile/core/external/external_url_policy.dart';
import 'package:ipr_mobile/features/support/data/mappers/legal_documents_mapper.dart';
import 'package:ipr_mobile/features/support/data/repositories/secure_browser_legal_opener.dart';
import 'package:ipr_mobile/features/support/domain/entities/legal_document.dart';

import 'support_fakes.dart';

void main() {
  group('M2 · RF-099 · documentos legales desde /config', () {
    test('sin nada publicado la lista queda vacía (falla cerrado)', () {
      expect(legalDocumentsFromConfig(const RemoteConfig()), isEmpty);
    });

    test('cadenas vacías o en blanco cuentan como no publicadas', () {
      const config = RemoteConfig(
        termsVersion: '  ',
        termsUrl: '',
        privacyPolicyVersion: '',
        privacyPolicyUrl: '   ',
        dataRightsUrl: '',
        dataRightsEmail: ' ',
        accountDeletionNotice: '  ',
      );
      expect(legalDocumentsFromConfig(config), isEmpty);
      expect(accountDeletionNoticeFromConfig(config), isNull);
    });

    test('lista términos, política y derechos con versión, URL y correo', () {
      final docs = legalDocumentsFromConfig(fullLegalConfig);
      expect(docs.map((d) => d.kind), [
        LegalDocumentKind.terms,
        LegalDocumentKind.privacy,
        LegalDocumentKind.dataRights,
      ]);
      expect(docs[0].version, '2026-01');
      expect(docs[0].url, 'https://$legalHost/terminos');
      expect(docs[1].version, '2026-02');
      expect(docs[2].email, 'datos@$legalHost');
      expect(docs[2].url, isNull);
    });

    test('un documento con solo versión se lista (sin URL: no se abrirá)', () {
      final docs = legalDocumentsFromConfig(
        const RemoteConfig(termsVersion: ' 7 '),
      );
      expect(docs, hasLength(1));
      expect(docs.single.version, '7', reason: 'recortado');
      expect(docs.single.url, isNull);
    });

    test('derechos del titular: solo URL o solo correo bastan', () {
      expect(
        legalDocumentsFromConfig(
          const RemoteConfig(dataRightsUrl: 'https://x.test/d'),
        ).single.kind,
        LegalDocumentKind.dataRights,
      );
      expect(
        legalDocumentsFromConfig(
          const RemoteConfig(dataRightsEmail: 'a@x.test'),
        ).single.email,
        'a@x.test',
      );
    });

    test('el aviso de eliminación se recorta y se conserva como texto', () {
      expect(
        accountDeletionNoticeFromConfig(
          const RemoteConfig(accountDeletionNotice: ' <b>aviso</b> '),
        ),
        '<b>aviso</b>',
        reason: 'se muestra como texto plano, sin interpretarlo',
      );
    });
  });

  group('AC-099-7 · SC-036 · SecureBrowserLegalOpener', () {
    late FakeSecureBrowser browser;
    late SecureBrowserLegalOpener opener;

    setUp(() {
      browser = FakeSecureBrowser();
      opener = SecureBrowserLegalOpener(
        browser: browser,
        policy: const ExternalUrlPolicy(extraHttpsHosts: {legalHost}),
      );
    });

    LegalDocument doc(String? url) =>
        LegalDocument(kind: LegalDocumentKind.terms, url: url);

    test('https de un host permitido se abre en el navegador seguro', () async {
      final result = await opener.open(doc('https://$legalHost/terminos'));
      expect(result, LegalOpenResult.opened);
      expect(browser.opened.single.toString(), 'https://$legalHost/terminos');
    });

    test('el navegador que no puede abrir devuelve failed', () async {
      browser.result = false;
      expect(
        await opener.open(doc('https://$legalHost/t')),
        LegalOpenResult.failed,
      );
    });

    for (final url in [
      null,
      '',
      'terminos',
      'https://',
      'javascript:alert(1)',
      'file:///etc/passwd',
      'tel:+576043604440',
    ]) {
      test(
        'URL ausente o inválida ($url) → unavailable, no abre nada',
        () async {
          expect(await opener.open(doc(url)), LegalOpenResult.unavailable);
          expect(browser.opened, isEmpty);
        },
      );
    }

    for (final url in [
      'http://$legalHost/terminos',
      'https://evil.example/terminos',
      'https://user:pass@$legalHost/terminos',
      'https://$legalHost:8443/terminos',
      'whatsapp://send?phone=1',
      'intent://scan/#Intent;scheme=zxing;end',
      'content://x/y',
    ]) {
      test('no permitida por la política ($url) → blocked', () async {
        expect(await opener.open(doc(url)), LegalOpenResult.blocked);
        expect(browser.opened, isEmpty);
      });
    }

    test('la comparación del host no distingue mayúsculas', () async {
      expect(
        await opener.open(doc('https://STAGING.invalid/terminos')),
        LegalOpenResult.opened,
      );
    });
  });
}
