import 'package:meta/meta.dart';

/// Tipos de PQRS admitidos por `POST /pqrs` (`openapi.yaml` → `PqrsRequest`).
enum PqrsType {
  peticion('peticion'),
  queja('queja'),
  reclamo('reclamo'),
  sugerencia('sugerencia');

  new(this.apiValue);

  final String apiValue;
}

/// Solicitud de PQRS antes de enviarla al servidor (RF-096).
///
/// `toString` no expone PII (`AC-096-12`).
@immutable
final class PqrsSubmission {
  const new({
    required this.type,
    required this.name,
    required this.email,
    required this.phone,
    required this.message,
    required this.acceptsDataPolicy,
    this.orderReference,
  });

  final PqrsType type;
  final String name;
  final String email;
  final String phone;
  final String? orderReference;
  final String message;
  final bool acceptsDataPolicy;

  @override
  String toString() => 'PqrsSubmission(type: ${type.apiValue})';
}

/// Confirmación del servidor tras radicar una PQRS (HTTP 202).
@immutable
final class PqrsReceipt {
  const new({required this.status, required this.receivedAt});

  final String status;
  final DateTime receivedAt;
}
