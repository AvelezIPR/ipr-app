import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/home/domain/entities/home_brand.dart';
import 'package:ipr_mobile/features/home/domain/entities/home_category.dart';
import 'package:ipr_mobile/features/home/domain/entities/section_data.dart';
import 'package:ipr_mobile/features/home/domain/repositories/home_repository.dart';
import 'package:ipr_mobile/features/home/home_providers.dart';
import 'package:ipr_mobile/features/home/presentation/controllers/home_controllers.dart';
import 'package:ipr_mobile/shared/domain/product_summary.dart';
import 'package:ipr_mobile/shared/widgets/ui_state.dart';

import 'home_test_support.dart';

const _cat = HomeCategory(id: 1, slug: 'aire', name: 'Aire');
const _cat2 = HomeCategory(id: 2, slug: 'refri', name: 'Refrigeración');

/// Contenedor con el repositorio doble; al crearlo empieza la carga de
/// categorías (como lo haría la pantalla al observarlas).
ProviderContainer _container(HomeRepository repo) {
  final container = ProviderContainer(
    overrides: [homeRepositoryProvider.overrideWithValue(repo)],
  )..read(homeCategoriesProvider);
  addTearDown(container.dispose);
  return container;
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

/// Repositorio con compuerta: permite resolver las cargas en el orden que
/// la prueba decida.
final class _GatedRepository extends FakeHomeRepository {
  new(this.gates);

  final List<Completer<Result<SectionData<List<HomeCategory>>>>> gates;
  int _i = 0;

  @override
  Future<Result<SectionData<List<HomeCategory>>>> categories({
    bool forceRefresh = false,
  }) => gates[_i++].future;
}

void main() {
  group('M1 · RF-002 · HomeCategoriesController', () {
    test('Loading → Data', () async {
      final repo = FakeHomeRepository(
        categoryResults: [
          const Ok(SectionData([_cat])),
        ],
      );
      final container = _container(repo);
      expect(
        container.read(homeCategoriesProvider),
        isA<UiLoading<List<HomeCategory>>>(),
      );
      await _settle();
      final state = container.read(homeCategoriesProvider);
      expect(state, isA<UiData<List<HomeCategory>>>());
      expect((state as UiData<List<HomeCategory>>).value, [_cat]);
      expect(state.stale, isFalse);
      expect(repo.categoryCalls, [false]);
    });

    test('200 con lista vacía → UiEmpty (solo en ese caso)', () async {
      final container = _container(
        FakeHomeRepository(
          categoryResults: [const Ok(SectionData(<HomeCategory>[]))],
        ),
      );
      await _settle();
      expect(
        container.read(homeCategoriesProvider),
        isA<UiEmpty<List<HomeCategory>>>(),
      );
    });

    test(
      'un fallo es UiFailure (nunca UiEmpty) y "Reintentar" recupera',
      () async {
        final repo = FakeHomeRepository(
          categoryResults: [
            const Err(NoConnection()),
            const Ok(SectionData([_cat])),
          ],
        );
        final container = _container(repo);
        await _settle();
        final failed = container.read(homeCategoriesProvider);
        expect(failed, isA<UiFailure<List<HomeCategory>>>());
        expect(
          (failed as UiFailure<List<HomeCategory>>).failure,
          isA<NoConnection>(),
        );

        final future = container
            .read(homeCategoriesProvider.notifier)
            .load(forceRefresh: true);
        expect(
          container.read(homeCategoriesProvider),
          isA<UiLoading<List<HomeCategory>>>(),
        );
        await future;
        expect(
          container.read(homeCategoriesProvider),
          isA<UiData<List<HomeCategory>>>(),
        );
        expect(repo.categoryCalls, [false, true]);
      },
    );

    test('datos guardados llegan marcados como obsoletos', () async {
      final container = _container(
        FakeHomeRepository(
          categoryResults: [
            const Ok(SectionData([_cat], stale: true)),
          ],
        ),
      );
      await _settle();
      final state =
          container.read(homeCategoriesProvider) as UiData<List<HomeCategory>>;
      expect(state.stale, isTrue);
    });

    test(
      'refresco fallido con datos en pantalla: los conserva (obsoletos)',
      () async {
        final container = _container(
          FakeHomeRepository(
            categoryResults: [
              const Ok(SectionData([_cat])),
              const Err(RequestTimeout()),
            ],
          ),
        );
        await _settle();
        await container
            .read(homeCategoriesProvider.notifier)
            .load(forceRefresh: true);
        final state = container.read(
          homeCategoriesProvider,
        ) as UiData<List<HomeCategory>>;
        expect(state.value, [_cat]);
        expect(state.stale, isTrue);
      },
    );

    test('una carga más nueva no es pisada por una anterior lenta', () async {
      final slow = Completer<Result<SectionData<List<HomeCategory>>>>();
      final fast = Completer<Result<SectionData<List<HomeCategory>>>>();
      final container = _container(_GatedRepository([slow, fast]));
      await _settle(); // arranca la carga 1 (lenta)
      final second = container
          .read(homeCategoriesProvider.notifier)
          .load(forceRefresh: true);
      fast.complete(const Ok(SectionData([_cat2])));
      await second;
      slow.complete(const Ok(SectionData([_cat])));
      await _settle();
      final state =
          container.read(homeCategoriesProvider) as UiData<List<HomeCategory>>;
      expect(state.value, [_cat2]);
    });

    test('descartar el controlador durante la carga no lanza', () async {
      final gate = Completer<Result<SectionData<List<HomeCategory>>>>();
      final container = ProviderContainer(
        overrides: [
          homeRepositoryProvider.overrideWithValue(_GatedRepository([gate])),
        ],
      );
      await _settle();
      container.dispose();
      gate.complete(const Ok(SectionData([_cat])));
      await _settle();
    });
  });

  group('M1 · AC-003-4 · las secciones son independientes', () {
    test('si falla solo "más vendidos", categorías y marcas siguen', () async {
      // Las otras dos secciones empiezan al observarlas.
      final container =
          _container(
              FakeHomeRepository(
                categoryResults: [
                  const Ok(SectionData([_cat])),
                ],
                brandResults: [
                  const Ok(
                    SectionData([HomeBrand(slug: 'elitech', name: 'Elitech')]),
                  ),
                ],
                featuredResults: [const Err(ServiceUnavailable())],
              ),
            )
            ..read(homeBrandsProvider)
            ..read(homeFeaturedProvider);
      await _settle();
      expect(
        container.read(homeCategoriesProvider),
        isA<UiData<List<HomeCategory>>>(),
      );
      expect(
        container.read(homeBrandsProvider),
        isA<UiData<List<HomeBrand>>>(),
      );
      expect(
        container.read(homeFeaturedProvider),
        isA<UiFailure<List<ProductSummary>>>(),
      );
    });
  });
}
