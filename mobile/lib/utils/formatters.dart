import 'package:intl/intl.dart';

class Formatters {
  static final NumberFormat _copInteger = NumberFormat.decimalPattern('es_CO');
  static final NumberFormat _copDecimals = NumberFormat('#,##0.00', 'es_CO');

  static String formatCop(double amount) {
    final hasDecimals = (amount - amount.truncateToDouble()).abs() > 0.0001;
    final formatted = hasDecimals
        ? _copDecimals.format(amount)
        : _copInteger.format(amount);
    return '\$$formatted COP';
  }

  static String formatDateTime(DateTime utcDate) {
    final local = utcDate.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year;
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/$year · $hour:$minute';
  }
}

class AmountValidationResult {
  final double? value;
  final String? error;

  const AmountValidationResult({this.value, this.error});

  bool get isValid => value != null && error == null;
}

class InputValidators {
  /// Safe UI maximum in COP (9,999,999,999.99 COP = 999,999,999,999 cents),
  /// well within IEEE-754 double exact integer precision (2^53 - 1) so no valid
  /// input string can ever lose precision or round silently when serialized.
  static const int maxSafeCents = 999999999999; // 9999999999.99 COP
  static const double maxSafeAmountCop = 9999999999.99;

  /// Parses an explicit numeric COP input string (digits with optional `.` or `,` decimal point).
  /// Validates exact integer cents before conversion and never silently strips grouping separators.
  static AmountValidationResult validateAmount(String? raw) {
    final trimmed = (raw ?? '').trim();
    if (trimmed.isEmpty) {
      return const AmountValidationResult(
        error: 'Ingresa el monto del reembolso en COP.',
      );
    }

    if (trimmed.contains(' ')) {
      return const AmountValidationResult(
        error: 'Escribe el monto sin espacios ni símbolos (ej. 125000 o 125000.50).',
      );
    }

    final dotCount = '.'.allMatches(trimmed).length;
    final commaCount = ','.allMatches(trimmed).length;

    if (dotCount + commaCount > 1) {
      return const AmountValidationResult(
        error:
            'No uses puntos ni comas para separar miles. Escribe solo dígitos (ej. 500000).',
      );
    }

    final normalized = trimmed.replaceAll(',', '.');
    final validPattern = RegExp(r'^-?\d+(\.\d+)?$');
    if (!validPattern.hasMatch(normalized)) {
      return const AmountValidationResult(
        error:
            'Ingresa un número válido sin símbolos de moneda ni separadores de miles.',
      );
    }

    if (normalized.startsWith('-')) {
      return const AmountValidationResult(
        error: 'El monto debe ser mayor a cero.',
      );
    }

    final parts = normalized.split('.');
    final integerPart = parts[0];
    final fractionPart = parts.length > 1 ? parts[1] : '';

    if (normalized.contains('.')) {
      // Detect suspicious 3-digit grouping like 500.000
      if (fractionPart.length == 3) {
        return const AmountValidationResult(
          error:
              'Usa hasta 2 decimales y no uses puntos de miles (para quinientos mil escribe 500000).',
        );
      }
      if (fractionPart.length > 2) {
        return const AmountValidationResult(
          error: 'El monto puede tener máximo 2 decimales.',
        );
      }
    }

    final significantInt = integerPart.replaceFirst(RegExp(r'^0+'), '');
    if (significantInt.length > 10) {
      return const AmountValidationResult(
        error:
            'El monto supera el máximo permitido en la aplicación (\$9.999.999.999,99 COP).',
      );
    }

    final intPesos = significantInt.isEmpty ? 0 : int.tryParse(significantInt);
    final paddedFraction = fractionPart.padRight(2, '0');
    final intCents = paddedFraction.isEmpty ? 0 : int.tryParse(paddedFraction);

    if (intPesos == null || intCents == null) {
      return const AmountValidationResult(
        error: 'Ingresa un monto numérico válido.',
      );
    }

    final totalCents = (intPesos * 100) + intCents;
    if (totalCents <= 0) {
      return const AmountValidationResult(
        error: 'El monto debe ser mayor a cero.',
      );
    }

    if (totalCents > maxSafeCents) {
      return const AmountValidationResult(
        error:
            'El monto supera el máximo permitido en la aplicación (\$9.999.999.999,99 COP).',
      );
    }

    final exactValue = totalCents / 100.0;
    return AmountValidationResult(value: exactValue);
  }

  static String? validateCategory(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return 'Selecciona una categoría para el gasto.';
    }
    if (trimmed.length > 60) {
      return 'La categoría no puede superar los 60 caracteres.';
    }
    return null;
  }

  static String? validateDescription(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return 'Describe el motivo y detalle del gasto.';
    }
    if (trimmed.length > 500) {
      return 'La descripción no puede superar los 500 caracteres.';
    }
    return null;
  }
}
