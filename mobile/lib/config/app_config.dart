import 'package:flutter/foundation.dart';

class AppConfig {
  static const String fixedEmployeeName = 'Empleado Demo';

  static const List<String> categories = <String>[
    'Alimentación',
    'Transporte',
    'Papelería',
    'Alojamiento',
    'Otros',
  ];

  static const double autoApprovalLimitCop = 500000;

  static const String _definedBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get apiBaseUrl {
    final trimmed = _definedBaseUrl.trim();
    if (trimmed.isNotEmpty) {
      return trimmed.endsWith('/')
          ? trimmed.substring(0, trimmed.length - 1)
          : trimmed;
    }
    if (kIsWeb) {
      return 'http://localhost:5000';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5000';
    }
    return 'http://localhost:5000';
  }
}
