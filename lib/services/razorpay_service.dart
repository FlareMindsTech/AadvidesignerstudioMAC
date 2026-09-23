import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:flutter/material.dart';


class RazorpayService {
  static Razorpay? _razorpay;
  static Function(Map<String, dynamic>)? _onSuccess;
  static Function(String)? _onError;

  static void initialize() {
    _razorpay = Razorpay();
    _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  static void dispose() {
    if (_razorpay != null) {
      _razorpay!.clear();
      _razorpay = null;
    }
    _onSuccess = null;
    _onError = null;
  }

  static void _handlePaymentSuccess(PaymentSuccessResponse response) {
    debugPrint('--- RAZORPAY SUCCESS ---');
    debugPrint('ID: ${response.paymentId}, Order: ${response.orderId}');
    
    final hasPaymentId = response.paymentId?.isNotEmpty ?? false;
    final hasSignature = response.signature?.isNotEmpty ?? false;

    if (hasPaymentId && hasSignature) {
      if (_onSuccess != null) {
        _onSuccess!({
          'razorpay_payment_id': response.paymentId!,
          'razorpay_order_id': response.orderId ?? '',
          'razorpay_subscription_id': response.orderId ?? '', 
          'razorpay_signature': response.signature!,
        });
      }
    } else {
      debugPrint('Warning: Incomplete payment response received: id=$hasPaymentId, sig=$hasSignature');
      if (_onError != null) {
        _onError!('Invalid payment response. Please try again.');
      }
    }
  }

  static void _handlePaymentError(PaymentFailureResponse response) {
    debugPrint('Payment Error Callback Received');
    debugPrint('Error Code: ${response.code}');
    debugPrint('Error Message: ${response.message}');

    if (_onError != null) {
      String errorMsg = 'Payment failed';

      // Handle user-cancelled payments with a clear, friendly message
      final message = response.message ?? '';
      final lowerMessage = message.toLowerCase();

      final isUserCancelled =
          response.code == 2 || // Razorpay user-cancelled code on many platforms
              lowerMessage.contains('cancelled') ||
              lowerMessage.contains('canceled') ||
              lowerMessage.contains('user cancelled') ||
              lowerMessage.contains('user canceled');

      if (isUserCancelled) {
        errorMsg =
            'Payment was cancelled. You can try again whenever you\'re ready.';
      } else if (message.isNotEmpty) {
        errorMsg = message;
      }

      _onError!(errorMsg);
    }
  }

  static void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint('External Wallet Callback Received: ${response.walletName}');
    // External wallet selection doesn't mean payment success
    // User still needs to complete payment in the external wallet
    // We don't call onError here as the payment flow is still ongoing
  }

  static Future<void> openPayment({
    required String keyId,
    required String orderId,
    required int amount,
    required String courseTitle,
    required String courseId,
    String? userEmail,
    String? userContact,
    required Function(Map<String, dynamic>) onSuccess,
    required Function(String) onError,
  }) async {
    if (_razorpay == null) {
      initialize();
    }

    _onSuccess = onSuccess;
    _onError = onError;

    final options = {
      'key': keyId,
      'amount': amount, // Amount in paise (e.g., 100000 = ₹1000)
      'name': 'Course Payment',
      'description': courseTitle,
      'order_id': orderId,
      'prefill': {
        'contact': userContact ?? '',
        'email': userEmail ?? '',
      },
      'external': {
        'wallets': ['phonepe', 'paytm']
      }
    };

    try {
      _razorpay!.open(options);
    } catch (e) {
      debugPrint('Error opening Razorpay: $e');
      onError('Failed to open payment gateway. Please try again.');
    }
  }

  // Open Razorpay for Subscription (EMI)
  static Future<void> openSubscription({
    required String keyId,
    required String subscriptionId,
    required String courseTitle,
    required String courseId,
    String? userEmail,
    String? userContact,
    required Function(Map<String, dynamic>) onSuccess,
    required Function(String) onError,
  }) async {
    if (_razorpay == null) {
      initialize();
    }
    debugPrint('RAZORPAY SERVICE: Initiating Subscription $subscriptionId');
    _onSuccess = onSuccess;
    _onError = onError;

    final options = {
      'key': keyId,
      'name': 'FlareMinds Payment',
      'description': courseTitle,
      'subscription_id': subscriptionId,
      // Removed 'amount' to allow Razorpay to use the plan's amount (500 or 1000)
      'prefill': {
        'contact': userContact ?? '',
        'email': userEmail ?? '',
      },
      'external': {
        'wallets': ['phonepe', 'paytm']
      }
    };

    debugPrint('Opening Razorpay Subscription with options: $options');

    try {
      _razorpay!.open(options);
    } catch (e) {
      debugPrint('Error opening Razorpay Subscription: $e');
      onError('Failed to open payment gateway. Please try again.');
    }
  }
}

