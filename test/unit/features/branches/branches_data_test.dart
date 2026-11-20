import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart' show ResponseBody;
import 'package:flutter_test/flutter_test.dart';
import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/core/storage/cache_store.dart';
import 'package:ipr_mobile/features/branches/branches.dart';
import 'package:ipr_mobile/features/branches/data/datasources/branches_remote_datasource.dart';
import 'package:ipr_mobile/features/branches/data/mappers/branches_mappers.dart';
import 'package:ipr_mobile/features/branches/data/repositories/api_branches_repository.dart';

import '../../../mocks/fake_http_adapter.dart';
import '../../../mocks/test_clients.dart';

Map<String, dynamic> _fixture(String name) =>
    jsonDecode(File('test/fixtures/branches/$name').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  group('M5 · RF-072..076 · mapStores y agrupación por ciudad', () {
    test('TC-124 · AC-076-4 · mapea sedes válidas y omite teléfono inválido sin fallar', () {
      final branches = mapStores({
        'data': [
          _fixture('Store.valid.json'),
          _fixture('Store.upcoming.json'),
          _fixture('Store.missing-whatsapp.json'),
          _fixture('Store.bad-dial.json'),
        ],
      });
      expect(branches, hasLength(4));
      expect(branches.first.phones, hasLength(4));
      expect(branches[1].upcoming, isTrue);
      expect(branches[2].whatsappNumber, isNull);
      expect(branches[3].phones, isEmpty);
    });

    test(
      'TC-124 · AC-072-6 · groupBranchesByCity agrupa sin ciudades vacías',
      () {
        final grouped = groupBranchesByCity([
          const Branch(
            slug: 's1',
            city: 'Medellín',
            name: 'Sede 1',
            address: 'Dir 1',
            upcoming: false,
            phones: [],
          ),
          const Branch(
            slug: 's2',
            city: 'Bogotá',
            name: 'Sede 2',
            address: 'Dir 2',
            upcoming: false,
            phones: [],
          ),
          const Branch(
            slug: 's3',
            city: 'Medellín',
            name: 'Sede 3',
            address: 'Dir 3',
            upcoming: false,
            phones: [],
          ),
          const Branch(
            slug: 's-empty-city',
            city: '   ',
            name: 'Sin ciudad',
            address: 'Dir',
            upcoming: false,
            phones: [],
          ),
        ]);
        expect(grouped.map((g) => g.city), ['Medellín', 'Bogotá']);
        expect(grouped.first.branches.map((b) => b.slug), ['s1', 's3']);
      },
    );

    test('TC-125 · AC-075-2 · buildBranchMapsUri codifica y decodifica tildes, #, & y comas', () {
      const address = 'Calle 0 # 0-00, Local 1 & 2, Medellín, San José';
      const branch = Branch(
        slug: 's1',
        city: 'Medellín',
        name: 'Sede Centro',
        address: address,
        upcoming: false,
        phones: [],
      );
      final uri = buildBranchMapsUri(branch);
      expect(uri, isNotNull);
      expect(uri!.host, 'www.google.com');
      expect(uri.path, startsWith('/maps'));
      expect(uri.queryParameters['query'], address);
    });

    test('M5 · RF-076 · respuesta sin {data: [...]} lanza FormatException', () {
      expect(() => mapStores({'bad': 1}), throwsFormatException);
    });
  });

  group('M5 · RF-076 · ApiBranchesRepository (SWR + fallo transitorio)', () {
    test(
      'usa caché fresca sin llamar a red y cae a caché obsoleta ante 503',
      () async {
        final adapter = FakeHttpAdapter()
          ..enqueue(
            (_) => FakeHttpAdapter.json({
              'data': [_fixture('Store.valid.json')],
            }),
          );
        final cache = MemoryCacheStore();
        final repo = ApiBranchesRepository(
          remote: BranchesRemoteDataSource(
            buildTestClient(adapter: adapter).client,
          ),
          cache: cache,
        );

        final first = await repo.stores();
        expect(first, isA<Ok<BranchesSnapshot>>());
        expect((first as Ok<BranchesSnapshot>).value.branches, hasLength(1));
        expect(adapter.requests, hasLength(1));

        // Segunda lectura dentro de TTL no pega a la red.
        final cached = await repo.stores();
        expect((cached as Ok<BranchesSnapshot>).value.stale, isFalse);
        expect(adapter.requests, hasLength(1));

        // ForceRefresh ante 503 devuelve caché marcada como stale.
        adapter.fallback = (_) =>
            FakeHttpAdapter.problem(503, 'upstream_unavailable');
        final stale = await repo.stores(forceRefresh: true);
        expect(stale, isA<Ok<BranchesSnapshot>>());
        expect((stale as Ok<BranchesSnapshot>).value.stale, isTrue);
      },
    );

    test('sin caché un 304 devuelve ContractFailure', () async {
      final adapter = FakeHttpAdapter()
        ..fallback = (_) => ResponseBody.fromString('', 304);
      final repo = ApiBranchesRepository(
        remote: BranchesRemoteDataSource(
          buildTestClient(adapter: adapter).client,
        ),
        cache: MemoryCacheStore(),
      );
      final res = await repo.stores();
      expect(res, isA<Err<BranchesSnapshot>>());
      expect((res as Err<BranchesSnapshot>).failure, isA<ContractFailure>());
    });
  });
}
