import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/storage/cache_store.dart';
import 'package:ipr_mobile/features/home/data/mappers/home_mappers.dart';
import 'package:ipr_mobile/features/home/data/repositories/api_home_repository.dart';
import 'package:ipr_mobile/features/home/domain/entities/home_city.dart';

import '../../../mocks/fake_http_adapter.dart';
import '../../../mocks/test_clients.dart';
import 'home_test_support.dart';

Map<String, dynamic> _store(String city, {bool upcoming = false}) => {
  'slug': '${city.toLowerCase()}-${upcoming ? 'pronto' : 'sede'}',
  'city': city,
  'name': 'Sede de $city',
  'upcoming': upcoming,
};

void main() {
  group('RF-072 · mapCities (resumen de sedes por ciudad)', () {
    test('cuenta las sedes abiertas por ciudad', () {
      final cities = mapCities([
        _store('Medellín'),
        _store('Medellín'),
        _store('Cali'),
      ]);
      expect(cities, const [
        HomeCity(name: 'Medellín', branchCount: 2, upcoming: false),
        HomeCity(name: 'Cali', branchCount: 1, upcoming: false),
      ]);
    });

    test('ordena por más sedes y, a igualdad, por nombre', () {
      final cities = mapCities([
        _store('Cali'),
        _store('Bogotá'),
        _store('Medellín'),
        _store('Medellín'),
      ]);
      expect(cities.map((c) => c.name), ['Medellín', 'Bogotá', 'Cali']);
    });

    test('una ciudad con solo sedes por abrir va al final y es "próxima"', () {
      final cities = mapCities([
        _store('Cartagena', upcoming: true),
        _store('Cali'),
      ]);
      expect(cities.map((c) => c.name), ['Cali', 'Cartagena']);
      expect(cities.last.upcoming, isTrue);
      expect(cities.last.branchCount, 0);
    });

    test('una sede por abrir no suma a una ciudad que ya tiene abiertas', () {
      final cities = mapCities([
        _store('Cali'),
        _store('Cali', upcoming: true),
      ]);
      expect(cities.single.branchCount, 1);
      expect(cities.single.upcoming, isFalse);
    });

    test('descarta sedes sin ciudad o con ciudad vacía y no se cae', () {
      final cities = mapCities([
        {'slug': 'x', 'name': 'Sin ciudad'},
        {'slug': 'y', 'city': '   '},
        {'slug': 'z', 'city': 42},
        _store('Bogotá'),
      ]);
      expect(cities.map((c) => c.name), ['Bogotá']);
    });

    test('sin sedes devuelve una lista vacía', () {
      expect(mapCities(const []), isEmpty);
    });
  });

  group('RF-072 · ApiHomeRepository.cities (listStores)', () {
    late FakeHttpAdapter adapter;
    late MemoryCacheStore cache;
    late ApiHomeRepository repo;

    setUp(() {
      adapter = FakeHttpAdapter();
      cache = MemoryCacheStore(now: () => DateTime(2026, 11, 23, 10));
      repo = ApiHomeRepository(
        client: buildTestClient(adapter: adapter).client,
        cache: cache,
      );
    });

    Responder ok(Object? body) =>
        (_) => FakeHttpAdapter.json(body);

    test('pide GET /stores y agrupa por ciudad', () async {
      adapter.enqueue(
        ok(listBody([_store('Medellín'), _store('Cali'), _store('Medellín')])),
      );
      final result = await repo.cities();
      expect(adapter.requests.single.path, '/stores');
      expect(adapter.requests.single.method, 'GET');
      expect(result.valueOrNull!.value.map((c) => c.name), [
        'Medellín',
        'Cali',
      ]);
    });

    test('sin red y sin caché devuelve el error (no lista vacía)', () async {
      adapter.fallback = FakeHttpAdapter.connectionError;
      final result = await repo.cities();
      expect(result.failureOrNull, isA<NoConnection>());
    });

    test(
      'sin red, con caché guardada: devuelve la caché como obsoleta',
      () async {
        adapter.enqueue(ok(listBody([_store('Cali')])));
        await repo.cities();
        adapter.fallback = FakeHttpAdapter.connectionError;
        final result = await repo.cities(forceRefresh: true);
        final data = result.valueOrNull!;
        expect(data.stale, isTrue);
        expect(data.value.single.name, 'Cali');
      },
    );
  });
}
