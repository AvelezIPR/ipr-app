import 'package:ipr_mobile/core/errors/app_failure.dart';

/// RFC 9457 Problem Details con las extensiones de IPR (`openapi.yaml`).
final class Problem {
  const new({
    required this.status,
    required this.code,
    this.title,
    this.detail,
    this.requestId,
    this.retryAfter,
    this.errors = const [],
  });

  /// Devuelve `null` si [json] no tiene la forma de un Problem con `code`.
  static Problem? tryParse(Object? json, {int? fallbackStatus}) {
    if (json is! Map<String, dynamic>) return null;
    final code = json['code'];
    if (code is! String || code.isEmpty) return null;
    final status = json['status'];
    final errors = <FieldError>[];
    final rawErrors = json['errors'];
    if (rawErrors is List<dynamic>) {
      for (final item in rawErrors) {
        if (item is Map<String, dynamic>) {
          errors.add(
            FieldError(
              field: '${item['field'] ?? ''}',
              code: '${item['code'] ?? ''}',
              message: '${item['message'] ?? ''}',
            ),
          );
        }
      }
    }
    final retryAfter = json['retryAfter'];
    return Problem(
      status: status is int ? status : (fallbackStatus ?? 0),
      code: code,
      title: json['title'] as String?,
      detail: json['detail'] as String?,
      requestId: json['requestId'] as String?,
      retryAfter: retryAfter is int ? retryAfter : null,
      errors: errors,
    );
  }

  final int status;
  final String code;
  final String? title;
  final String? detail;
  final String? requestId;
  final int? retryAfter;
  final List<FieldError> errors;
}
