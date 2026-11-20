import 'package:ipr_mobile/core/network/api_client.dart';
import 'package:ipr_mobile/core/network/api_request.dart';
import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/checkout/data/dtos/checkout_dtos.dart';

/// Acceso HTTP a `POST /checkout` (EP-23) y `GET /checkout/{ref}` (EP-24).
///
/// * `POST`: autenticado, `Idempotency-Key` OBLIGATORIA (CR-005), tiempo de
///   20 s (RNF-021) y **nunca** se reintenta solo (`RetryInterceptor` solo
///   reintenta GET).
/// * `GET`: autenticado; el estado es la fuente de verdad del pago.
final class CheckoutRemoteDataSource {
  const new(this._client);

  final ApiClient _client;

  Future<Result<CheckoutSessionDto>> create(
    CheckoutRequestDto body, {
    required String idempotencyKey,
    RequestCancellation? cancellation,
  }) => _client.sendDecoded(
    ApiRequest.post(
      '/checkout',
      body: body.toJson(),
      requiresAuth: true,
      requiresIdempotency: true,
      idempotencyKey: idempotencyKey,
      receiveTimeout: ApiTimeouts.checkout,
    ),
    CheckoutSessionDto.fromJson,
    cancellation: cancellation,
  );

  Future<Result<CheckoutStatusDto>> status(
    String checkoutRef, {
    RequestCancellation? cancellation,
  }) => _client.sendDecoded(
    ApiRequest.get(
      '/checkout/${Uri.encodeComponent(checkoutRef)}',
      requiresAuth: true,
    ),
    CheckoutStatusDto.fromJson,
    cancellation: cancellation,
  );
}
