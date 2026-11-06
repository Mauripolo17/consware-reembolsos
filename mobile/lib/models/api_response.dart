class ApiError {
  final String? field;
  final String code;
  final String message;

  const ApiError({
    required this.field,
    required this.code,
    required this.message,
  });

  factory ApiError.fromJson(Map<String, dynamic> json) {
    final rawField = json['field']?.toString().trim();
    return ApiError(
      field: (rawField == null || rawField.isEmpty) ? null : rawField,
      code: (json['code']?.toString().trim().isNotEmpty ?? false)
          ? json['code'].toString().trim()
          : 'UNKNOWN_ERROR',
      message: (json['message']?.toString().trim().isNotEmpty ?? false)
          ? json['message'].toString().trim()
          : 'Ocurrió un error al procesar la solicitud.',
    );
  }
}

class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;
  final List<ApiError> errors;
  final String traceId;
  final int statusCode;

  const ApiResponse({
    required this.success,
    required this.message,
    required this.data,
    required this.errors,
    required this.traceId,
    required this.statusCode,
  });

  Map<String, String> get fieldErrors {
    final map = <String, String>{};
    for (final error in errors) {
      final fieldName = error.field;
      if (fieldName != null && fieldName.isNotEmpty && !map.containsKey(fieldName)) {
        map[fieldName] = error.message;
      }
    }
    return map;
  }

  List<ApiError> get generalErrors =>
      errors.where((e) => e.field == null || e.field!.isEmpty).toList();
}
