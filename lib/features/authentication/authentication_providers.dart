import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ipr_mobile/core/providers.dart';
import 'package:ipr_mobile/features/authentication/data/datasources/auth_remote_datasource.dart';
import 'package:ipr_mobile/features/authentication/data/repositories/api_auth_repository.dart';
import 'package:ipr_mobile/features/authentication/domain/repositories/auth_repository.dart';

/// Repositorio de autenticación. Las pruebas lo sustituyen con un doble de la
/// interfaz de dominio. Vive en la raíz de la feature porque los controladores
/// (presentation) no pueden importar `data/` (D4).
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) =>
      ApiAuthRepository(AuthRemoteDataSource(ref.watch(apiClientProvider))),
);
