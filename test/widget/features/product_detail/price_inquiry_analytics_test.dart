import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/core/observability/analytics_sink.dart';
import 'package:ipr_mobile/core/providers.dart';
import 'package:ipr_mobile/features/product_detail/product_detail.dart';
import 'package:ipr_mobile/features/product_detail/product_detail_providers.dart';
import 'package:ipr_mobile/shared/domain/price_status.dart';
import 'package:ipr_mobile/shared/domain/stock_status.dart';

import 'product_detail_harness.dart';

final class _SpyAnalyticsSink implements AnalyticsSink {
  final List<({String event, Map<String, String> params})> events = [];
  bool shouldThrow = false;

  @override
  Future<void> track(
    String event, {
    Map<String, String> parameters = const {},
  }) async {
    if (shouldThrow) throw StateError('analytics error');
    events.add((event: event, params: parameters));
  }
}

void main() {
  group('M5 · RF-065 · Medición agregada de Más información (PA-08)', () {
    testWidgets(
      'AC-065-1/2 · producto sin precio registra exactamente 1 evento sin PII al abrir WhatsApp',
      (tester) async {
        final sink = _SpyAnalyticsSink();
        final launcher = FakeExternalLauncher();
        final repo = FakeProductDetailRepository([
          Ok(
            ProductDetailLoad(product: customProduct(price: const OnRequest())),
          ),
        ]);

        await pumpApp(
          tester,
          const ProductDetailScreen(slug: kSlug),
          overrides: testOverrides(
            launcher: launcher,
            extra: [
              productDetailRepositoryProvider.overrideWithValue(repo),
              analyticsSinkProvider.overrideWithValue(sink),
            ],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final consultBtn = find.text('Más información');
        await tester.ensureVisible(consultBtn);
        await tester.tap(consultBtn);
        await tester.pump();

        expect(launcher.opened, hasLength(1));
        expect(sink.events, hasLength(1));
        expect(sink.events.single.event, 'price_on_request_tap');
        expect(sink.events.single.params['product_id'], '77');
        expect(sink.events.single.params['timestamp'], isNotEmpty);
        expect(sink.events.single.params.keys, {'product_id', 'timestamp'});
      },
    );

    testWidgets(
      'AC-065-4 · si el AnalyticsSink falla, WhatsApp se abre igual sin error visible',
      (tester) async {
        final sink = _SpyAnalyticsSink()..shouldThrow = true;
        final launcher = FakeExternalLauncher();
        final repo = FakeProductDetailRepository([
          Ok(
            ProductDetailLoad(
              product: customProduct(
                price: const OnRequest(),
                availability: StockStatus.unknown,
              ),
            ),
          ),
        ]);

        await pumpApp(
          tester,
          const ProductDetailScreen(slug: kSlug),
          overrides: testOverrides(
            launcher: launcher,
            extra: [
              productDetailRepositoryProvider.overrideWithValue(repo),
              analyticsSinkProvider.overrideWithValue(sink),
            ],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final consultBtn = find.text('Más información');
        await tester.ensureVisible(consultBtn);
        await tester.tap(consultBtn);
        await tester.pump();

        expect(launcher.opened, hasLength(1));
        expect(tester.takeException(), isNull);
      },
    );
  });
}
