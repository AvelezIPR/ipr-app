/// `PaymentState` del contrato (`openapi.yaml`): lo único que decide si un
/// pedido está pagado. Un valor nuevo o desconocido NUNCA es [paid].
enum PaymentState {
  paid,
  pending,
  failed,
  cancelled,
  refunded,
  unknown;

  /// Tolerante: cualquier valor no reconocido es [unknown].
  static PaymentState fromContract(Object? value) => switch (value) {
    'paid' => PaymentState.paid,
    'pending' => PaymentState.pending,
    'failed' => PaymentState.failed,
    'cancelled' => PaymentState.cancelled,
    'refunded' => PaymentState.refunded,
    _ => PaymentState.unknown,
  };
}
