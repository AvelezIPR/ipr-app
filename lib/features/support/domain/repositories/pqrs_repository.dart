import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/support/domain/entities/pqrs.dart';

/// Envío de PQRS al buzón corporativo (`POST /pqrs`, RF-096, RF-097).
abstract interface class PqrsRepository {
  Future<Result<PqrsReceipt>> submit({
    required PqrsSubmission submission,
    required String idempotencyKey,
    RequestCancellation? cancel,
  });
}
