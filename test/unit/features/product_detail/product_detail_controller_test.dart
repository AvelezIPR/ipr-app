import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/product_detail/domain/entities/product_detail.dart';
import 'package:ipr_mobile/features/product_detail/presentation/controllers/product_detail_controller.dart';
import 'package:ipr_mobile/features/product_detail/product_detail_providers.dart';
import 'package:ipr_mobile/shared/widgets/ui_state.dart';

import 'product_detail_test_support.dart';

void main() {
  const slug = 'compresor-scroll-24000-btu';

  ProviderContainer containerWith(FakeProductDetailRepository repo) {
    final container = ProviderContainer(
      overrides: [productDetailRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<UiState<ProductDetail>> settle(ProviderContainer c) async {
    final sub = c.listen(productDetailControllerProvider(slug), (_, _) {});
    addTearDown(sub.close);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    final state = c.read(productDetailControllerProvider(slug));
    return state;
  }

  test('M1 · RF-026 · empieza cargando y luego entrega los datos', () async {
    final repo = FakeProductDetailRepository([
      Ok(
        ProductDetailLoad(product: fixtureProduct('ProductDetail.priced.json')),
      ),
    ]);
    final c = containerWith(repo);
    final sub = c.listen(productDetailControllerProvider(slug), (_, _) {});
    addTearDown(sub.close);
    expect(
      c.read(productDetailControllerProvider(slug)),
      isA<UiLoading<ProductDetail>>(),
    );
    final state = await settle(c);
    expect(state, isA<UiData<ProductDetail>>());
    expect((state as UiData<ProductDetail>).stale, isFalse);
    expect(repo.calls.single, (slug: slug, forceRefresh: false));
  });

  test('RNF-022 · datos obsoletos llegan marcados', () async {
    final c = containerWith(
      FakeProductDetailRepository([
        Ok(
          ProductDetailLoad(
            product: fixtureProduct('ProductDetail.priced.json'),
            stale: true,
          ),
        ),
      ]),
    );
    final state = await settle(c);
    expect((state as UiData<ProductDetail>).stale, isTrue);
  });

  test('404 y 503 son estados distintos', () async {
    final notFound = await settle(
      containerWith(FakeProductDetailRepository([const Err(NotFound())])),
    );
    expect((notFound as UiFailure<ProductDetail>).failure, isA<NotFound>());

    final down = await settle(
      containerWith(
        FakeProductDetailRepository([const Err(ServiceUnavailable())]),
      ),
    );
    expect(
      (down as UiFailure<ProductDetail>).failure,
      isA<ServiceUnavailable>(),
    );
  });

  test(
    'AC-009-3 · reintentar vuelve a pedir ignorando la caché y carga',
    () async {
      final repo = FakeProductDetailRepository([
        const Err(NoConnection()),
        Ok(
          ProductDetailLoad(
            product: fixtureProduct('ProductDetail.priced.json'),
          ),
        ),
      ]);
      final c = containerWith(repo);
      expect(await settle(c), isA<UiFailure<ProductDetail>>());

      final retry = c
          .read(productDetailControllerProvider(slug).notifier)
          .retry();
      expect(
        c.read(productDetailControllerProvider(slug)),
        isA<UiLoading<ProductDetail>>(),
      );
      await retry;
      expect(
        c.read(productDetailControllerProvider(slug)),
        isA<UiData<ProductDetail>>(),
      );
      expect(repo.calls.last.forceRefresh, isTrue);
    },
  );

  test('al salir de la pantalla se cancela la petición en vuelo', () async {
    final repo = CancellableProductDetailRepository();
    final c = ProviderContainer(
      overrides: [productDetailRepositoryProvider.overrideWithValue(repo)],
    );
    final sub = c.listen(productDetailControllerProvider(slug), (_, _) {});
    await Future<void>.delayed(Duration.zero);
    expect(repo.cancellations.single!.isCancelled, isFalse);
    sub.close();
    await Future<void>.delayed(Duration.zero);
    c.dispose();
    expect(repo.cancellations.single!.isCancelled, isTrue);
    // Responder después no rompe nada.
    repo.pending.single.complete(const Err(NoConnection()));
    await Future<void>.delayed(Duration.zero);
  });

  test('un reintento cancela el anterior y solo escribe el último', () async {
    final repo = CancellableProductDetailRepository();
    final c = ProviderContainer(
      overrides: [productDetailRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    final sub = c.listen(productDetailControllerProvider(slug), (_, _) {});
    addTearDown(sub.close);
    await Future<void>.delayed(Duration.zero);

    final retry = c
        .read(productDetailControllerProvider(slug).notifier)
        .retry();
    await Future<void>.delayed(Duration.zero);
    expect(repo.cancellations.first!.isCancelled, isTrue);
    expect(repo.cancellations.last!.isCancelled, isFalse);

    // La primera responde tarde con un fallo: se ignora.
    repo.pending.first.complete(const Err(NoConnection()));
    await Future<void>.delayed(Duration.zero);
    expect(
      c.read(productDetailControllerProvider(slug)),
      isA<UiLoading<ProductDetail>>(),
    );

    repo.pending.last.complete(
      Ok(
        ProductDetailLoad(product: fixtureProduct('ProductDetail.priced.json')),
      ),
    );
    await retry;
    expect(
      c.read(productDetailControllerProvider(slug)),
      isA<UiData<ProductDetail>>(),
    );
  });
}
