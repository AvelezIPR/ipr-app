import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/config/remote_config.dart';
import 'package:ipr_mobile/core/config/remote_config_controller.dart';
import 'package:ipr_mobile/core/config/remote_config_repository.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/home/domain/entities/section_data.dart';
import 'package:ipr_mobile/features/home/home.dart';
import 'package:material_ui/material_ui.dart';

import '../../../unit/features/home/home_test_support.dart';
import 'home_harness.dart';

FakeHomeRepository _emptyHome() => FakeHomeRepository(
  categoryResults: [const Ok(SectionData([]))],
  brandResults: [const Ok(SectionData([]))],
  featuredResults: [const Ok(SectionData([]))],
);

void main() {
  group(
    'M5 · barra superior (Ayuda + Carrito) y calculadora BTU en Inicio',
    () {
      testWidgets(
        'H1-03 · barra superior muestra insignia del carrito y navega a Ayuda y Carrito',
        (tester) async {
          await pumpHome(
            tester,
            repository: _emptyHome(),
            extra: [homeCartCountProvider.overrideWithValue(3)],
          );
          expect(find.text('3'), findsOneWidget);

          await tester.tap(find.byTooltip('Ayuda y contacto'));
          await tester.pumpAndSettle();
          expect(destinationOf(tester), '/support');
        },
      );

      testWidgets('H1-03 · botón Carrito superior lleva a /cart', (
        tester,
      ) async {
        await pumpHome(
          tester,
          repository: _emptyHome(),
          extra: [homeCartCountProvider.overrideWithValue(105)],
        );
        expect(find.text('99+'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.shopping_cart_outlined));
        await tester.pumpAndSettle();
        expect(destinationOf(tester), '/cart');
      });

      testWidgets(
        'TC-142 · AC-006-2 · calculadora oculta cuando btuCalculatorEnabled es false',
        (tester) async {
          await pumpHome(tester, repository: _emptyHome());
          expect(find.text('Calculadora de BTU'), findsNothing);
        },
      );

      testWidgets(
        'TC-142 · AC-006-1 · calculadora visible cuando btuCalculatorEnabled es true y navega',
        (tester) async {
          await pumpHome(
            tester,
            repository: _emptyHome(),
            extra: [
              remoteConfigProvider.overrideWithBuild(
                (_, _) => const RemoteConfigState(
                  config: RemoteConfig(btuCalculatorEnabled: true),
                  source: RemoteConfigSource.network,
                ),
              ),
            ],
          );
          final tile = find.text('Calculadora de BTU');
          await tester.scrollUntilVisible(
            tile,
            250,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.drag(find.byType(ListView), const Offset(0, -120));
          await tester.pumpAndSettle();
          expect(tile, findsOneWidget);
          await tester.tap(tile);
          await tester.pumpAndSettle();
          expect(destinationOf(tester), '/tools/btu');
        },
      );
    },
  );
}
