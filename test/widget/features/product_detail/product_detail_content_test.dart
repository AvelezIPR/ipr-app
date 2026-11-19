// Los fragmentos de HTML se concatenan a propósito, sin espacios.
// ignore_for_file: missing_whitespace_between_adjacent_strings

import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/product_detail/presentation/widgets/product_description.dart';
import 'package:ipr_mobile/shared/widgets/product_image.dart';
import 'package:material_ui/material_ui.dart';

import 'product_detail_harness.dart';

const _okHost = 'https://staging.invalid/media';

Finder _richText(String text) => find.textContaining(text, findRichText: true);

void main() {
  group('AC-026-2 · AC-026-3 · RNF-072 · galería', () {
    testWidgets('indicador textual, botones y límites', (tester) async {
      await pumpProduct(
        tester,
        repository: repoWith('ProductDetail.priced.json'),
      );
      expect(find.text('Imagen 1 de 3'), findsOneWidget);

      final previous = iconButtonWith('Imagen anterior');
      final next = iconButtonWith('Imagen siguiente');
      expect(tester.widget<IconButton>(previous).onPressed, isNull);
      expect(tester.widget<IconButton>(next).onPressed, isNotNull);

      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(find.text('Imagen 2 de 3'), findsOneWidget);
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(find.text('Imagen 3 de 3'), findsOneWidget);
      expect(tester.widget<IconButton>(next).onPressed, isNull);

      await tester.tap(previous);
      await tester.pumpAndSettle();
      expect(find.text('Imagen 2 de 3'), findsOneWidget);
    });

    testWidgets('los botones miden al menos 48 dp', (tester) async {
      await pumpProduct(
        tester,
        repository: repoWith('ProductDetail.priced.json'),
      );
      for (final tooltip in ['Imagen anterior', 'Imagen siguiente']) {
        final size = tester.getSize(find.byTooltip(tooltip));
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
    });

    testWidgets('deslizar horizontalmente cambia de imagen', (tester) async {
      await pumpProduct(
        tester,
        repository: repoWith('ProductDetail.priced.json'),
      );
      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(find.text('Imagen 2 de 3'), findsOneWidget);
    });

    testWidgets('con movimiento reducido cambia sin animar', (tester) async {
      await pumpProduct(
        tester,
        repository: repoWith('ProductDetail.priced.json'),
      );
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Imagen siguiente'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Imagen 2 de 3'), findsOneWidget);
    });

    testWidgets('una sola imagen: sin botones ni indicador', (tester) async {
      await pumpProduct(
        tester,
        repository: repoWith('ProductDetail.out-of-stock.json'),
      );
      expect(find.byTooltip('Imagen siguiente'), findsNothing);
      expect(find.textContaining('Imagen 1 de'), findsNothing);
      expect(find.byType(ProductImage), findsOneWidget);
    });

    testWidgets('sin imágenes: marcador de posición, sin error', (
      tester,
    ) async {
      await pumpProduct(
        tester,
        repository: repoWith('ProductDetail.on-request.json'),
      );
      expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
      expect(find.byTooltip('Imagen siguiente'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('SC-043 · imágenes de hosts no permitidos nunca se piden', (
      tester,
    ) async {
      await pumpProduct(
        tester,
        repository: FakeProductDetailRepository([
          Ok(
            ProductDetailLoad(
              product: customProduct(
                galleryUrls: [
                  'https://evil.invalid/a.png',
                  'http://staging.invalid/b.png',
                  'https://staging.invalid.evil.invalid/c.png',
                ],
              ),
            ),
          ),
        ]),
      );
      expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
      expect(find.byTooltip('Imagen siguiente'), findsNothing);
    });

    testWidgets('solo cuentan las imágenes permitidas en el indicador', (
      tester,
    ) async {
      await pumpProduct(
        tester,
        repository: FakeProductDetailRepository([
          Ok(
            ProductDetailLoad(
              product: customProduct(
                galleryUrls: [
                  '$_okHost/1.jpg',
                  'https://evil.invalid/x.png',
                  '$_okHost/2.jpg',
                ],
              ),
            ),
          ),
        ]),
      );
      expect(find.text('Imagen 1 de 2'), findsOneWidget);
    });

    testWidgets('sin galería usa la imagen principal del resumen', (
      tester,
    ) async {
      await pumpProduct(
        tester,
        repository: FakeProductDetailRepository([
          Ok(
            ProductDetailLoad(
              product: fixtureProduct('ProductDetail.out-of-stock.json'),
            ),
          ),
        ]),
      );
      expect(find.byType(ProductImage), findsOneWidget);
    });

    testWidgets('tocar la imagen abre pantalla completa con cierre explícito', (
      tester,
    ) async {
      await pumpProduct(
        tester,
        repository: repoWith('ProductDetail.priced.json'),
      );
      await tester.tap(find.byType(PageView));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Cerrar galería'), findsOneWidget);
      expect(find.text('Imagen 1 de 3'), findsWidgets);

      await tester.drag(find.byType(PageView).last, const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(find.text('Imagen 2 de 3'), findsWidgets);

      await tester.tap(find.byTooltip('Cerrar galería'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Cerrar galería'), findsNothing);
      expect(find.text('Compresor scroll 24.000 BTU R410A'), findsOneWidget);
    });
  });

  group('AC-027-3 · AC-027-5 · AC-027-6 · descripción', () {
    testWidgets('corta y larga en secciones distintas, formato conservado', (
      tester,
    ) async {
      await pumpProduct(
        tester,
        repository: repoWith('ProductDetail.priced.json'),
      );
      expect(
        find.text(
          'Compresor scroll hermético para aire acondicionado residencial.',
        ),
        findsOneWidget,
      );
      expect(find.text('Descripción'), findsOneWidget);
      expect(_richText('Compresor scroll de alta eficiencia.'), findsOneWidget);
      expect(_richText('Refrigerante R410A'), findsOneWidget);
      expect(_richText('Voltaje 220 V'), findsOneWidget);
    });

    testWidgets(
      'sin descripción ni atributos: secciones omitidas, sin encabezados',
      (tester) async {
        await pumpProduct(
          tester,
          repository: repoWith('ProductDetail.on-request.json'),
        );
        expect(find.text('Descripción'), findsNothing);
        expect(find.text('Especificaciones'), findsNothing);
      },
    );

    testWidgets('solo descripción corta: no deja el encabezado de la larga', (
      tester,
    ) async {
      await pumpProduct(
        tester,
        repository: FakeProductDetailRepository([
          Ok(
            ProductDetailLoad(
              product: customProduct(
                shortDescription: 'Solo corta',
                descriptionHtml: '<p> </p><div><br></div>',
              ),
            ),
          ),
        ]),
      );
      expect(find.text('Solo corta'), findsOneWidget);
      expect(find.text('Descripción'), findsNothing);
    });
  });

  group('AC-027-1/-2/-4 · TC-123 · descripción hostil', () {
    testWidgets(
      'no renderiza scripts, formularios, iframes ni imágenes ajenas',
      (tester) async {
        await pumpProduct(
          tester,
          repository: repoWith('ProductDetail.malicious-html.json'),
        );
        expect(_richText('Texto legítimo'), findsOneWidget);
        expect(_richText('enlace malo'), findsOneWidget);
        for (final leaked in ['xss1', 'xss2', 'xss3', 'evil.invalid']) {
          expect(
            _richText(leaked),
            findsNothing,
            reason: '"$leaked" no debe aparecer en pantalla',
          );
          expect(find.textContaining(leaked), findsNothing);
        }
        expect(
          find.byType(Image),
          findsNothing,
          reason: 'ninguna imagen ajena',
        );
        expect(find.byType(TextField), findsNothing, reason: 'sin formulario');
      },
    );

    testWidgets('un enlace javascript: no activa nada', (tester) async {
      final launcher = FakeExternalLauncher();
      await pumpProduct(
        tester,
        repository: repoWith('ProductDetail.malicious-html.json'),
        launcher: launcher,
      );
      final finder = find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains('enlace malo'),
      );
      var hasRecognizer = false;
      tester.widget<RichText>(finder.first).text.visitChildren((span) {
        if (span is TextSpan && span.recognizer != null) hasRecognizer = true;
        return true;
      });
      expect(hasRecognizer, isFalse, reason: 'el texto quedó sin enlace');
      expect(launcher.opened, isEmpty);
    });

    testWidgets('AC-028-3 · el marcado en un atributo se ve como texto', (
      tester,
    ) async {
      await pumpProduct(
        tester,
        repository: repoWith('ProductDetail.malicious-html.json'),
      );
      expect(find.text('Especificaciones'), findsOneWidget);
      expect(find.text('Nota'), findsOneWidget);
      expect(
        find.text('<b>negrita</b>, <script>alert(1)</script>'),
        findsOneWidget,
        reason: 'se muestra literal, sin interpretarse',
      );
    });

    testWidgets('imágenes del HTML de hosts no permitidos no se cargan', (
      tester,
    ) async {
      await pumpProduct(
        tester,
        repository: FakeProductDetailRepository([
          Ok(
            ProductDetailLoad(
              product: customProduct(
                descriptionHtml:
                    '<p>Foto:</p><img src="https://evil.invalid/p.png" alt="x">'
                    '<img src="http://staging.invalid/p.png">'
                    '<img src="data:image/png;base64,AAAA">'
                    '<p style="background-image:url(https://evil.invalid/b.png)">fin</p>',
              ),
            ),
          ),
        ]),
      );
      expect(_richText('Foto:'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).image != null,
        ),
        findsNothing,
      );
    });
  });

  group('AC-027-4 · enlaces con ExternalLauncher, nunca webview', () {
    testWidgets('un enlace https se abre con el lanzador externo', (
      tester,
    ) async {
      final launcher = FakeExternalLauncher();
      await pumpProduct(
        tester,
        repository: repoWith('ProductDetail.priced.json'),
        launcher: launcher,
      );
      tapHtmlLink(tester, 'la ficha técnica');
      await tester.pump();
      expect(
        launcher.opened.single.toString(),
        'https://staging.invalid/ficha-tecnica',
      );
    });

    testWidgets('si el lanzador lo rechaza, avisa sin romper', (tester) async {
      final launcher = FakeExternalLauncher(result: false);
      await pumpProduct(
        tester,
        repository: repoWith('ProductDetail.priced.json'),
        launcher: launcher,
      );
      tapHtmlLink(tester, 'la ficha técnica');
      await tester.pump();
      await tester.pump();
      expect(find.text('No se pudo abrir el enlace.'), findsOneWidget);
    });

    test(
      'openDescriptionLink solo acepta https y respeta al lanzador',
      () async {
        final launcher = FakeExternalLauncher();
        expect(
          await openDescriptionLink(launcher, 'https://a.invalid/x'),
          isTrue,
        );
        expect(launcher.opened, hasLength(1));
        for (final bad in [
          'http://a.invalid',
          'javascript:alert(1)',
          'intent://x#Intent;end',
          'file:///etc/passwd',
          'mailto:a@b.invalid',
          '/relativa',
          '',
          '::::',
        ]) {
          expect(
            await openDescriptionLink(launcher, bad),
            isFalse,
            reason: bad,
          );
        }
        expect(
          launcher.opened,
          hasLength(1),
          reason: 'nada más llegó al lanzador',
        );
        launcher.result = false;
        expect(
          await openDescriptionLink(launcher, 'https://a.invalid/y'),
          isFalse,
        );
      },
    );
  });

  group('AC-028-1/-2 · atributos técnicos', () {
    testWidgets('pares nombre-valor tal como los entrega el servidor', (
      tester,
    ) async {
      await pumpProduct(
        tester,
        repository: repoWith('ProductDetail.priced.json'),
      );
      expect(find.text('Especificaciones'), findsOneWidget);
      expect(find.text('Capacidad'), findsOneWidget);
      expect(find.text('24.000 BTU'), findsOneWidget);
      expect(find.text('Refrigerante'), findsOneWidget);
      expect(find.text('R410A, R32'), findsOneWidget);
    });
  });
}
