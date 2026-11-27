import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ipr_mobile/core/providers.dart';
import 'package:ipr_mobile/features/branches/data/datasources/branches_remote_datasource.dart';
import 'package:ipr_mobile/features/branches/data/repositories/api_branches_repository.dart';
import 'package:ipr_mobile/features/branches/domain/entities/colombia_map.dart';
import 'package:ipr_mobile/features/branches/domain/repositories/branches_repository.dart';

/// Repositorio de sedes sobre `ApiClient` y `CacheStore` (`CachePolicy.stores`).
/// Las pruebas de widgets sustituyen este proveedor con un doble (D4).
final branchesRepositoryProvider = Provider<BranchesRepository>(
  (ref) => ApiBranchesRepository(
    remote: BranchesRemoteDataSource(ref.watch(apiClientProvider)),
    cache: ref.watch(cacheStoreProvider),
  ),
);

/// Mapa de Colombia empaquetado (`assets/map/colombia_map.json`, W3-03). Si el
/// asset no se pudiera leer, el mapa queda vacío y la pantalla de Sedes sigue
/// funcionando solo con su lista: el mapa es una ayuda, no un requisito.
final colombiaMapProvider = FutureProvider<ColombiaMap>((ref) async {
  try {
    // Sin la caché del bundle: este proveedor ya guarda el resultado, y un
    // `Future` cacheado que no termina colgaría las lecturas siguientes.
    final text = await rootBundle.loadString(
      'assets/map/colombia_map.json',
      cache: false,
    );
    return ColombiaMap.fromJson(jsonDecode(text));
  } on Object {
    return ColombiaMap.empty;
  }
});
