import 'package:dio/dio.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:ipr_mobile/core/providers.dart';
import 'package:ipr_mobile/core/storage/cache_store.dart';

import '../../mocks/fake_http_adapter.dart';
import '../../mocks/test_clients.dart';
import '../../mocks/test_providers.dart';
import 'catalog_fixtures.dart';

/// BFF simulado del catálogo sobre [FakeHttpAdapter]: despacha por ruta.
///
/// * [on] fija el manejador permanente de una ruta.
/// * [queue] guioniza una secuencia (la primera petición consume la primera
///   respuesta; al agotarse se usa el manejador permanente).
/// * Sin manejador responde 404 (`not_found`).
final class FakeCatalogBff {
  new({bool defaults = true}) {
    adapter.fallback = _dispatch;
    if (defaults) {
      on('/categories', (_) => FakeHttpAdapter.json(categoriesBody()));
      on('/brands', (_) => FakeHttpAdapter.json(brandsBody()));
      on('/filters', (_) => FakeHttpAdapter.json(filtersBody()));
    }
  }

  final FakeHttpAdapter adapter = FakeHttpAdapter();
  final Map<String, Responder> _handlers = {};
  final Map<String, List<Responder>> _queues = {};

  void on(String path, Responder responder) => _handlers[path] = responder;

  void queue(String path, List<Responder> responders) =>
      (_queues[path] ??= []).addAll(responders);

  /// Peticiones recibidas (con sus parámetros de consulta).
  List<RequestOptions> get requests => adapter.requests;

  List<RequestOptions> to(String path) =>
      requests.where((r) => r.path == path).toList();

  Future<ResponseBody> _dispatch(RequestOptions options) async {
    final queued = _queues[options.path];
    if (queued != null && queued.isNotEmpty) {
      return await queued.removeAt(0)(options);
    }
    final handler = _handlers[options.path];
    if (handler != null) return await handler(options);
    return FakeHttpAdapter.problem(404, 'not_found');
  }

  /// Overrides para montar widgets y controladores: cliente real sobre el
  /// adaptador falso y una caché en memoria.
  List<Override> overrides({CacheStore? cache}) {
    final client = buildTestClient(adapter: adapter).client;
    return testOverrides(
      cache: cache,
      extra: [apiClientProvider.overrideWithValue(client)],
    );
  }
}
