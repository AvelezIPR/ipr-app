import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/app/router/app_router.dart';
import 'package:ipr_mobile/app/router/deep_link_policy.dart';
import 'package:ipr_mobile/app/router/routes.dart';
import 'package:ipr_mobile/core/session/session_state.dart';

void main() {
  const policy = DeepLinkPolicy(allowedHost: 'iprpartesyrepuestos.com');

  String? decideLocation(String url) => switch (policy.decide(Uri.parse(url))) {
    DeepLinkAccepted(:final location) => location,
    DeepLinkRejected() => null,
  };

  group('SC-067 · CR-001 · DeepLinkPolicy', () {
    test('acepta SOLO https en el host del flavor y la ruta /app/pedido', () {
      expect(
        decideLocation(
          'https://iprpartesyrepuestos.com/app/pedido?order=1234&status=paid',
        ),
        '/checkout/result?order=1234&status=paid',
      );
      expect(
        decideLocation('https://IPRPartesyRepuestos.com/app/pedido/'),
        '/checkout/result',
      );
      expect(
        decideLocation('/app/pedido?order=99'),
        '/checkout/result?order=99',
      );
    });

    test('rechaza otro host, otro esquema, credenciales y puertos', () {
      for (final url in [
        'https://evil.example.com/app/pedido',
        'https://iprpartesyrepuestos.com.evil.com/app/pedido',
        'http://iprpartesyrepuestos.com/app/pedido',
        'myapp://iprpartesyrepuestos.com/app/pedido',
        'https://user:pw@iprpartesyrepuestos.com/app/pedido',
        'https://iprpartesyrepuestos.com:8443/app/pedido',
      ]) {
        expect(decideLocation(url), isNull, reason: url);
      }
    });

    test(
      'nunca comodines: solo /app/pedido, no /app/* ni /pedido-confirmado',
      () {
        for (final url in [
          'https://iprpartesyrepuestos.com/app/otra',
          'https://iprpartesyrepuestos.com/app',
          'https://iprpartesyrepuestos.com/app/pedido/extra',
          'https://iprpartesyrepuestos.com/pedido-confirmado',
          'https://iprpartesyrepuestos.com/producto/x',
          'https://iprpartesyrepuestos.com/',
        ]) {
          expect(decideLocation(url), isNull, reason: url);
        }
      },
    );

    test('TC-078 · AC-055-4 · los parámetros son una pista y se validan', () {
      expect(
        decideLocation(
          'https://iprpartesyrepuestos.com/app/pedido?order=12ab&status=paid',
        ),
        '/checkout/result?status=paid',
        reason: 'order no numérico se descarta',
      );
      expect(
        decideLocation(
          'https://iprpartesyrepuestos.com/app/pedido?order=${'9' * 13}',
        ),
        '/checkout/result',
        reason: 'order demasiado largo se descarta',
      );
      expect(
        decideLocation(
          'https://iprpartesyrepuestos.com/app/pedido?status=hackeado&order=5',
        ),
        '/checkout/result?order=5',
        reason: 'status fuera del conjunto conocido se descarta',
      );
      expect(
        decideLocation(
          'https://iprpartesyrepuestos.com/app/pedido?next=https://evil.com',
        ),
        '/checkout/result',
        reason: 'parámetros desconocidos se ignoran (sin redirección abierta)',
      );
    });

    test('isDeepLink distingue enlaces externos del espacio /app', () {
      expect(policy.isDeepLink(Uri.parse('https://x.com/a')), isTrue);
      expect(policy.isDeepLink(Uri.parse('/app/pedido')), isTrue);
      expect(policy.isDeepLink(Uri.parse('/catalog')), isFalse);
    });
  });

  group('Routes', () {
    test('rutas protegidas', () {
      for (final p in [
        '/checkout',
        '/checkout/result',
        '/orders',
        '/orders/123',
        '/account/profile',
        '/account/addresses',
        '/account/delete',
      ]) {
        expect(Routes.isProtected(p), isTrue, reason: p);
      }
      for (final p in [
        '/',
        '/catalog',
        '/cart',
        '/account',
        '/login',
        '/search',
        '/orders-x',
        '/checkoutx',
      ]) {
        expect(Routes.isProtected(p), isFalse, reason: p);
      }
    });

    test(
      'safeInternal: solo rutas internas conocidas (sin redirección abierta)',
      () {
        expect(Routes.safeInternal('/orders/55'), '/orders/55');
        expect(Routes.safeInternal('/checkout?x=1'), '/checkout?x=1');
        expect(
          Routes.safeInternal('/product/mini-split'),
          '/product/mini-split',
        );
        for (final bad in <String?>[
          null,
          '',
          'https://evil.com',
          '//evil.com/x',
          r'/\evil.com',
          '/orders://evil',
          '/ruta-desconocida',
          'orders',
          'javascript:alert(1)',
          '/%zz',
        ]) {
          expect(Routes.safeInternal(bad), Routes.home, reason: '$bad');
        }
        expect(Routes.safeInternal('/'), Routes.home);
      },
    );
  });

  group('TC-029 · AC-037-3 · computeRedirect (guarda de sesión y actualización)', () {
    String? redirect(
      String url, {
      SessionState session = const SessionAnonymous(),
      bool updateRequired = false,
    }) => computeRedirect(
      uri: Uri.parse(url),
      deepLinks: policy,
      updateRequired: updateRequired,
      session: session,
    );

    test('ruta pública sin sesión: sin redirección', () {
      for (final url in [
        '/',
        '/catalog',
        '/cart',
        '/search?q=x',
        '/product/x',
        '/login',
      ]) {
        expect(redirect(url), isNull, reason: url);
      }
    });

    test(
      'ruta protegida sin sesión → /login?from=<ruta> conservando la consulta',
      () {
        expect(redirect('/orders'), '/login?from=%2Forders');
        expect(redirect('/checkout?x=1'), '/login?from=%2Fcheckout%3Fx%3D1');
        expect(
          redirect('/account/profile', session: const SessionExpired()),
          '/login?from=%2Faccount%2Fprofile',
        );
      },
    );

    test('mientras la sesión se lee del almacén no se redirige', () {
      expect(redirect('/orders', session: const SessionUnknown()), isNull);
    });

    test('con sesión las rutas protegidas se abren', () {
      expect(
        redirect('/orders', session: const SessionAuthenticated()),
        isNull,
      );
      expect(
        redirect('/checkout', session: const SessionAuthenticated()),
        isNull,
      );
    });

    test('login con sesión vuelve a "from" (si es segura) o a la cuenta', () {
      const authed = SessionAuthenticated();
      expect(
        redirect('/login?from=%2Forders%2F5', session: authed),
        '/orders/5',
      );
      expect(
        redirect('/login?from=https%3A%2F%2Fevil.com', session: authed),
        '/account',
      );
      expect(redirect('/login', session: authed), '/account');
      expect(redirect('/register', session: authed), '/account');
    });

    test('TC-077 · AC-055-6 · enlace de retorno sin sesión → login conservando el destino', () {
      expect(
        redirect('/app/pedido?order=12&status=paid'),
        '/checkout/result?order=12&status=paid',
        reason: 'el enlace se traduce a la ruta interna; la guarda actúa en el siguiente paso',
      );
      expect(
        redirect('/checkout/result?order=12&status=paid'),
        '/login?from=%2Fcheckout%2Fresult%3Forder%3D12%26status%3Dpaid',
      );
    });

    test('un enlace externo rechazado va a Inicio', () {
      expect(redirect('https://evil.com/app/pedido'), '/');
      expect(redirect('/app/otra'), '/');
    });

    test('actualización obligatoria: todo va a /update-required y se puede salir si ya no aplica', () {
      expect(redirect('/catalog', updateRequired: true), '/update-required');
      expect(redirect('/update-required', updateRequired: true), isNull);
      expect(redirect('/update-required'), '/');
    });
  });
}
