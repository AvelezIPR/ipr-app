import 'package:ipr_mobile/core/network/api_client.dart';
import 'package:ipr_mobile/core/network/api_request.dart';
import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/support/domain/entities/pqrs.dart';

/// Cliente remoto para `POST /pqrs`. Exige `Idempotency-Key` (CR-005) y es
/// accesible sin sesión (AC-096-10).
final class PqrsRemoteDataSource {
  const new(this._client);

  final ApiClient _client;

  Future<Result<PqrsReceipt>> submit({
    required PqrsSubmission submission,
    required String idempotencyKey,
    RequestCancellation? cancel,
  }) {
    final body = <String, Object?>{
      'type': submission.type.apiValue,
      'name': submission.name,
      'email': submission.email,
      'phone': submission.phone,
      'orderReference': ?submission.orderReference,
      'message': submission.message,
      'acceptsDataPolicy': submission.acceptsDataPolicy,
    };

    return _client.sendDecoded<PqrsReceipt>(
      ApiRequest.post(
        '/pqrs',
        body: body,
        idempotencyKey: idempotencyKey,
        requiresIdempotency: true,
        receiveTimeout: ApiTimeouts.pqrs,
      ),
      _decodeReceipt,
      cancellation: cancel,
    );
  }

  static PqrsReceipt _decodeReceipt(Object? json) {
    if (json is! Map<String, dynamic> ||
        json['data'] is! Map<String, dynamic>) {
      throw const FormatException('se esperaba {data: {...}} en /pqrs');
    }
    final data = json['data']! as Map<String, dynamic>;
    final status = data['status'];
    final receivedAtRaw = data['receivedAt'];
    if (status is! String || status != 'received' || receivedAtRaw is! String) {
      throw const FormatException('respuesta PQRS inválida');
    }
    final receivedAt = DateTime.tryParse(receivedAtRaw);
    if (receivedAt == null) {
      throw const FormatException('receivedAt inválido en /pqrs');
    }
    return PqrsReceipt(status: status, receivedAt: receivedAt);
  }
}
