import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ipr_mobile/core/network/uuid_v4.dart';
import 'package:ipr_mobile/core/providers.dart';
import 'package:ipr_mobile/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:ipr_mobile/features/profile/data/repositories/api_profile_repository.dart';
import 'package:ipr_mobile/features/profile/domain/repositories/profile_repository.dart';

/// Repositorio del perfil (D4: en la raíz de la feature para que
/// `presentation/` no importe `data/`).
final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ApiProfileRepository(
    ProfileRemoteDataSource(ref.watch(apiClientProvider)),
  ),
);

/// Generador de UUID v4 para la cabecera `Idempotency-Key` de
/// `POST /me/deletion` (CR-005).
final profileUuidProvider = Provider<String Function()>((ref) => uuidV4);
