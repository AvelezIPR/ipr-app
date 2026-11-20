import 'package:ipr_mobile/core/errors/app_failure.dart';
import 'package:ipr_mobile/core/network/request_cancellation.dart';
import 'package:ipr_mobile/core/network/result.dart';
import 'package:ipr_mobile/features/checkout/data/datasources/checkout_remote_datasource.dart';
import 'package:ipr_mobile/features/checkout/data/mappers/checkout_mappers.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/checkout_line.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/checkout_status.dart';
import 'package:ipr_mobile/features/checkout/domain/entities/checkout_ticket.dart';
import 'package:ipr_mobile/features/checkout/domain/repositories/checkout_repository.dart';

/// Implementación sobre `/mobile/v1`. **No persiste nada**: ni la respuesta,
/// ni la URL, ni el ticket.
final class ApiCheckoutRepository implements CheckoutRepository {
  const new(this._remote);

  final CheckoutRemoteDataSource _remote;

  @override
  Future<Result<CheckoutTicket>> createCheckout({
    required List<CheckoutLine> lines,
    required String idempotencyKey,
    RequestCancellation? cancellation,
  }) async {
    final result = await _remote.create(
      checkoutRequestOf(lines),
      idempotencyKey: idempotencyKey,
      cancellation: cancellation,
    );
    return _mapped(result, mapCheckoutTicket, 'POST /checkout');
  }

  @override
  Future<Result<CheckoutStatus>> status(
    String checkoutRef, {
    RequestCancellation? cancellation,
  }) async {
    final result = await _remote.status(
      checkoutRef,
      cancellation: cancellation,
    );
    return _mapped(result, mapCheckoutStatus, 'GET /checkout/{ref}');
  }

  /// Un fallo de mapeo es [ContractFailure] sin detalle de la respuesta.
  Result<R> _mapped<T, R>(
    Result<T> result,
    R Function(T value) transform,
    String route,
  ) => switch (result) {
    Err<T>(:final failure) => Err(failure),
    Ok<T>(:final value) => _transform(value, transform, route),
  };

  Result<R> _transform<T, R>(
    T value,
    R Function(T value) transform,
    String route,
  ) {
    try {
      return Ok(transform(value));
    } on FormatException {
      return Err(ContractFailure(detail: route));
    }
  }
}
