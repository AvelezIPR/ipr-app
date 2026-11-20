import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/branches/domain/entities/branch.dart';

/// Resultado cacheable con marca de frescura (patrón SWR, `CachePolicy.stores`).
final class BranchesSnapshot {
  const new({required this.branches, this.stale = false});

  final List<Branch> branches;
  final bool stale;
}

/// Acceso a las sedes (`GET /stores`, RF-072..076). Sin detalles de red ni
/// caché (D5).
abstract interface class BranchesRepository {
  Future<Result<BranchesSnapshot>> stores({
    bool forceRefresh = false,
    RequestCancellation? cancel,
  });
}
