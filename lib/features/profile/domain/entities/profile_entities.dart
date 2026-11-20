import 'package:ipr_mobile/core/session/session_tokens.dart';
import 'package:meta/meta.dart';

/// Tipo de dirección soportada en el perfil (`PUT /me/addresses/{type}`).
enum AddressType {
  billing,
  shipping;

  String get contractValue => name;
}

/// Dirección de facturación o envío (`openapi.yaml` → `Address`).
///
/// Solo en memoria; `toString()` no imprime datos personales (RNF-062).
@immutable
final class Address {
  const new({
    required this.firstName,
    required this.lastName,
    required this.company,
    required this.nationalId,
    required this.address1,
    required this.address2,
    required this.department,
    required this.city,
    required this.postcode,
    required this.phone,
  });

  final String firstName;
  final String lastName;
  final String company;
  final String? nationalId;
  final String address1;
  final String address2;
  final String department;
  final String city;
  final String postcode;
  final String? phone;

  @override
  String toString() => 'Address(<redacted>)';
}

/// Entrada validada para actualizar una dirección (`AddressInput`).
@immutable
final class AddressInput {
  const new({
    required this.firstName,
    required this.lastName,
    required this.address1,
    required this.department,
    required this.city,
    this.nationalId = '',
    this.company = '',
    this.address2 = '',
    this.postcode = '',
    this.phone = '',
  });

  final String nationalId;
  final String firstName;
  final String lastName;
  final String company;
  final String address1;
  final String address2;
  final String department;
  final String city;
  final String postcode;
  final String phone;

  @override
  String toString() => 'AddressInput(<redacted>)';
}

/// Perfil del cliente autenticado (`GET /me`, RF-104, RF-106).
///
/// Solo en memoria (RNF-062).
@immutable
final class UserProfile {
  const new({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.displayName,
    this.billing,
    this.shipping,
  });

  final int id;
  final String email;
  final String firstName;
  final String lastName;
  final String displayName;
  final Address? billing;
  final Address? shipping;

  @override
  String toString() => 'UserProfile(id: $id)';
}

/// Resultado de `POST /me/email`: rota la sesión y devuelve el perfil nuevo.
@immutable
final class EmailChangeResult {
  const new({required this.tokens, required this.profile});

  final SessionTokens tokens;
  final UserProfile profile;

  @override
  String toString() => 'EmailChangeResult(id: ${profile.id})';
}

enum AccountDeletionState {
  scheduled,
  completed,
  unknown;

  static AccountDeletionState fromContract(Object? raw) => switch (raw) {
    'scheduled' => scheduled,
    'completed' => completed,
    _ => unknown,
  };
}

/// Respuesta `202` de `POST /me/deletion` (RF-110).
@immutable
final class AccountDeletionStatus {
  const new({
    required this.requestId,
    required this.status,
    required this.completeBy,
  });

  final String requestId;
  final AccountDeletionState status;
  final DateTime? completeBy;

  @override
  String toString() => 'AccountDeletionStatus(status: ${status.name})';
}
