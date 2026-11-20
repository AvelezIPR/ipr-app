import 'package:ipr_mobile/features/support/domain/entities/pqrs.dart';

/// Campos validables del formulario PQRS.
enum PqrsField { name, email, phone, orderReference, message, dataPolicy }

/// Reglas locales de validación alineadas con `PqrsRequest` (`openapi.yaml` y
/// `AC-096-2`).
abstract final class PqrsValidation {
  static const int minNameLength = 3;
  static const int maxNameLength = 120;
  static const int maxEmailLength = 254;
  static const int maxOrderReferenceLength = 60;
  static const int minMessageLength = 1;
  static const int maxMessageLength = 1000;

  static final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
  static final RegExp _phonePattern = RegExp(r'^[\d\s+\-().]{7,20}$');

  static bool isValidName(String raw) {
    final trimmed = raw.trim();
    return trimmed.length >= minNameLength && trimmed.length <= maxNameLength;
  }

  static bool isValidEmail(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed.length > maxEmailLength) return false;
    return _emailPattern.hasMatch(trimmed);
  }

  static bool isValidPhone(String raw) {
    final trimmed = raw.trim();
    return _phonePattern.hasMatch(trimmed);
  }

  static bool isValidOrderReference(String raw) =>
      raw.trim().length <= maxOrderReferenceLength;

  static bool isValidMessage(String raw) {
    final trimmed = raw.trim();
    return trimmed.length >= minMessageLength && raw.length <= maxMessageLength;
  }

  static Map<PqrsField, String> validate({
    required String name,
    required String email,
    required String phone,
    required String orderReference,
    required String message,
    required bool acceptsDataPolicy,
  }) {
    final errors = <PqrsField, String>{};
    if (!isValidName(name)) errors[PqrsField.name] = 'invalid_name';
    if (!isValidEmail(email)) errors[PqrsField.email] = 'invalid_email';
    if (!isValidPhone(phone)) errors[PqrsField.phone] = 'invalid_phone';
    if (!isValidOrderReference(orderReference)) {
      errors[PqrsField.orderReference] = 'invalid_order_ref';
    }
    if (!isValidMessage(message)) {
      errors[PqrsField.message] = 'invalid_message';
    }
    if (!acceptsDataPolicy) {
      errors[PqrsField.dataPolicy] = 'policy_required';
    }
    return Map.unmodifiable(errors);
  }

  static PqrsSubmission normalizeSubmission({
    required PqrsType type,
    required String name,
    required String email,
    required String phone,
    required String orderReference,
    required String message,
    required bool acceptsDataPolicy,
  }) {
    final trimmedOrder = orderReference.trim();
    return PqrsSubmission(
      type: type,
      name: name.trim(),
      email: email.trim(),
      phone: phone.trim(),
      orderReference: trimmedOrder.isEmpty ? null : trimmedOrder,
      message: message,
      acceptsDataPolicy: acceptsDataPolicy,
    );
  }
}
