import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/support/data/datasources/pqrs_remote_datasource.dart';
import 'package:ipr_mobile/features/support/domain/entities/pqrs.dart';
import 'package:ipr_mobile/features/support/domain/repositories/pqrs_repository.dart';

/// Repositorio sin almacenamiento local ni logs: la PQRS vive solo en vuelo
/// durante el envío (AC-096-12).
final class ApiPqrsRepository implements PqrsRepository {
  const new(this._remote);

  final PqrsRemoteDataSource _remote;

  @override
  Future<Result<PqrsReceipt>> submit({
    required PqrsSubmission submission,
    required String idempotencyKey,
    RequestCancellation? cancel,
  }) => _remote.submit(
    submission: submission,
    idempotencyKey: idempotencyKey,
    cancel: cancel,
  );
}
