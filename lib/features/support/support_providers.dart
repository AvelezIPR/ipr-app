import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ipr_mobile/core/config/remote_config_controller.dart';
import 'package:ipr_mobile/core/external/external_url_policy.dart';
import 'package:ipr_mobile/core/network/uuid_v4.dart';
import 'package:ipr_mobile/core/providers.dart';
import 'package:ipr_mobile/features/support/data/datasources/pqrs_remote_datasource.dart';
import 'package:ipr_mobile/features/support/data/mappers/legal_documents_mapper.dart';
import 'package:ipr_mobile/features/support/data/repositories/api_pqrs_repository.dart';
import 'package:ipr_mobile/features/support/data/repositories/secure_browser_legal_opener.dart';
import 'package:ipr_mobile/features/support/domain/entities/legal_document.dart';
import 'package:ipr_mobile/features/support/domain/repositories/legal_opener.dart';
import 'package:ipr_mobile/features/support/domain/repositories/pqrs_repository.dart';

/// Documentos legales publicados en `/config` (se actualizan solos cuando la
/// configuración remota se refresca).
final legalDocumentsProvider = Provider<List<LegalDocument>>(
  (ref) => legalDocumentsFromConfig(ref.watch(remoteConfigProvider).config),
);

/// Aviso (texto plano) sobre la eliminación de cuenta, si el servidor lo trae.
final accountDeletionNoticeProvider = Provider<String?>(
  (ref) =>
      accountDeletionNoticeFromConfig(ref.watch(remoteConfigProvider).config),
);

/// Abridor de documentos. Vive en la raíz de la feature para conectar
/// `data/` con los controladores sin romper D4; las pruebas lo sustituyen.
final legalOpenerProvider = Provider<LegalOpener>(
  (ref) => SecureBrowserLegalOpener(
    browser: ref.watch(secureBrowserProvider),
    policy: ExternalUrlPolicy(
      extraHttpsHosts: {ref.watch(appConfigProvider).deepLinkHost},
    ),
  ),
);

/// Repositorio PQRS (`POST /pqrs`). Las pruebas lo sustituyen por un doble.
final pqrsRepositoryProvider = Provider<PqrsRepository>(
  (ref) =>
      ApiPqrsRepository(PqrsRemoteDataSource(ref.watch(apiClientProvider))),
);

/// Generador de `Idempotency-Key` para `POST /pqrs` (CR-005).
final supportUuidProvider = Provider<String Function()>((ref) => uuidV4);
