// Los fragmentos de HTML se concatenan a propósito, sin espacios.
// ignore_for_file: missing_whitespace_between_adjacent_strings

import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/external/media_host_policy.dart';
import 'package:ipr_mobile/features/product_detail/domain/rules/html_sanitizer.dart';

void main() {
  const policy = MediaHostPolicy(allowedHosts: {'media.ipr.test'});
  final sanitizer = HtmlSanitizer(isImageUrlAllowed: policy.isAllowed);

  String clean(String html) => sanitizer.sanitize(html);

  /// Propiedades que NINGUNA salida puede tener, cualquiera sea la entrada.
  void expectInert(String out, {bool allowTextRemnants = false}) {
    final lower = out.toLowerCase();
    for (final bad in [
      '<script',
      '<iframe',
      '<object',
      '<embed',
      '<form',
      '<input',
      '<style',
      '<svg',
      '<link',
      '<meta',
      'javascript:',
      'vbscript:',
      'data:text',
      if (!allowTextRemnants) 'alert(',
    ]) {
      expect(lower, isNot(contains(bad)), reason: 'salida: $out');
    }
    expect(
      RegExp(
        r'<[a-z0-9]+[^>]*\son[a-z]+\s*=',
        caseSensitive: false,
      ).hasMatch(out),
      isFalse,
      reason: 'atributo on* en: $out',
    );
    expect(
      RegExp(r'<[a-z0-9]+[^>]*\sstyle\s*=', caseSensitive: false).hasMatch(out),
      isFalse,
      reason: 'atributo style en: $out',
    );
  }

  group('AC-027-1 · TC-123 · corpus de payloads hostiles', () {
    const corpus = <String>[
      "<script>alert('x')</script>",
      '<SCRIPT SRC=https://evil.invalid/x.js></SCRIPT>',
      '<ScRiPt>alert(1)</sCrIpT>',
      '<script >alert(1)</script >',
      '<script\n>alert(1)</script\n>',
      '<scr<script>ipt>alert(1)</scr</script>ipt>',
      '<img src=x onerror=alert(1)>',
      '<img src="https://media.ipr.test/a.png" onerror="alert(1)">',
      '<img/src="https://media.ipr.test/a.png"/onload=alert(1)>',
      '<a href="javascript:alert(1)">x</a>',
      '<a href="JaVaScRiPt:alert(1)">x</a>',
      '<a href="  javascript:alert(1)">x</a>',
      '<a href="jav\tascript:alert(1)">x</a>',
      '<a href="jav&#x09;ascript:alert(1)">x</a>',
      '<a href="jav&#97;script:alert(1)">x</a>',
      '<a href="&#106;avascript:alert(1)">x</a>',
      '<a href="&#x6A;&#x61;&#x76;&#x61;script&colon;alert(1)">x</a>',
      '<a href="vbscript:msgbox(1)">x</a>',
      '<a href="data:text/html;base64,PHNjcmlwdD5hbGVydCgxKTwvc2NyaXB0Pg==">x</a>',
      '<a href=javascript:alert(1)>x</a>',
      '<iframe src="https://evil.invalid"></iframe>',
      '<iframe srcdoc="<script>alert(1)</script>"></iframe>',
      '<object data="javascript:alert(1)"></object>',
      '<embed src="https://evil.invalid/x.swf">',
      '<form action="https://evil.invalid"><input name=a><button>ok</button></form>',
      '<svg onload=alert(1)><circle/></svg>',
      '<svg><script>alert(1)</script></svg>',
      '<math><mi xlink:href="javascript:alert(1)">x</mi></math>',
      '<style>body{background:url(javascript:alert(1))}</style>',
      '<p style="background:url(javascript:alert(1))">x</p>',
      '<link rel=stylesheet href="https://evil.invalid/x.css">',
      '<meta http-equiv="refresh" content="0;url=https://evil.invalid">',
      '<base href="https://evil.invalid/">',
      '<body onload=alert(1)>',
      '<div onmouseover="alert(1)">x</div>',
      '<div onclick=alert(1)>x</div>',
      '<video><source onerror=alert(1)></video>',
      '<audio src=x onerror=alert(1)></audio>',
      '<details open ontoggle=alert(1)>',
      '<!--><script>alert(1)</script>-->',
      '<!-- <script>alert(1)</script> -->',
      '<![CDATA[<script>alert(1)</script>]]>',
      '<?xml version="1.0"?><script>alert(1)</script>',
      '<noscript><p title="</noscript><script>alert(1)</script>">',
      '<template><script>alert(1)</script></template>',
      '<textarea><script>alert(1)</script></textarea>',
      '<a href="https://evil.invalid" onclick="alert(1)">x</a>',
      "<a href='https://evil.invalid' ONCLICK='alert(1)'>x</a>",
      '<img src="data:image/svg+xml;base64,PHN2ZyBvbmxvYWQ9YWxlcnQoMSk+">',
      '<img srcset="https://evil.invalid/a.png 1x" src="https://media.ipr.test/a.png">',
      '<script',
      '<script>alert(1)',
      '<img src="https://media.ipr.test/a.png" onerror="alert(1)',
      '<a href="javascript:alert(1)',
    ];

    for (final payload in corpus) {
      test('inerte: ${payload.replaceAll('\n', r'\n')}', () {
        final remnants = payload.startsWith('<scr<script');
        expectInert(clean(payload), allowTextRemnants: remnants);
        expectInert(
          clean('<p>antes</p>$payload<p>después</p>'),
          allowTextRemnants: remnants,
        );
      });
    }

    test('el texto legítimo alrededor de un payload se conserva', () {
      final out = clean('<p>antes</p><script>alert(1)</script><p>después</p>');
      expect(out, '<p>antes</p><p>después</p>');
    });

    test('no se dispara solicitud alguna: sin src de hosts no permitidos', () {
      final out = clean(
        '<img src="https://evil.invalid/pixel.png">'
        '<img src="http://media.ipr.test/a.png">'
        '<img src="//media.ipr.test/a.png">'
        '<img src="data:image/png;base64,AAAA">'
        '<img src="file:///etc/passwd">'
        '<img src="https://user:pw@media.ipr.test/a.png">'
        '<img src="https://media.ipr.test:8443/a.png">'
        '<img src="https://media.ipr.test.evil.invalid/a.png">',
      );
      expect(out, isNot(contains('<img')));
    });
  });

  group('AC-027-3 / AC-027-4 · formato legítimo y recursos externos', () {
    test('conserva párrafos, listas, negritas y tablas', () {
      const html =
          '<p>Hola <strong>mundo</strong> <em>cursiva</em></p>'
          '<ul><li>uno</li><li>dos</li></ul>'
          '<table><thead><tr><th colspan="2">T</th></tr></thead>'
          '<tbody><tr><td>a</td><td rowspan="2">b</td></tr></tbody></table>';
      expect(clean(html), html);
    });

    test('imagen de host permitido y https se conserva', () {
      final out = clean(
        '<img src="https://media.ipr.test/a.png" alt="Foto" width="300" '
        'height="200">',
      );
      expect(out, contains('src="https://media.ipr.test/a.png"'));
      expect(out, contains('alt="Foto"'));
      expect(out, contains('width="300"'));
    });

    test('dimensiones no numéricas se descartan', () {
      final out = clean(
        '<img src="https://media.ipr.test/a.png" width="100%" height="1e9">',
      );
      expect(out, isNot(contains('width')));
      expect(out, isNot(contains('height')));
    });

    test(
      'enlaces: solo https; el resto pierde el href pero conserva el texto',
      () {
        expect(
          clean('<a href="https://ejemplo.invalid/x?a=1&b=2">ok</a>'),
          '<a href="https://ejemplo.invalid/x?a=1&amp;b=2">ok</a>',
        );
        for (final href in [
          'http://ejemplo.invalid',
          'mailto:a@b.invalid',
          'tel:+573000000000',
          'intent://scan#Intent;end',
          'file:///etc/passwd',
          '//ejemplo.invalid',
          '/ruta/relativa',
          'https://user:pw@ejemplo.invalid',
          'https:///sin-host',
        ]) {
          expect(
            clean('<a href="$href">texto</a>'),
            '<a>texto</a>',
            reason: href,
          );
        }
      },
    );

    test('atributos no permitidos se eliminan (class, id, style, target)', () {
      expect(
        clean(
          '<p class="x" id="y" style="color:red" data-a="b" target="_blank">t</p>',
        ),
        '<p>t</p>',
      );
    });

    test('los valores de atributo salen escapados', () {
      final out = clean(
        '<a href="https://a.invalid" title="a&quot; onx=&quot;b">t</a>',
      );
      expect(
        out,
        '<a href="https://a.invalid" title="a&quot; onx=&quot;b">t</a>',
      );
    });

    test('etiquetas desconocidas se quitan y se conserva el texto', () {
      expect(clean('<font color="red">hola</font><center>x</center>'), 'holax');
    });

    test('cierra las etiquetas abiertas y descarta cierres huérfanos', () {
      expect(clean('<p><b>negrita'), '<p><b>negrita</b></p>');
      expect(clean('</div>texto</p>'), 'texto');
    });

    test('un "<" suelto es texto, no una etiqueta', () {
      expect(clean('1 < 2 y a<3'), '1 &lt; 2 y a&lt;3');
    });

    test('la entrada se acota a maxLength', () {
      final big = HtmlSanitizer(
        isImageUrlAllowed: policy.isAllowed,
        maxLength: 20,
      );
      expect(big.sanitize('<p>${'a' * 100}</p>').length, lessThan(40));
    });

    test('anidación excesiva no desborda la pila', () {
      final out = clean('<div>' * 5000 + 'x');
      expect('<div>'.allMatches(out).length, lessThanOrEqualTo(64));
      expectInert(out);
    });
  });

  group('AC-027-5 · hasVisibleContent', () {
    test('vacío, solo etiquetas o espacios → false', () {
      expect(HtmlSanitizer.hasVisibleContent(''), isFalse);
      expect(
        HtmlSanitizer.hasVisibleContent('<p></p><p> &nbsp; </p>'),
        isFalse,
      );
      expect(HtmlSanitizer.hasVisibleContent('<div><br></div>'), isFalse);
    });

    test('texto o imagen → true', () {
      expect(HtmlSanitizer.hasVisibleContent('<p>hola</p>'), isTrue);
      expect(
        HtmlSanitizer.hasVisibleContent(
          '<img src="https://media.ipr.test/a.png">',
        ),
        isTrue,
      );
    });
  });
}
