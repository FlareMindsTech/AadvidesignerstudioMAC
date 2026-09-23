import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../config/api_config.dart';
import 'storage_service.dart';
import 'http_interceptor_service.dart';

class PaymentService {
  // Initiate One-Time Payment
  static Future<Map<String, dynamic>> initiatePayment({
    required String courseId,
  }) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw PaymentServiceException('Not authenticated. Please login again.');
      }

      final body = {
        'courseId': courseId,
      };

      debugPrint("Initiate Payment API Url: ${ApiConfig.initiatePaymentEndpoint}");
      debugPrint("Initiate Payment Body: ${jsonEncode(body)}");

      final response = await http
          .post(
            Uri.parse(ApiConfig.initiatePaymentEndpoint),
            headers: ApiConfig.getAuthHeaders(token),
            body: jsonEncode(body),
          )
          .timeout(ApiConfig.timeout);

      // Check for invalid token and handle auto-logout
      await HttpInterceptorService.checkResponseAndHandleAuth(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        debugPrint('Initiate Payment Success: ${response.body}');
        return Map<String, dynamic>.from(data);
      } else {
        debugPrint('Error Initiate Payment Status: ${response.statusCode}');
        debugPrint('Error Initiate Payment Body: ${response.body}');
        final error = jsonDecode(response.body);
        throw PaymentServiceException(
          error['message'] ?? 'Failed to initiate payment. Please try again.',
        );
      }
    } catch (e) {
      if (e is PaymentServiceException) {
        rethrow;
      }
      debugPrint('Initiate payment error: $e');
      throw PaymentServiceException(
          'Network error. Please check your connection.');
    }
  }

  // Initiate Subscription (EMI)
  static Future<Map<String, dynamic>> initiateSubscription({
    required String courseId,
    required int totalCount, // Number of installments
    String? emiPlanId,
  }) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw PaymentServiceException('Not authenticated. Please login again.');
      }

      final body = {
        'courseId': courseId,
        'type': 'subscription',
        'total_count': totalCount,
        'emiPlanId': emiPlanId,
        'paymentOption': 'emi', // Added to assist backend routing
      };

      debugPrint("Initiate Subscription API Url: ${ApiConfig.initiatePaymentEndpoint}");
      debugPrint("Initiate Subscription Body: ${jsonEncode(body)}");

      final response = await http
          .post(
            Uri.parse(ApiConfig.initiatePaymentEndpoint),
            headers: ApiConfig.getAuthHeaders(token),
            body: jsonEncode(body),
          )
          .timeout(ApiConfig.timeout);

      // Check for invalid token and handle auto-logout
      await HttpInterceptorService.checkResponseAndHandleAuth(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        debugPrint('Initiate Subscription Success: ${response.body}');
        return Map<String, dynamic>.from(data);
      } else {
        debugPrint('Error Initiate Subscription Status: ${response.statusCode}');
        debugPrint('Error Initiate Subscription Body: ${response.body}');
        final error = jsonDecode(response.body);
        throw PaymentServiceException(
          error['message'] ?? 'Failed to initiate subscription. Please try again.',
        );
      }
    } catch (e) {
      if (e is PaymentServiceException) {
        rethrow;
      }
      debugPrint('Initiate subscription error: $e');
      throw PaymentServiceException(
          'Network error. Please check your connection.');
    }
  }

  // Verify Payment
  static Future<Map<String, dynamic>> verifyPayment({
    required String courseId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw PaymentServiceException('Not authenticated. Please login again.');
      }

      final body = {
        'courseId': courseId,
        'razorpay_order_id': razorpayOrderId,
        'razorpay_payment_id': razorpayPaymentId,
        'razorpay_signature': razorpaySignature,
      };

      debugPrint("Verify Payment API Url: ${ApiConfig.verifyPaymentEndpoint}");
      debugPrint("Verify Payment Body: ${jsonEncode(body)}");

      final response = await http
          .post(
            Uri.parse(ApiConfig.verifyPaymentEndpoint),
            headers: ApiConfig.getAuthHeaders(token),
            body: jsonEncode(body),
          )
          .timeout(ApiConfig.timeout);

      // Check for invalid token and handle auto-logout
      await HttpInterceptorService.checkResponseAndHandleAuth(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        debugPrint('Verify Payment Success: ${response.body}');
        return Map<String, dynamic>.from(data);
      } else {
        debugPrint('Error Verify Payment Status: ${response.statusCode}');
        debugPrint('Error Verify Payment Body: ${response.body}');
        final error = jsonDecode(response.body);
        throw PaymentServiceException(
          error['message'] ?? 'Payment verification failed. Please try again.',
        );
      }
    } catch (e) {
      if (e is PaymentServiceException) {
        rethrow;
      }
      debugPrint('Verify payment error: $e');
      throw PaymentServiceException(
          'Network error. Please check your connection.');
    }
  }

  // Verify Subscription (EMI/Renewal)
  static Future<Map<String, dynamic>> verifySubscription({
    required String courseId,
    required String subscriptionId,
    required String paymentId,
    required String signature,
  }) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw PaymentServiceException('Not authenticated. Please login again.');
      }

      final body = {
        'courseId': courseId,
        'razorpay_subscription_id': subscriptionId,
        'razorpay_payment_id': paymentId,
        'razorpay_signature': signature,
      };

      debugPrint("Verify Subscription API Url: ${ApiConfig.verifySubscriptionEndpoint}");
      debugPrint("Verify Subscription Body: ${jsonEncode(body)}");

      final response = await http
          .post(
            Uri.parse(ApiConfig.verifySubscriptionEndpoint),
            headers: ApiConfig.getAuthHeaders(token),
            body: jsonEncode(body),
          )
          .timeout(ApiConfig.timeout);

      // Check for invalid token and handle auto-logout
      await HttpInterceptorService.checkResponseAndHandleAuth(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        debugPrint('Verify Subscription Success: ${response.body}');
        return Map<String, dynamic>.from(data);
      } else {
        debugPrint('Error Verify Subscription Status: ${response.statusCode}');
        debugPrint('Error Verify Subscription Body: ${response.body}');
        final error = jsonDecode(response.body);
        throw PaymentServiceException(
          error['message'] ?? 'Subscription verification failed. Please try again.',
        );
      }
    } catch (e) {
      if (e is PaymentServiceException) {
        rethrow;
      }
      debugPrint('Verify subscription error: $e');
      throw PaymentServiceException(
          'Network error. Please check your connection.');
    }
  }

  // Get All Payments (Admin) - One-Time Payments
  //
  // Returns a map with:
  // - 'payments': List<Map<String, dynamic>>
  // - 'analytics': Map<String, dynamic>? (may be null if not provided by API)
  static Future<Map<String, dynamic>> getAllPayments() async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw PaymentServiceException('Not authenticated. Please login again.');
      }

      debugPrint("Get All Payments API Url: ${ApiConfig.getAllPaymentsEndpoint}");

      final response = await http
          .get(
            Uri.parse(ApiConfig.getAllPaymentsEndpoint),
            headers: ApiConfig.getAuthHeaders(token),
          )
          .timeout(ApiConfig.timeout);

      // Check for invalid token and handle auto-logout
      await HttpInterceptorService.checkResponseAndHandleAuth(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        debugPrint('Get All Payments Success: ${response.body}');

        // Normalized result
        final result = <String, dynamic>{
          'payments': <Map<String, dynamic>>[],
          'analytics': null,
        };

        // Handle both list and wrapped response
        if (data is List) {
          result['payments'] =
              data.map((item) => Map<String, dynamic>.from(item)).toList();
        } else if (data is Map) {
          if (data['payments'] != null) {
            result['payments'] = (data['payments'] as List)
                .map((item) => Map<String, dynamic>.from(item))
                .toList();
          }
          if (data['analytics'] != null) {
            result['analytics'] =
                Map<String, dynamic>.from(data['analytics']);
          }
        }

        return result;
      } else {
        debugPrint('Error Get All Payments Status: ${response.statusCode}');
        debugPrint('Error Get All Payments Body: ${response.body}');
        final error = jsonDecode(response.body);
        throw PaymentServiceException(
          error['message'] ?? 'Failed to get payments. Please try again.',
        );
      }
    } catch (e) {
      if (e is PaymentServiceException) {
        rethrow;
      }
      debugPrint('Get all payments error: $e');
      throw PaymentServiceException(
          'Network error. Please check your connection.');
    }
  }

  // Get All Subscriptions (Admin)
  static Future<List<Map<String, dynamic>>> getAllSubscriptions() async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw PaymentServiceException('Not authenticated. Please login again.');
      }

      debugPrint("Get All Subscriptions API Url: ${ApiConfig.getAllSubscriptionsEndpoint}");

      final response = await http
          .get(
            Uri.parse(ApiConfig.getAllSubscriptionsEndpoint),
            headers: ApiConfig.getAuthHeaders(token),
          )
          .timeout(ApiConfig.timeout);

      // Check for invalid token and handle auto-logout
      await HttpInterceptorService.checkResponseAndHandleAuth(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        debugPrint('Get All Subscriptions Success: ${response.body}');
        
        // Handle both list and wrapped response
        if (data is List) {
          return data.map((item) => Map<String, dynamic>.from(item)).toList();
        } else if (data is Map && data['subscriptions'] != null) {
          return (data['subscriptions'] as List)
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        } else {
          return [];
        }
      } else {
        debugPrint('Error Get All Subscriptions Status: ${response.statusCode}');
        debugPrint('Error Get All Subscriptions Body: ${response.body}');
        final error = jsonDecode(response.body);
        throw PaymentServiceException(
          error['message'] ?? 'Failed to get subscriptions. Please try again.',
        );
      }
    } catch (e) {
      if (e is PaymentServiceException) {
        rethrow;
      }
      debugPrint('Get all subscriptions error: $e');
      throw PaymentServiceException(
          'Network error. Please check your connection.');
    }
  }

  // Cancel Subscription (Admin)
  static Future<Map<String, dynamic>> cancelSubscription(String subscriptionId) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw PaymentServiceException('Not authenticated. Please login again.');
      }

      debugPrint("Cancel Subscription API Url: ${ApiConfig.cancelSubscriptionEndpoint(subscriptionId)}");

      final response = await http
          .post(
            Uri.parse(ApiConfig.cancelSubscriptionEndpoint(subscriptionId)),
            headers: ApiConfig.getAuthHeaders(token),
          )
          .timeout(ApiConfig.timeout);

      // Check for invalid token and handle auto-logout
      await HttpInterceptorService.checkResponseAndHandleAuth(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        debugPrint('Cancel Subscription Success: ${response.body}');
        return Map<String, dynamic>.from(data);
      } else {
        debugPrint('Error Cancel Subscription Status: ${response.statusCode}');
        debugPrint('Error Cancel Subscription Body: ${response.body}');
        final error = jsonDecode(response.body);
        throw PaymentServiceException(
          error['message'] ?? 'Failed to cancel subscription. Please try again.',
        );
      }
    } catch (e) {
      if (e is PaymentServiceException) {
        rethrow;
      }
      debugPrint('Cancel subscription error: $e');
      throw PaymentServiceException(
          'Network error. Please check your connection.');
    }
  }

  // Get Subscription Status
  static Future<Map<String, dynamic>> getSubscriptionStatus() async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw PaymentServiceException('Not authenticated. Please login again.');
      }

      debugPrint("Get Subscription Status API Url: ${ApiConfig.subscriptionStatusEndpoint}");

      final response = await http
          .get(
            Uri.parse(ApiConfig.subscriptionStatusEndpoint),
            headers: ApiConfig.getAuthHeaders(token),
          )
          .timeout(ApiConfig.timeout);

      // Check for invalid token and handle auto-logout
      await HttpInterceptorService.checkResponseAndHandleAuth(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        debugPrint('Get Subscription Status Success: ${response.body}');
        return Map<String, dynamic>.from(data);
      } else {
        debugPrint('Error Get Subscription Status: ${response.statusCode}');
        debugPrint('Error Get Subscription Status Body: ${response.body}');
        final error = jsonDecode(response.body);
        throw PaymentServiceException(
          error['message'] ?? 'Failed to get subscription status. Please try again.',
        );
      }
    } catch (e) {
      if (e is PaymentServiceException) {
        rethrow;
      }
      debugPrint('Get subscription status error: $e');
      throw PaymentServiceException(
          'Network error. Please check your connection.');
    }
  }
  // Get Payment History (Student)
  static Future<List<Map<String, dynamic>>> getPaymentHistory() async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw PaymentServiceException('Not authenticated. Please login again.');
      }

      debugPrint("Get Payment History API Url: ${ApiConfig.getPaymentHistoryEndpoint}");

      final response = await http
          .get(
            Uri.parse(ApiConfig.getPaymentHistoryEndpoint),
            headers: ApiConfig.getAuthHeaders(token),
          )
          .timeout(ApiConfig.timeout);

      debugPrint('Get Payment History status code: ${response.statusCode}');
      debugPrint('Get Payment History response body: ${response.body}');

      // Check for invalid token and handle auto-logout
      await HttpInterceptorService.checkResponseAndHandleAuth(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        
        // Handle different response formats
        if (data is List) {
          return data
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        } else if (data is Map) {
          // Check if it's a single payment object (has id, courseTitle, etc.)
          if (data.containsKey('id') || data.containsKey('courseTitle')) {
            return [Map<String, dynamic>.from(data)];
          } else if (data['payments'] != null) {
            final payments = data['payments'] as List;
            return payments
                .map((item) => Map<String, dynamic>.from(item))
                .toList();
          } else if (data['data'] != null) {
            // Check if data is a list or single object
            if (data['data'] is List) {
              final dataList = data['data'] as List;
              return dataList
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList();
            } else {
              return [Map<String, dynamic>.from(data['data'])];
            }
          } else {
            return [];
          }
        } else {
          return [];
        }
      } else {
        debugPrint('Error Get Payment History Status: ${response.statusCode}');
        debugPrint('Error Get Payment History Body: ${response.body}');
        final error = jsonDecode(response.body);
        throw PaymentServiceException(
          error['message'] ?? 'Failed to get payment history. Please try again.',
        );
      }
    } catch (e) {
      if (e is PaymentServiceException) {
        rethrow;
      }
      debugPrint('Get payment history error: $e');
      throw PaymentServiceException(
          'Network error. Please check your connection.');
    }
  }

  // Get Student Payment History (Admin)
  static Future<List<Map<String, dynamic>>> getStudentPaymentHistory(String studentId) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw PaymentServiceException('Not authenticated. Please login again.');
      }

      final endpoint = ApiConfig.getStudentPaymentHistoryEndpoint(studentId);
      debugPrint("Get Student Payment History API Url: $endpoint");

      final response = await http
          .get(
            Uri.parse(endpoint),
            headers: ApiConfig.getAuthHeaders(token),
          )
          .timeout(ApiConfig.timeout);

      debugPrint('Get Student Payment History status code: ${response.statusCode}');
      debugPrint('Get Student Payment History response body: ${response.body}');

      // Check for invalid token and handle auto-logout
      await HttpInterceptorService.checkResponseAndHandleAuth(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        
        // Handle different response formats
        if (data is List) {
          return data
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        } else if (data is Map) {
          // Check if it's a single payment object (has id, courseTitle, etc.)
          if (data.containsKey('id') || data.containsKey('courseTitle')) {
            return [Map<String, dynamic>.from(data)];
          } else if (data['payments'] != null) {
            final payments = data['payments'] as List;
            return payments
                .map((item) => Map<String, dynamic>.from(item))
                .toList();
          } else if (data['data'] != null) {
            // Check if data is a list or single object
            if (data['data'] is List) {
              final dataList = data['data'] as List;
              return dataList
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList();
            } else {
              return [Map<String, dynamic>.from(data['data'])];
            }
          } else {
            return [];
          }
        } else {
          return [];
        }
      } else {
        debugPrint('Error Get Student Payment History Status: ${response.statusCode}');
        debugPrint('Error Get Student Payment History Body: ${response.body}');
        final error = jsonDecode(response.body);
        throw PaymentServiceException(
          error['message'] ?? 'Failed to get student payment history. Please try again.',
        );
      }
    } catch (e) {
      if (e is PaymentServiceException) {
        rethrow;
      }
      debugPrint('Get student payment history error: $e');
      throw PaymentServiceException(
          'Network error. Please check your connection.');
    }
  }
}

class PaymentServiceException implements Exception {
  final String message;

  PaymentServiceException(this.message);

  @override
  String toString() => message;
}

