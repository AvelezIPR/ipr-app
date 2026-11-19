import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/external/screen_protection.dart';
import 'package:ipr_mobile/shared/domain/money.dart';
import 'package:ipr_mobile/shared/domain/price_status.dart';
import 'package:ipr_mobile/shared/domain/stock_status.dart';
import 'package:ipr_mobile/shared/widgets/price_widgets.dart';
import 'package:ipr_mobile/shared/widgets/sensitive_screen.dart';
import 'package:ipr_mobile/shared/widgets/state_widgets.dart';
import 'package:ipr_mobile/shared/widgets/ui_state.dart';
import 'package:material_ui/material_ui.dart';

import '../mocks/pump_app.dart';

final class _SpyProtection implements ScreenProtection {
  int enabled = 0;
  int disabled = 0;
  @override
  Future<void> enable() async => enabled++;
  @override
  Future<void> disable() async => disabled++;
}

void main() {
  group('TC-052 · AC-012-1 · PriceText', () {
    testWidgets('con precio: formato COP, IVA incluido y etiqueta semántica', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, const PriceText(price: Priced(Money(1445000))));
      expect(find.text(r'$ 1.445.000'), findsOneWidget);
      expect(find.text('IVA incluido'), findsOneWidget);
      expect(
        find.bySemanticsLabel('1.445.000 pesos, IVA incluido'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets(r'sin precio: "Más información" y JAMÁS "$0"', (tester) async {
      await pumpApp(tester, const PriceText(price: OnRequest()));
      expect(find.text('Más información'), findsOneWidget);
      expect(find.textContaining(r'$'), findsNothing);
      expect(find.textContaining('0'), findsNothing);
    });
  });

  group('StockBadge · texto + ícono, nunca solo color (RNF-076)', () {
    for (final entry in {
      StockStatus.inStock: ('En stock', Icons.check_circle_outline),
      StockStatus.outOfStock: ('Agotado', Icons.cancel_outlined),
      StockStatus.onBackorder: ('Bajo pedido', Icons.schedule),
      StockStatus.unknown: ('Disponibilidad por confirmar', Icons.help_outline),
    }.entries) {
      testWidgets('${entry.key.name}: ${entry.value.$1}', (tester) async {
        await pumpApp(tester, StockBadge(stock: entry.key));
        expect(find.text(entry.value.$1), findsOneWidget);
        expect(find.byIcon(entry.value.$2), findsOneWidget);
      });
    }
  });

  group('TC-103 · RNF-022/027 · estados de UI', () {
    testWidgets(
      'ErrorState: mensaje es-CO y "Reintentar" solo si es reintentable',
      (tester) async {
        var retried = 0;
        await pumpApp(
          tester,
          ErrorState(failure: const NoConnection(), onRetry: () => retried++),
        );
        expect(
          find.text('No tienes conexión. Revisa tu internet.'),
          findsOneWidget,
        );
        await tester.tap(find.text('Reintentar'));
        expect(retried, 1);
      },
    );

    testWidgets('ErrorState: un 404 NO ofrece reintentar', (tester) async {
      await pumpApp(
        tester,
        ErrorState(failure: const NotFound(), onRetry: () {}),
      );
      expect(
        find.text('Este contenido ya no está disponible.'),
        findsOneWidget,
      );
      expect(find.text('Reintentar'), findsNothing);
    });

    testWidgets('un fallo de red nunca se presenta como "sin resultados"', (
      tester,
    ) async {
      await pumpApp(
        tester,
        AsyncView<List<int>>(
          state: const UiFailure(NoConnection()),
          builder: (_, v) => Text('$v'),
        ),
      );
      expect(find.text('No hay resultados'), findsNothing);
      expect(find.byType(ErrorState), findsOneWidget);
    });

    testWidgets('AsyncView: cargando, vacío y datos con aviso de obsoleto', (
      tester,
    ) async {
      await pumpApp(
        tester,
        AsyncView<String>(state: const UiLoading(), builder: (_, v) => Text(v)),
      );
      expect(find.byType(LoadingState), findsOneWidget);

      await pumpApp(
        tester,
        AsyncView<String>(state: const UiEmpty(), builder: (_, v) => Text(v)),
      );
      expect(find.text('No hay resultados'), findsOneWidget);

      await pumpApp(
        tester,
        AsyncView<String>(
          state: const UiData('hola', stale: true),
          builder: (_, v) => Text(v),
        ),
      );
      expect(find.text('hola'), findsOneWidget);
      expect(find.byType(StaleBanner), findsOneWidget);
      expect(
        find.text(
          'Mostrando información guardada; puede no estar actualizada.',
        ),
        findsOneWidget,
      );

      await pumpApp(
        tester,
        AsyncView<String>(
          state: const UiData('fresco'),
          builder: (_, v) => Text(v),
        ),
      );
      expect(find.byType(StaleBanner), findsNothing);
    });

    testWidgets('EmptyState admite acción propia (p. ej. WhatsApp)', (
      tester,
    ) async {
      await pumpApp(
        tester,
        EmptyState(
          title: 'Sin resultados para "x"',
          body: 'Escríbenos',
          action: FilledButton(
            onPressed: () {},
            child: const Text('Escribir por WhatsApp'),
          ),
        ),
      );
      expect(find.text('Escribir por WhatsApp'), findsOneWidget);
    });

    testWidgets('RNF-074 · con movimiento reducido no hay animación de carga', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await pumpApp(tester, const LoadingState());
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.hourglass_empty), findsOneWidget);
    });
  });

  group('SC-035 · SensitiveScreen', () {
    testWidgets('activa la protección al entrar y la desactiva al salir', (
      tester,
    ) async {
      final spy = _SpyProtection();
      await pumpApp(
        tester,
        SensitiveScreen(protection: spy, child: const Text('Perfil')),
      );
      expect(spy.enabled, 1);
      expect(spy.disabled, 0);
      await tester.pumpWidget(const SizedBox());
      expect(spy.disabled, 1);
    });
  });

  group('TC-157 · RNF-067..076 · guías de accesibilidad automáticas', () {
    Future<void> guidelines(WidgetTester tester) async {
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    }

    testWidgets('ErrorState', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(
        tester,
        ErrorState(failure: const NoConnection(), onRetry: () {}),
      );
      await guidelines(tester);
      handle.dispose();
    });

    testWidgets('EmptyState y StaleBanner', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(
        tester,
        const Column(
          children: [
            StaleBanner(),
            Expanded(child: EmptyState()),
          ],
        ),
      );
      await guidelines(tester);
      handle.dispose();
    });

    testWidgets('PriceText y StockBadge en todos los estados', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(
        tester,
        const Column(
          children: [
            PriceText(price: Priced(Money(1445000))),
            PriceText(price: OnRequest()),
            StockBadge(stock: StockStatus.inStock),
            StockBadge(stock: StockStatus.outOfStock),
            StockBadge(stock: StockStatus.onBackorder),
            StockBadge(stock: StockStatus.unknown),
          ],
        ),
      );
      await guidelines(tester);
      handle.dispose();
    });

    testWidgets(
      'RNF-068 · ErrorState y EmptyState no desbordan al 200 % en pantalla baja',
      (tester) async {
        await pumpApp(
          tester,
          ErrorState(failure: const NoConnection(), onRetry: () {}),
          textScale: 2,
          size: const Size(320, 260),
        );
        expect(tester.takeException(), isNull);
        await pumpApp(
          tester,
          const EmptyState(),
          textScale: 2,
          size: const Size(320, 260),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('texto al 200 % no desborda (RNF-068)', (tester) async {
      await pumpApp(
        tester,
        const SingleChildScrollView(
          child: Column(
            children: [
              PriceText(price: Priced(Money(1445000))),
              StockBadge(stock: StockStatus.unknown),
              StaleBanner(),
            ],
          ),
        ),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
