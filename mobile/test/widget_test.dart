import 'dart:async';
import 'dart:convert';
import 'package:consware_reembolsos/main.dart';
import 'package:consware_reembolsos/models/reimbursement.dart';
import 'package:consware_reembolsos/services/reimbursement_api_service.dart';
import 'package:consware_reembolsos/utils/formatters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('InputValidators.validateAmount', () {
    test('accepts valid integer and decimal amounts', () {
      final r1 = InputValidators.validateAmount('499999');
      expect(r1.isValid, isTrue);
      expect(r1.value, 499999);

      final r2 = InputValidators.validateAmount('500000.01');
      expect(r2.isValid, isTrue);
      expect(r2.value, 500000.01);
    });

    test('rejects 3-digit grouping like 500.000 so it is never read as 500', () {
      final r = InputValidators.validateAmount('500.000');
      expect(r.isValid, isFalse);
      expect(r.error, contains('500000'));
    });

    test('rejects excess precision (>2 decimals), zero and negative values', () {
      expect(InputValidators.validateAmount('100.123').isValid, isFalse);
      expect(InputValidators.validateAmount('0').isValid, isFalse);
      expect(InputValidators.validateAmount('-50').isValid, isFalse);
    });

    test('accepts max safe UI amount 9999999999.99 and rejects large unsafe inputs', () {
      final maxSafe = InputValidators.validateAmount('9999999999.99');
      expect(maxSafe.isValid, isTrue);
      expect(maxSafe.value, 9999999999.99);

      final overSafe = InputValidators.validateAmount('10000000000');
      expect(overSafe.isValid, isFalse);
      expect(overSafe.error, contains('9.999.999.999,99'));

      final unsafeDoublePrecision = InputValidators.validateAmount('9999999999999999.99');
      expect(unsafeDoublePrecision.isValid, isFalse);
      expect(unsafeDoublePrecision.error, contains('9.999.999.999,99'));
    });
  });

  group('ReimbursementApiService strict envelope & shape validation', () {
    test('rejects success=true when data is an object instead of a list', () async {
      final client = MockClient((_) async {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'success': true,
            'message': 'OK',
            'data': <String, dynamic>{'unexpected': true},
            'errors': <dynamic>[],
            'traceId': 't-1',
          }),
          200,
        );
      });
      final service = ReimbursementApiService(client: client, baseUrl: 'http://localhost:5000');
      final response = await service.getReimbursements();
      expect(response.success, isFalse);
      expect(response.data, isNull);
    });

    test('rejects list when any element is malformed instead of dropping it silently', () async {
      final client = MockClient((_) async {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'success': true,
            'message': 'OK',
            'data': <dynamic>[
              <String, dynamic>{
                'id': 1,
                'employeeName': 'Empleado Demo',
                'amount': 100000,
                'category': 'Transporte',
                'description': 'Taxi',
                'status': 'Approved',
                'rejectionReason': null,
                'createdAtUtc': '2026-11-06T10:00:00Z',
                'decidedAtUtc': '2026-11-06T10:00:00Z',
              },
              <String, dynamic>{'id': 'bad-id'},
            ],
            'errors': <dynamic>[],
            'traceId': 't-2',
          }),
          200,
        );
      });
      final service = ReimbursementApiService(client: client, baseUrl: 'http://localhost:5000');
      final response = await service.getReimbursements();
      expect(response.success, isFalse);
      expect(response.data, isNull);
    });

    test('rejects inconsistent envelope where success=true but HTTP status is 500', () async {
      final client = MockClient((_) async {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'success': true,
            'message': 'Inconsistent',
            'data': <dynamic>[],
            'errors': <dynamic>[],
            'traceId': 't-3',
          }),
          500,
        );
      });
      final service = ReimbursementApiService(client: client, baseUrl: 'http://localhost:5000');
      final response = await service.getReimbursements();
      expect(response.success, isFalse);
      expect(response.data, isNull);
    });
  });

  group('EmployeeHomeScreen UI & API integration', () {
    testWidgets('displays requests, rejection reason, and creates new expense',
        (WidgetTester tester) async {
      final records = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 10,
          'employeeName': 'Empleado Demo',
          'amount': 650000,
          'category': 'Alojamiento',
          'description': 'Hotel conferencia anual en Medellín',
          'status': 'Rejected',
          'rejectionReason': 'Excede tarifa corporativa sin preaprobación.',
          'createdAtUtc': '2026-11-06T12:00:00Z',
          'decidedAtUtc': '2026-11-06T13:00:00Z',
        },
        <String, dynamic>{
          'id': 9,
          'employeeName': 'Empleado Demo',
          'amount': 120000,
          'category': 'Transporte',
          'description': 'Taxis aeropuerto',
          'status': 'Approved',
          'rejectionReason': null,
          'createdAtUtc': '2026-11-06T10:00:00Z',
          'decidedAtUtc': '2026-11-06T10:00:00Z',
        },
      ];

      final mockClient = MockClient((http.Request request) async {
        if (request.method == 'GET' &&
            request.url.path == '/api/reimbursements') {
          return http.Response.bytes(
            utf8.encode(
              jsonEncode(<String, dynamic>{
                'success': true,
                'message': 'Operación completada.',
                'data': records,
                'errors': <dynamic>[],
                'traceId': 'test-trace-get',
              }),
            ),
            200,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }

        if (request.method == 'POST' &&
            request.url.path == '/api/reimbursements') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final created = <String, dynamic>{
            'id': 11,
            'employeeName': body['employeeName'],
            'amount': body['amount'],
            'category': body['category'],
            'description': body['description'],
            'status': (body['amount'] as num) <= 500000 ? 'Approved' : 'Pending',
            'rejectionReason': null,
            'createdAtUtc': '2026-11-06T14:00:00Z',
            'decidedAtUtc': (body['amount'] as num) <= 500000
                ? '2026-11-06T14:00:00Z'
                : null,
          };
          records.insert(0, created);
          return http.Response.bytes(
            utf8.encode(
              jsonEncode(<String, dynamic>{
                'success': true,
                'message': 'Solicitud creada.',
                'data': created,
                'errors': <dynamic>[],
                'traceId': 'test-trace-post',
              }),
            ),
            201,
            headers: <String, String>{'content-type': 'application/json'},
          );
        }

        return http.Response('Not found', 404);
      });

      final service = ReimbursementApiService(
        client: mockClient,
        baseUrl: 'http://localhost:5000',
      );

      await tester.pumpWidget(ConswareEmployeeApp(apiService: service));
      await tester.pumpAndSettle();

      // Verify existing requests and rejection reason are rendered
      expect(find.text('Hotel conferencia anual en Medellín'), findsOneWidget);
      expect(
        find.text('Excede tarifa corporativa sin preaprobación.'),
        findsOneWidget,
      );
      expect(find.text('Rechazado'), findsOneWidget);
      expect(find.text('Aprobado'), findsOneWidget);

      // Navigate to Nuevo gasto tab
      await tester.tap(find.text('Nuevo gasto').first);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('amount_input')),
        '320000',
      );
      await tester.enterText(
        find.byKey(const Key('description_input')),
        'Almuerzo con equipo de cliente',
      );
      await tester.pumpAndSettle();

      final submitFinder = find.byKey(const Key('submit_reimbursement_button'));
      await tester.ensureVisible(submitFinder);
      await tester.pumpAndSettle();
      await tester.tap(submitFinder);
      await tester.pumpAndSettle();

      // Should return to requests list and display the new request
      expect(find.text('Almuerzo con equipo de cliente'), findsOneWidget);
    });

    testWidgets('shows API-down error state and recovers on retry',
        (WidgetTester tester) async {
      bool shouldFail = true;
      final mockClient = MockClient((http.Request request) async {
        if (shouldFail) {
          throw Exception('Connection refused');
        }
        return http.Response.bytes(
          utf8.encode(
            jsonEncode(<String, dynamic>{
              'success': true,
              'message': 'Operación completada.',
              'data': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 1,
                  'employeeName': 'Empleado Demo',
                  'amount': 95000,
                  'category': 'Papelería',
                  'description': 'Compra de carpetas corporativas',
                  'status': 'Approved',
                  'rejectionReason': null,
                  'createdAtUtc': '2026-11-06T12:00:00Z',
                  'decidedAtUtc': '2026-11-06T12:00:00Z',
                },
              ],
              'errors': <dynamic>[],
              'traceId': 'trace-ok',
            }),
          ),
          200,
        );
      });

      final service = ReimbursementApiService(
        client: mockClient,
        baseUrl: 'http://localhost:5000',
      );

      await tester.pumpWidget(ConswareEmployeeApp(apiService: service));
      await tester.pumpAndSettle();

      expect(find.text('No pudimos cargar las solicitudes'), findsOneWidget);

      shouldFail = false;
      final retryFinder = find.byKey(const Key('retry_requests_button'));
      await tester.ensureVisible(retryFinder);
      await tester.pumpAndSettle();
      await tester.tap(retryFinder);
      await tester.pumpAndSettle();

      expect(find.text('Compra de carpetas corporativas'), findsOneWidget);
      expect(ReimbursementStatus.approved.spanishLabel, 'Aprobado');
    });

    testWidgets('ignores out-of-order stale filter responses',
        (WidgetTester tester) async {
      final pendingCompleter = Completer<http.Response>();
      final approvedCompleter = Completer<http.Response>();

      final mockClient = MockClient((http.Request request) async {
        final statusParam = request.url.queryParameters['status'];
        if (statusParam == 'Pending') {
          return pendingCompleter.future;
        }
        if (statusParam == 'Approved') {
          return approvedCompleter.future;
        }
        return http.Response.bytes(
          utf8.encode(
            jsonEncode(<String, dynamic>{
              'success': true,
              'message': 'Operación completada.',
              'data': <Map<String, dynamic>>[],
              'errors': <dynamic>[],
              'traceId': 'trace-initial',
            }),
          ),
          200,
        );
      });

      final service = ReimbursementApiService(
        client: mockClient,
        baseUrl: 'http://localhost:5000',
      );

      await tester.pumpWidget(ConswareEmployeeApp(apiService: service));
      await tester.pumpAndSettle();

      // Select Pendientes first via the enum-backed dropdown, then Aprobadas before Pendientes finishes
      final dropdownFinder = find.byKey(const Key('status_filter_dropdown'));
      await tester.tap(dropdownFinder);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pendientes').last);
      await tester.pump();

      await tester.tap(dropdownFinder);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aprobadas').last);
      await tester.pump();

      // Complete Approved first
      approvedCompleter.complete(
        http.Response.bytes(
          utf8.encode(
            jsonEncode(<String, dynamic>{
              'success': true,
              'message': 'Operación completada.',
              'data': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 20,
                  'employeeName': 'Empleado Demo',
                  'amount': 150000,
                  'category': 'Transporte',
                  'description': 'Registro aprobado vigente',
                  'status': 'Approved',
                  'rejectionReason': null,
                  'createdAtUtc': '2026-11-06T12:00:00Z',
                  'decidedAtUtc': '2026-11-06T12:00:00Z',
                },
              ],
              'errors': <dynamic>[],
              'traceId': 'trace-approved',
            }),
          ),
          200,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Registro aprobado vigente'), findsOneWidget);

      // Now complete stale Pending response after Approved already rendered
      pendingCompleter.complete(
        http.Response.bytes(
          utf8.encode(
            jsonEncode(<String, dynamic>{
              'success': true,
              'message': 'Operación completada.',
              'data': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 21,
                  'employeeName': 'Empleado Demo',
                  'amount': 900000,
                  'category': 'Alojamiento',
                  'description': 'Registro pendiente obsoleto',
                  'status': 'Pending',
                  'rejectionReason': null,
                  'createdAtUtc': '2026-11-06T12:00:00Z',
                  'decidedAtUtc': null,
                },
              ],
              'errors': <dynamic>[],
              'traceId': 'trace-pending-stale',
            }),
          ),
          200,
        ),
      );
      await tester.pumpAndSettle();

      // Stale Pending response must be ignored; Approved item remains visible
      expect(find.text('Registro aprobado vigente'), findsOneWidget);
      expect(find.text('Registro pendiente obsoleto'), findsNothing);
    });
  });
}
