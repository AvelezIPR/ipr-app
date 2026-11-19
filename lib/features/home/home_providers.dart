import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ipr_mobile/core/providers.dart';
import 'package:ipr_mobile/features/home/data/repositories/api_home_repository.dart';
import 'package:ipr_mobile/features/home/domain/repositories/home_repository.dart';

/// Repositorio del inicio. Vive en la raíz de la feature (no en
/// `presentation/`) para poder conectar `data/` con los controladores sin
/// romper D4; las pruebas lo sustituyen con un `override`.
final homeRepositoryProvider = Provider<HomeRepository>(
  (ref) => ApiHomeRepository(
    client: ref.watch(apiClientProvider),
    cache: ref.watch(cacheStoreProvider),
  ),
);
