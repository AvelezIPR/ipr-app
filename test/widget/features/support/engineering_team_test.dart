import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/config/engineering_team.dart';
import 'package:ipr_mobile/core/config/remote_config.dart';
import 'package:ipr_mobile/core/config/remote_config_controller.dart';
import 'package:ipr_mobile/core/config/remote_config_repository.dart'
    show RemoteConfigSource;
import 'package:ipr_mobile/features/support/support.dart';
import 'package:material_ui/material_ui.dart';

import '../../../mocks/pump_app.dart';
import '../../../mocks/test_providers.dart';

const _refri = EngineeringSpecialty(
  id: 'refrigeracion',
  name: 'Refrigeración Comercial e Industrial',
  whatsappMessage: 'Hola, quiero hablar con ingeniería en refrigeración',
  contacts: [
    EngineeringContact(
      id: 'refri-medellin',
      city: 'Medellín',
      email: 'ingenieriamedellin@example.invalid',
      whatsapp: '573011384281',
      phoneDisplay: '6043604440 ext. 1151',
      phoneDial: '6043604440',
    ),
    EngineeringContact(
      id: 'refri-cali',
      city: 'Cali',
      email: 'ingenieriacali@example.invalid',
    ),
  ],
);

const _aire = EngineeringSpecialty(
  id: 'aire',
  name: 'Aire Acondicionado y Ventilación',
  contacts: [
    EngineeringContact(
      id: 'aire-bogota',
      city: 'Bogotá',
      whatsapp: '573011384285',
    ),
  ],
);

Override _config(List<EngineeringSpecialty> specialties) =>
    remoteConfigProvider.overrideWithBuild(
      (ref, notifier) => RemoteConfigState(
        config: RemoteConfig(
          whatsappNumber: '573014021882',
          engineeringSpecialties: specialties,
        ),
        source: RemoteConfigSource.network,
      ),
    );

Future<void> _pump(
  WidgetTester tester,
  List<EngineeringSpecialty> specialties, {
  FakeExternalLauncher? launcher,
  double textScale = 1,
}) => pumpApp(
  tester,
  const EngineeringScreen(),
  textScale: textScale,
  size: const Size(360, 4000),
  overrides: testOverrides(launcher: launcher, extra: [_config(specialties)]),
);

void main() {
  group('W3-02 · ingenieros por ciudad', () {
    testWidgets('sin equipo del servidor no aparece la sección', (
      tester,
    ) async {
      await _pump(tester, const []);
      expect(find.text('Ingenieros por ciudad'), findsNothing);
    });

    testWidgets('muestra cada especialidad con sus ciudades', (tester) async {
      await _pump(tester, const [_refri, _aire]);
      expect(find.text('Ingenieros por ciudad'), findsOneWidget);
      expect(find.text('Refrigeración Comercial e Industrial'), findsOneWidget);
      expect(find.text('Aire Acondicionado y Ventilación'), findsOneWidget);
      expect(find.text('Medellín'), findsOneWidget);
      expect(find.text('Cali'), findsOneWidget);
      expect(find.text('Bogotá'), findsOneWidget);
    });

    testWidgets('cada contacto solo ofrece los canales que tiene', (
      tester,
    ) async {
      await _pump(tester, const [_refri, _aire]);
      // Medellín: WhatsApp, teléfono y correo. Cali: solo correo. Bogotá: solo WhatsApp.
      expect(find.text('6043604440 ext. 1151'), findsOneWidget);
      expect(find.text('Correo'), findsNWidgets(2));
      expect(find.text('WhatsApp'), findsNWidgets(2));
    });

    testWidgets(
      'WhatsApp abre el número de esa ciudad con el mensaje de la especialidad',
      (tester) async {
        final launcher = FakeExternalLauncher();
        await _pump(tester, const [_refri], launcher: launcher);
        await tester.tap(find.widgetWithText(OutlinedButton, 'WhatsApp').last);
        await tester.pump();
        final uri = launcher.opened.single;
        expect(uri.host, 'wa.me');
        expect(uri.path, '/573011384281');
        expect(
          uri.queryParameters['text'],
          'Hola, quiero hablar con ingeniería en refrigeración',
        );
      },
    );

    testWidgets('sin mensaje propio usa el general de ingeniería', (
      tester,
    ) async {
      final launcher = FakeExternalLauncher();
      await _pump(tester, const [_aire], launcher: launcher);
      await tester.tap(find.widgetWithText(OutlinedButton, 'WhatsApp').last);
      await tester.pump();
      expect(launcher.opened.single.path, '/573011384285');
      expect(launcher.opened.single.queryParameters['text'], isNotEmpty);
    });

    testWidgets('el teléfono marca el número base, sin la extensión', (
      tester,
    ) async {
      final launcher = FakeExternalLauncher();
      await _pump(tester, const [_refri], launcher: launcher);
      await tester.tap(find.text('6043604440 ext. 1151'));
      await tester.pump();
      expect(launcher.opened.single.scheme, 'tel');
      expect(launcher.opened.single.path, '6043604440');
    });

    testWidgets('el correo abre el cliente de correo de esa ciudad', (
      tester,
    ) async {
      final launcher = FakeExternalLauncher();
      await _pump(tester, const [_refri], launcher: launcher);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Correo').last);
      await tester.pump();
      expect(launcher.opened.single.scheme, 'mailto');
      expect(launcher.opened.single.path, 'ingenieriacali@example.invalid');
    });

    testWidgets('si el teléfono no se puede abrir, lo dice', (tester) async {
      final launcher = FakeExternalLauncher(result: false);
      await _pump(tester, const [_refri], launcher: launcher);
      await tester.tap(find.text('6043604440 ext. 1151'));
      await tester.pump();
      await tester.pump();
      expect(
        find.text('No pudimos abrir el marcador del teléfono.'),
        findsOneWidget,
      );
    });

    testWidgets('las etiquetas de accesibilidad incluyen la ciudad', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, const [_refri]);
      expect(
        find.bySemanticsLabel('WhatsApp de ingeniería en Medellín'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'Llamar a ingeniería en Medellín: 6043604440 ext. 1151',
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'Escribir a ingeniería en Cali: ingenieriacali@example.invalid',
        ),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('guías de objetivo táctil, etiquetas y contraste', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, const [_refri, _aire]);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });

    testWidgets('texto al 200 % sin desbordar', (tester) async {
      await _pump(tester, const [_refri, _aire], textScale: 2);
      expect(tester.takeException(), isNull);
    });
  });
}
