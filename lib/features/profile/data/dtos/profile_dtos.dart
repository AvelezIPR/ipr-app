import 'package:ipr_mobile/core/session/session_tokens.dart';

/// DTOs de perfil, direcciones, cambio de credenciales y eliminación de cuenta.
///
/// Ningún `toString` imprime contraseñas ni datos personales.
final class AddressDto {
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

  static AddressDto? tryFromJson(Object? json) {
    if (json == null) return null;
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Address no es un objeto');
    }
    return AddressDto(
      firstName: _str(json['firstName']),
      lastName: _str(json['lastName']),
      company: _str(json['company']),
      nationalId: _nullableStr(json['nationalId']),
      address1: _str(json['address1']),
      address2: _str(json['address2']),
      department: _str(json['department']),
      city: _str(json['city']),
      postcode: _str(json['postcode']),
      phone: _nullableStr(json['phone']),
    );
  }

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
  String toString() => 'AddressDto(<redacted>)';
}

final class UserProfileDto {
  const new({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.displayName,
    required this.billing,
    required this.shipping,
  });

  factory fromEnvelope(Object? json) => UserProfileDto.fromJson(_data(json));

  factory fromJson(Map<String, dynamic> data) {
    final id = data['id'];
    final email = data['email'];
    if (id is! int || id < 1 || email is! String || email.isEmpty) {
      throw const FormatException('UserProfile inválido');
    }
    return UserProfileDto(
      id: id,
      email: email,
      firstName: _str(data['firstName']),
      lastName: _str(data['lastName']),
      displayName: _str(data['displayName']),
      billing: AddressDto.tryFromJson(data['billing']),
      shipping: AddressDto.tryFromJson(data['shipping']),
    );
  }

  final int id;
  final String email;
  final String firstName;
  final String lastName;
  final String displayName;
  final AddressDto? billing;
  final AddressDto? shipping;

  @override
  String toString() => 'UserProfileDto(id: $id)';
}

final class UpdateProfileRequestDto {
  const new({required this.firstName, required this.lastName});

  final String firstName;
  final String lastName;

  Map<String, Object?> toJson() => {
    'firstName': firstName,
    'lastName': lastName,
  };

  @override
  String toString() => 'UpdateProfileRequestDto(<redacted>)';
}

final class ChangeEmailRequestDto {
  const new({required this.newEmail, required this.currentPassword});

  final String newEmail;
  final String currentPassword;

  Map<String, Object?> toJson() => {
    'newEmail': newEmail,
    'currentPassword': currentPassword,
  };

  @override
  String toString() => 'ChangeEmailRequestDto(<redacted>)';
}

final class ChangeEmailResponseDto {
  const new({required this.tokens, required this.user});

  factory fromEnvelope(Object? json) {
    final data = _data(json);
    return ChangeEmailResponseDto(
      tokens: SessionTokens.fromSessionJson(data['session']),
      user: UserProfileDto.fromJson(
        data['user'] is Map<String, dynamic>
            ? data['user']! as Map<String, dynamic>
            : throw const FormatException('falta user'),
      ),
    );
  }

  final SessionTokens tokens;
  final UserProfileDto user;

  @override
  String toString() => 'ChangeEmailResponseDto(id: ${user.id})';
}

final class ChangePasswordRequestDto {
  const new({required this.currentPassword, required this.newPassword});

  final String currentPassword;
  final String newPassword;

  Map<String, Object?> toJson() => {
    'currentPassword': currentPassword,
    'newPassword': newPassword,
  };

  @override
  String toString() => 'ChangePasswordRequestDto(<redacted>)';
}

final class ChangePasswordResponseDto {
  const new({required this.tokens});

  factory fromEnvelope(Object? json) {
    final data = _data(json);
    return ChangePasswordResponseDto(
      tokens: SessionTokens.fromSessionJson(data['session']),
    );
  }

  final SessionTokens tokens;

  @override
  String toString() => 'ChangePasswordResponseDto(<redacted>)';
}

final class AddressInputDto {
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

  Map<String, Object?> toJson() => {
    if (nationalId.isNotEmpty) 'nationalId': nationalId,
    'firstName': firstName,
    'lastName': lastName,
    if (company.isNotEmpty) 'company': company,
    'address1': address1,
    if (address2.isNotEmpty) 'address2': address2,
    'department': department,
    'city': city,
    if (postcode.isNotEmpty) 'postcode': postcode,
    if (phone.isNotEmpty) 'phone': phone,
  };

  @override
  String toString() => 'AddressInputDto(<redacted>)';
}

/// Cuerpo de `POST /me/deletion`: NUNCA incluye identificador de cuenta
/// (AC-110-13).
final class AccountDeletionRequestDto {
  const new({required this.currentPassword});

  final String currentPassword;

  Map<String, Object?> toJson() => {
    'currentPassword': currentPassword,
    'confirm': true,
  };

  @override
  String toString() => 'AccountDeletionRequestDto(<redacted>)';
}

final class AccountDeletionStatusDto {
  const new({
    required this.requestId,
    required this.status,
    required this.completeBy,
  });

  factory fromEnvelope(Object? json) {
    final data = _data(json);
    final requestId = data['requestId'];
    final status = data['status'];
    if (requestId is! String ||
        requestId.isEmpty ||
        status is! String ||
        status.isEmpty) {
      throw const FormatException('AccountDeletionStatus inválido');
    }
    return AccountDeletionStatusDto(
      requestId: requestId,
      status: status,
      completeBy: data['completeBy'],
    );
  }

  final String requestId;
  final String status;
  final Object? completeBy;

  @override
  String toString() => 'AccountDeletionStatusDto(status: $status)';
}

Map<String, dynamic> _data(Object? json) {
  if (json is! Map<String, dynamic>) {
    throw const FormatException('respuesta no es un objeto');
  }
  final data = json['data'];
  if (data is! Map<String, dynamic>) {
    throw const FormatException('falta data');
  }
  return data;
}

String _str(Object? value) => value is String ? value : '';

String? _nullableStr(Object? value) =>
    value is String && value.isNotEmpty ? value : null;
