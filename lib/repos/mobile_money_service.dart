/// This service handles integration with the mobile money payment mediator API.
/// It provides methods to initiate payments and check payment status using RESTful HTTP calls.

import 'dart:convert';
import 'package:http/http.dart' as http;

class MobileMoneyService {
  final String baseUrl;
  final http.Client httpClient;

  MobileMoneyService({
    required this.baseUrl,
    http.Client? httpClient,
  }) : httpClient = httpClient ?? http.Client();

  /// Initiates a payment request to the mobile money mediator.
  /// Returns a map containing the response data including transaction IDs and messages.
  Future<Map<String, dynamic>> initiatePayment({
    required String phoneNumber,
    required double totalAmount,
    String? referenceID,
    String? merchantTransactionID,
    Map<String, dynamic>? extraPayload,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/payment/request');

    final body = <String, dynamic>{
      'phoneNumber': phoneNumber,
      'totalAmount': totalAmount.toStringAsFixed(2),
    };

    if (referenceID != null) {
      body['referenceID'] = referenceID;
    }
    if (merchantTransactionID != null) {
      body['merchantTransactionID'] = merchantTransactionID;
    }
    if (extraPayload != null) {
      body.addAll(extraPayload);
    }

    final response = await httpClient.post(uri, body: body);

    if (response.statusCode != 200) {
      throw Exception('Payment initiation failed: ${response.body}');
    }

    final Map<String, dynamic> jsonResponse = json.decode(response.body);
    return jsonResponse;
  }

  /// Checks the payment status for a given transaction ID.
  /// Returns a map containing the status response.
  Future<Map<String, dynamic>> checkPaymentStatus({
    required String transactionID,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/payment/status/$transactionID');

    final response = await httpClient.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Payment status check failed: ${response.body}');
    }

    final Map<String, dynamic> jsonResponse = json.decode(response.body);
    return jsonResponse;
  }
}
