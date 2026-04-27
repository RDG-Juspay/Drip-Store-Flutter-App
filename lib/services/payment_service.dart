import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class PaymentService {
  // Android emulator uses 10.0.2.2 to reach the host machine's localhost.
  // For a physical device, replace with your machine's LAN IP (e.g. 192.168.1.x).
  static const String _baseUrl = 'http://10.0.2.2:3001/api/payments';
  static const Duration _timeout = Duration(seconds: 15);

  /// Creates a Juspay payment session via the backend and returns
  /// { order_id, status, sdk_payload }.
  static Future<Map<String, dynamic>> createSession({
    required double amount,
    required String customerId,
    required String customerEmail,
    required String customerPhone,
    http.Client? client,
  }) async {
    final c = client ?? http.Client();
    final http.Response response;

    try {
      response = await c
          .post(
            Uri.parse('$_baseUrl/create-session'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'amount': amount,
              'customer_id': customerId,
              'customer_email': customerEmail,
              'customer_phone': customerPhone,
            }),
          )
          .timeout(_timeout);
    } on SocketException catch (e) {
      throw PaymentException('Connection failed: ${e.message}');
    } on TimeoutException {
      throw const PaymentException('Request timed out. Please try again.');
    } on http.ClientException catch (e) {
      throw PaymentException('Network error: ${e.message}');
    } catch (e) {
      throw PaymentException('Unexpected error: $e');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw PaymentException(
          data['error']?.toString() ?? 'Session creation failed');
    }
    return data;
  }

  /// Fetches the authoritative order status from the backend.
  /// Returns { order_id, status, amount, txn_id }.
  static Future<Map<String, dynamic>> verifyOrder(
    String orderId, {
    http.Client? client,
  }) async {
    final c = client ?? http.Client();
    final http.Response response;

    try {
      response = await c
          .get(Uri.parse('$_baseUrl/verify/$orderId'))
          .timeout(_timeout);
    } on SocketException {
      throw const PaymentException(
          'Network error during payment verification.');
    } on TimeoutException {
      throw const PaymentException('Verification timed out.');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw PaymentException(
          data['error']?.toString() ?? 'Order verification failed');
    }
    return data;
  }
}

class PaymentException implements Exception {
  final String message;
  const PaymentException(this.message);

  @override
  String toString() => message;
}
