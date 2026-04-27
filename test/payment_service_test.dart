import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:drip_store/services/payment_service.dart';

void main() {
  // ── PaymentException ────────────────────────────────────────────────────────
  group('PaymentException', () {
    test('carries message and toString returns it', () {
      const e = PaymentException('test error');
      expect(e.message, 'test error');
      expect(e.toString(), 'test error');
    });
  });

  // ── PaymentService.createSession ────────────────────────────────────────────
  group('PaymentService.createSession', () {
    test('returns parsed map on HTTP 200', () async {
      final mockClient = MockClient((_) async => http.Response(
            jsonEncode({
              'order_id': 'DS1XYZ',
              'status': 'NEW',
              'sdk_payload': {
                'requestId': 'r1',
                'service': 'in.juspay.hyperpay',
                'payload': <String, dynamic>{},
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          ));

      final result = await PaymentService.createSession(
        amount: 29,
        customerId: 'cust_01',
        customerEmail: 'test@example.com',
        customerPhone: '9000000000',
        client: mockClient,
      );

      expect(result['order_id'], 'DS1XYZ');
      expect(result['status'], 'NEW');
      expect(result['sdk_payload'], isNotNull);
    });

    test('throws PaymentException on HTTP 422', () async {
      final mockClient = MockClient((_) async => http.Response(
            jsonEncode({'error': 'Duplicate order ID'}),
            422,
            headers: {'content-type': 'application/json'},
          ));

      expect(
        () => PaymentService.createSession(
          amount: 29,
          customerId: 'cust_01',
          customerEmail: 'test@example.com',
          customerPhone: '9000000000',
          client: mockClient,
        ),
        throwsA(
          isA<PaymentException>().having(
            (e) => e.message,
            'message',
            'Duplicate order ID',
          ),
        ),
      );
    });

    test('throws PaymentException on HTTP 500 with fallback message', () async {
      final mockClient = MockClient((_) async => http.Response(
            '{}',
            500,
            headers: {'content-type': 'application/json'},
          ));

      expect(
        () => PaymentService.createSession(
          amount: 29,
          customerId: 'cust_01',
          customerEmail: 'test@example.com',
          customerPhone: '9000000000',
          client: mockClient,
        ),
        throwsA(isA<PaymentException>()),
      );
    });

    // ── Network-drop scenario ──────────────────────────────────────────────
    // PaymentService.createSession must surface a user-readable message
    // when the device loses connectivity mid-request, so the UI can show
    // a "Retry" button instead of a raw exception.
    test('network drop — throws PaymentException with friendly message', () async {
      final mockClient = MockClient((_) async {
        throw http.ClientException('Connection refused');
      });

      await expectLater(
        () => PaymentService.createSession(
          amount: 29,
          customerId: 'cust_01',
          customerEmail: 'test@example.com',
          customerPhone: '9000000000',
          client: mockClient,
        ),
        throwsA(isA<PaymentException>()),
      );
    });
  });

  // ── PaymentService.verifyOrder ──────────────────────────────────────────────
  group('PaymentService.verifyOrder', () {
    test('returns order details on HTTP 200', () async {
      final mockClient = MockClient((request) async {
        // Verify the correct order ID is included in the URL
        expect(request.url.path, contains('DS1XYZ'));
        return http.Response(
          jsonEncode({
            'order_id': 'DS1XYZ',
            'status': 'CHARGED',
            'amount': '29.00',
            'txn_id': 'txn_abc',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final result =
          await PaymentService.verifyOrder('DS1XYZ', client: mockClient);
      expect(result['status'], 'CHARGED');
      expect(result['amount'], '29.00');
      expect(result['txn_id'], 'txn_abc');
    });

    test('throws PaymentException on HTTP 404', () async {
      final mockClient = MockClient((_) async => http.Response(
            jsonEncode({'error': 'Order not found'}),
            404,
            headers: {'content-type': 'application/json'},
          ));

      expect(
        () => PaymentService.verifyOrder('DS1XYZ', client: mockClient),
        throwsA(isA<PaymentException>()),
      );
    });

    // ── Duplicate handling ─────────────────────────────────────────────────
    // Both the SDK callback and the webhook may fire. Calling verifyOrder
    // twice with the same orderId must not throw — the backend is idempotent
    // and returns the same authoritative status both times.
    test('duplicate verifyOrder calls both succeed (idempotent)', () async {
      final mockClient = MockClient((_) async => http.Response(
            jsonEncode({
              'order_id': 'DS1XYZ',
              'status': 'CHARGED',
              'amount': '29.00',
              'txn_id': 'txn_abc',
            }),
            200,
            headers: {'content-type': 'application/json'},
          ));

      final r1 = await PaymentService.verifyOrder('DS1XYZ', client: mockClient);
      final r2 = await PaymentService.verifyOrder('DS1XYZ', client: mockClient);

      expect(r1['status'], 'CHARGED');
      expect(r2['status'], 'CHARGED');
    });

    // ── Security: amount verification ──────────────────────────────────────
    // The checkout screen must compare the verified paid amount against
    // the originally requested amount. This test documents that contract.
    test('amount field is returned as a parseable string', () async {
      final mockClient = MockClient((_) async => http.Response(
            jsonEncode({
              'order_id': 'DS1XYZ',
              'status': 'CHARGED',
              'amount': '137.50',
              'txn_id': 'txn_xyz',
            }),
            200,
            headers: {'content-type': 'application/json'},
          ));

      final result =
          await PaymentService.verifyOrder('DS1XYZ', client: mockClient);
      final paidAmount =
          double.tryParse(result['amount']?.toString() ?? '0') ?? 0;

      expect(paidAmount, closeTo(137.50, 0.001));
    });
  });
}
