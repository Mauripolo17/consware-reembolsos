import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/api_response.dart';
import '../models/reimbursement.dart';

class ReimbursementApiService {
  final http.Client _client;
  final String baseUrl;
  final Duration timeout;

  ReimbursementApiService({
    http.Client? client,
    String? baseUrl,
    this.timeout = const Duration(seconds: 10),
  })  : _client = client ?? http.Client(),
        baseUrl = (baseUrl ?? AppConfig.apiBaseUrl).trim();

  Uri _buildUri(String path, [Map<String, String>? queryParameters]) {
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final uri = Uri.parse('$normalizedBase$path');
    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }
    return uri.replace(queryParameters: queryParameters);
  }

  Future<ApiResponse<List<Reimbursement>>> getReimbursements({
    String employeeName = AppConfig.fixedEmployeeName,
    ReimbursementStatus? status,
  }) async {
    final query = <String, String>{};
    if (employeeName.trim().isNotEmpty) {
      query['employeeName'] = employeeName.trim();
    }
    if (status != null) {
      query['status'] = status.wireValue;
    }

    final uri = _buildUri('/api/reimbursements', query);
    try {
      final response = await _client.get(
        uri,
        headers: const <String, String>{
          'Accept': 'application/json',
        },
      ).timeout(timeout);

      return _decodeResponse<List<Reimbursement>>(
        response,
        (dynamic rawData) {
          if (rawData is! List) {
            throw const FormatException('Expected a JSON list in data');
          }
          final result = <Reimbursement>[];
          for (final dynamic item in rawData) {
            if (item is! Map<String, dynamic>) {
              throw const FormatException('Invalid item in reimbursement list');
            }
            result.add(Reimbursement.fromJson(item));
          }
          return result;
        },
      );
    } on TimeoutException {
      return const ApiResponse<List<Reimbursement>>(
        success: false,
        message:
            'El servidor tardó demasiado en responder al cargar las solicitudes. Intenta nuevamente.',
        data: null,
        errors: <ApiError>[
          ApiError(
            field: null,
            code: 'NETWORK_TIMEOUT',
            message:
                'Tiempo de espera agotado al conectar con el servidor de reembolsos.',
          ),
        ],
        traceId: 'local-timeout',
        statusCode: 0,
      );
    } catch (_) {
      return const ApiResponse<List<Reimbursement>>(
        success: false,
        message:
            'No fue posible conectar con el servidor de reembolsos. Verifica que la API esté activa e intenta nuevamente.',
        data: null,
        errors: <ApiError>[
          ApiError(
            field: null,
            code: 'NETWORK_ERROR',
            message:
                'No se pudo establecer conexión con el servidor de reembolsos.',
          ),
        ],
        traceId: 'local-network-error',
        statusCode: 0,
      );
    }
  }

  Future<ApiResponse<Reimbursement>> createReimbursement(
    CreateReimbursementInput input,
  ) async {
    final uri = _buildUri('/api/reimbursements');
    try {
      final response = await _client
          .post(
            uri,
            headers: const <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(input.toJson()),
          )
          .timeout(timeout);

      return _decodeResponse<Reimbursement>(
        response,
        (dynamic rawData) {
          if (rawData is! Map<String, dynamic>) {
            throw const FormatException('Expected a JSON object in data');
          }
          return Reimbursement.fromJson(rawData);
        },
      );
    } on TimeoutException {
      return const ApiResponse<Reimbursement>(
        success: false,
        message:
            'Tiempo de espera agotado. Es posible que la solicitud haya sido procesada; revisa Mis solicitudes antes de volver a enviar.',
        data: null,
        errors: <ApiError>[
          ApiError(
            field: null,
            code: 'NETWORK_TIMEOUT',
            message:
                'La respuesta tardó demasiado. Verifica en la lista si el gasto ya quedó registrado antes de reintentar.',
          ),
        ],
        traceId: 'local-timeout',
        statusCode: 0,
      );
    } catch (_) {
      return const ApiResponse<Reimbursement>(
        success: false,
        message:
            'No se pudo conectar con el servidor para registrar el reembolso. Tus datos siguen en el formulario para que puedas reintentar.',
        data: null,
        errors: <ApiError>[
          ApiError(
            field: null,
            code: 'NETWORK_ERROR',
            message:
                'Error de conexión con la API. Verifica que el servicio esté disponible.',
          ),
        ],
        traceId: 'local-network-error',
        statusCode: 0,
      );
    }
  }

  ApiResponse<T> _decodeResponse<T>(
    http.Response response,
    T? Function(dynamic rawData) parseData,
  ) {
    try {
      final bodyText = utf8.decode(response.bodyBytes);
      final dynamic decoded = jsonDecode(bodyText);
      if (decoded is! Map<String, dynamic>) {
        return ApiResponse<T>(
          success: false,
          message: 'El servidor devolvió un formato inesperado.',
          data: null,
          errors: const <ApiError>[
            ApiError(
              field: null,
              code: 'INVALID_RESPONSE',
              message: 'La respuesta del servidor no tiene el formato esperado.',
            ),
          ],
          traceId: 'invalid-envelope',
          statusCode: response.statusCode,
        );
      }

      final rawSuccess = decoded['success'];
      if (rawSuccess is! bool) {
        return ApiResponse<T>(
          success: false,
          message: 'El servidor devolvió un formato inesperado.',
          data: null,
          errors: const <ApiError>[
            ApiError(
              field: null,
              code: 'INVALID_RESPONSE',
              message: 'La respuesta del servidor no contiene un estado válido.',
            ),
          ],
          traceId: 'invalid-envelope',
          statusCode: response.statusCode,
        );
      }

      final bool isHttp2xx =
          response.statusCode >= 200 && response.statusCode < 300;
      if (rawSuccess != isHttp2xx) {
        return ApiResponse<T>(
          success: false,
          message: 'La respuesta del servidor fue inconsistente (HTTP ${response.statusCode}).',
          data: null,
          errors: const <ApiError>[
            ApiError(
              field: null,
              code: 'INVALID_RESPONSE',
              message:
                  'El estado HTTP no coincide con el resultado reportado por el servidor.',
            ),
          ],
          traceId: 'status-mismatch',
          statusCode: response.statusCode,
        );
      }

      final bool success = rawSuccess && isHttp2xx;
      final String message =
          (decoded['message']?.toString().trim().isNotEmpty ?? false)
              ? decoded['message'].toString().trim()
              : (success
                  ? 'Operación completada.'
                  : 'No se pudo procesar la solicitud.');
      final String traceId =
          (decoded['traceId']?.toString().trim().isNotEmpty ?? false)
              ? decoded['traceId'].toString().trim()
              : 'missing-trace-id';

      final rawErrors = decoded['errors'];
      if (rawErrors is! List) {
        return ApiResponse<T>(
          success: false,
          message: 'El servidor devolvió una estructura de errores inválida.',
          data: null,
          errors: const <ApiError>[
            ApiError(
              field: null,
              code: 'INVALID_RESPONSE',
              message: 'El campo errors de la respuesta no es una lista válida.',
            ),
          ],
          traceId: traceId,
          statusCode: response.statusCode,
        );
      }

      final List<ApiError> errors = <ApiError>[];
      for (final dynamic item in rawErrors) {
        if (item is! Map<String, dynamic>) {
          return ApiResponse<T>(
            success: false,
            message: 'El servidor devolvió un detalle de error inválido.',
            data: null,
            errors: const <ApiError>[
              ApiError(
                field: null,
                code: 'INVALID_RESPONSE',
                message: 'Formato de error inesperado en la respuesta.',
              ),
            ],
            traceId: traceId,
            statusCode: response.statusCode,
          );
        }
        errors.add(ApiError.fromJson(item));
      }

      if (success && decoded['data'] == null) {
        return ApiResponse<T>(
          success: false,
          message: 'El servidor no incluyó los datos esperados en la respuesta.',
          data: null,
          errors: const <ApiError>[
            ApiError(
              field: null,
              code: 'INVALID_RESPONSE',
              message: 'Respuesta exitosa sin datos adjuntos.',
            ),
          ],
          traceId: traceId,
          statusCode: response.statusCode,
        );
      }

      final T? parsedData =
          success ? parseData(decoded['data']) : null;

      return ApiResponse<T>(
        success: success,
        message: message,
        data: parsedData,
        errors: errors,
        traceId: traceId,
        statusCode: response.statusCode,
      );
    } catch (_) {
      return ApiResponse<T>(
        success: false,
        message:
            'No se pudo interpretar la respuesta del servidor (código HTTP ${response.statusCode}).',
        data: null,
        errors: const <ApiError>[
          ApiError(
            field: null,
            code: 'DECODE_ERROR',
            message:
                'Respuesta inválida recibida desde el servidor de reembolsos.',
          ),
        ],
        traceId: 'decode-error',
        statusCode: response.statusCode,
      );
    }
  }
}
