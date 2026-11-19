import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/external/external_launcher.dart';
import 'package:ipr_mobile/core/external/external_url_policy.dart';
import 'package:ipr_mobile/core/external/screen_protection.dart';
import 'package:ipr_mobile/core/external/secure_browser.dart';

void main() {
  group('SC-036 · ExternalUrlPolicy (lista blanca cerrada)', () {
    const policy = ExternalUrlPolicy(
      extraHttpsHosts: {'iprpartesyrepuestos.com'},
    );

    test('permite https a hosts listados, tel, WhatsApp y mapas', () {
      for (final url in [
        'https://wa.me/573014021882?text=Hola',
        'https://api.whatsapp.com/send?phone=1',
        'https://maps.google.com/?q=6.2,-75.5',
        'https://www.google.com/maps/dir/?api=1',
        'https://maps.apple.com/?q=x',
        'https://iprpartesyrepuestos.com/legal',
        'tel:+576043604440',
        'tel:6043604440',
        'whatsapp://send?phone=573014021882',
        'geo:6.2,-75.5',
      ]) {
        expect(policy.isAllowed(Uri.parse(url)), isTrue, reason: url);
      }
    });

    test('bloquea intent, javascript, file, content, data, http y mailto', () {
      for (final url in [
        'intent://scan/#Intent;scheme=zxing;end',
        'javascript:alert(1)',
        'file:///etc/passwd',
        'content://com.android.contacts',
        'data:text/html,<script>',
        'http://wa.me/573014021882',
        'mailto:a@b.co',
        'sms:+57300',
        'ftp://wa.me/x',
      ]) {
        expect(policy.isAllowed(Uri.parse(url)), isFalse, reason: url);
      }
    });

    test('bloquea hosts no listados, credenciales, puertos y rutas de google no mapas', () {
      for (final url in [
        'https://evil.example.com/',
        'https://wa.me.evil.com/x',
        'https://user:pass@wa.me/x',
        'https://wa.me:8443/x',
        'https://www.google.com/search?q=x',
        'tel:+57abc',
        'tel:123',
        'whatsapp://other',
        'geo:abc',
      ]) {
        expect(policy.isAllowed(Uri.parse(url)), isFalse, reason: url);
      }
    });

    test('whatsAppUri codifica el texto y deja solo dígitos', () {
      final uri = whatsAppUri(
        '+57 301 402 1882',
        text: 'Hola, ¿precio de SKU 500-0144?',
      );
      expect(uri.host, 'wa.me');
      expect(uri.path, '/573014021882');
      expect(uri.queryParameters['text'], 'Hola, ¿precio de SKU 500-0144?');
      expect(policy.isAllowed(uri), isTrue);
      expect(whatsAppUri('573014021882').hasQuery, isFalse);
    });
  });

  group('CR-016 · CheckoutUrlPolicy: intersección local ∩ remota', () {
    const policy = CheckoutUrlPolicy(
      localHosts: {'iprpartesyrepuestos.com', 'pay.example.com'},
    );

    test('acepta solo hosts presentes en AMBAS listas', () {
      final remote = {'iprpartesyrepuestos.com', 'otro.example.com'};
      expect(
        policy.isAllowed(
          Uri.parse('https://iprpartesyrepuestos.com/?ipr_ticket=abc'),
          remoteHosts: remote,
        ),
        isTrue,
      );
      expect(
        policy.isAllowed(
          Uri.parse('https://pay.example.com/x'),
          remoteHosts: remote,
        ),
        isFalse,
        reason: 'solo en la lista local',
      );
      expect(
        policy.isAllowed(
          Uri.parse('https://otro.example.com/x'),
          remoteHosts: remote,
        ),
        isFalse,
        reason: 'un servidor comprometido no puede añadir hosts',
      );
    });

    test('exige https, sin credenciales, puerto 443 y host no vacío', () {
      final remote = {'iprpartesyrepuestos.com'};
      for (final url in [
        'http://iprpartesyrepuestos.com/',
        'https://u:p@iprpartesyrepuestos.com/',
        'https://iprpartesyrepuestos.com:8443/',
        'javascript:alert(1)',
        'https:///sin-host',
      ]) {
        expect(
          policy.isAllowed(Uri.parse(url), remoteHosts: remote),
          isFalse,
          reason: url,
        );
      }
    });

    test('compara sin distinguir mayúsculas', () {
      expect(
        policy.isAllowed(
          Uri.parse('https://IPRPartesyRepuestos.com/'),
          remoteHosts: {'IPRPARTESYREPUESTOS.COM'},
        ),
        isTrue,
      );
    });

    test('sin hosts remotos (config no cargada) nada es válido', () {
      expect(
        policy.isAllowed(
          Uri.parse('https://iprpartesyrepuestos.com/'),
          remoteHosts: const {},
        ),
        isFalse,
      );
    });
  });

  group('SC-035 · ScreenProtection', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    test('llama al canal nativo con enable y disable', () async {
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('co.ipr.app/screen_protection'),
            (call) async {
              calls.add(call.method);
              return null;
            },
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('co.ipr.app/screen_protection'),
              null,
            ),
      );
      const protection = MethodChannelScreenProtection();
      await protection.enable();
      await protection.disable();
      expect(calls, ['enable', 'disable']);
    });

    test('sin implementación nativa no lanza (pruebas, escritorio)', () async {
      const protection = MethodChannelScreenProtection();
      await protection.enable();
      await protection.disable();
    });

    test('un PlatformException nativo no bloquea la interfaz', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('co.ipr.app/screen_protection'),
            (call) async {
              throw PlatformException(code: 'x');
            },
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('co.ipr.app/screen_protection'),
              null,
            ),
      );
      await const MethodChannelScreenProtection().enable();
    });
  });
}
