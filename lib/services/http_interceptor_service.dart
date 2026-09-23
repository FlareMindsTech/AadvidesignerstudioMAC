import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'auth_service.dart';
import 'storage_service.dart';
import '../screens/login_screen.dart';
import 'package:page_transition/page_transition.dart';
import '../main.dart' show navigatorKey; // Import the navigatorKey from main.dart

/// HTTP Interceptor Service
/// 
/// This service automatically handles invalid token scenarios across all screens.
/// When any API call returns 401 (Unauthorized) or 403 (Forbidden), it will:
/// 1. Automatically log out the user
/// 2. Clear all stored user data
/// 3. Navigate to the login screen
/// 4. Show a message to the user
/// 
/// Usage in services:
/// After making any HTTP request, add this line before checking response status:
/// 
/// ```dart
/// final response = await http.get(...);
/// 
/// // Add this line to check for invalid token
/// await HttpInterceptorService.checkResponseAndHandleAuth(response);
/// 
/// if (response.statusCode == 200) {
///   // Handle success
/// }
/// ```
/// 
/// This should be added to ALL service methods that make authenticated API calls.

class HttpInterceptorService {
  // Shared persistent client to reuse connections
  static final http.Client _client = http.Client();
  
  // Flag to prevent multiple simultaneous logout attempts
  static bool _isLoggingOut = false;

  /// Handles HTTP response and checks for authentication errors
  /// Returns true if the response indicates an invalid token (should logout)
  static bool _isInvalidTokenResponse(http.Response response) {
    // Check for 401 Unauthorized - this means token is bad/expired
    if (response.statusCode == 401) {
      return true;
    }

    // 403 Forbidden should NOT trigger logout. 
    // It just means the user has a valid session but no role access to THIS resource.
    
    // Also check response body for token-related error messages
    try {
      final errorBody = jsonDecode(response.body);
      
      // Check both 'message' and 'error' fields (APIs may use either)
      final errorMessage = ((errorBody['message'] ?? errorBody['error'] ?? '') as String).toLowerCase();
      
      // Check for common token invalid messages
      if (errorMessage.contains('token') && 
          (errorMessage.contains('invalid') || 
           errorMessage.contains('expired') || 
           errorMessage.contains('unauthorized'))) {
        return true;
      }
      
      // Also check if the error field directly contains token-related text
      final errorField = ((errorBody['error'] ?? '') as String).toLowerCase();
      if (errorField.contains('token') && 
          (errorField.contains('invalid') || 
           errorField.contains('expired') || 
           errorField.contains('unauthorized'))) {
        return true;
      }
    } catch (e) {
      // If JSON parsing fails, ignore and rely on status code only
    }

    return false;
  }

  /// Automatically logs out user and navigates to login screen
  static Future<void> handleInvalidToken() async {
    // Prevent multiple simultaneous logout attempts
    if (_isLoggingOut) {
      debugPrint('Logout already in progress, skipping...');
      return;
    }

    _isLoggingOut = true;
    debugPrint('Token is invalid. Logging out user...');
    
    try {
      // Clear user data first
      await AuthService.logout();
      
      // Wait a bit to ensure logout completes
      await Future.delayed(const Duration(milliseconds: 200));
      
      // Navigate to login screen using the global navigator key
      // Use rootNavigator to ensure we navigate from the root level
      final context = navigatorKey.currentContext;
      if (context != null) {
        // Use SchedulerBinding to ensure navigation happens after current frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (navigatorKey.currentContext != null) {
            Navigator.of(navigatorKey.currentContext!, rootNavigator: true).pushAndRemoveUntil(
              PageTransition(
                type: PageTransitionType.fade,
                duration: const Duration(milliseconds: 300),
                child: const LoginScreen(),
              ),
              (route) => false,
            );
            
            // Show message after navigation completes
            Future.delayed(const Duration(milliseconds: 600), () {
              if (navigatorKey.currentContext != null) {
                ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
                  const SnackBar(
                    content: Text('Your session has expired. Please login again.'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            });
          }
        });
      } else {
        debugPrint('Warning: navigatorKey.currentContext is null, cannot navigate to login');
        // Try to clear data even if navigation fails
        await StorageService.clearUserData();
      }
    } catch (e) {
      debugPrint('Error during automatic logout: $e');
      // Try to clear data even if navigation fails
      try {
        await StorageService.clearUserData();
      } catch (clearError) {
        debugPrint('Error clearing user data: $clearError');
      }
    } finally {
      // Reset flag after a delay to allow navigation to complete
      Future.delayed(const Duration(seconds: 2), () {
        _isLoggingOut = false;
      });
    }
  }

  /// Wrapper for HTTP GET requests with automatic token validation
  static Future<http.Response> get(
    Uri url, {
    Map<String, String>? headers,
    bool checkAuth = true,
  }) async {
    try {
      final token = await StorageService.getToken();
      
      // Add auth header if token exists and checkAuth is true
      final finalHeaders = Map<String, String>.from(headers ?? {});
      if (checkAuth && token != null) {
        finalHeaders['Authorization'] = 'Bearer $token';
      }
      
      final response = await _client.get(url, headers: finalHeaders).timeout(
        const Duration(seconds: 30),
      );

      // Check for invalid token
      if (checkAuth && _isInvalidTokenResponse(response)) {
        await handleInvalidToken();
        throw Exception('Token is invalid. User has been logged out.');
      }

      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Wrapper for HTTP POST requests with automatic token validation
  static Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    bool checkAuth = true,
  }) async {
    try {
      final token = await StorageService.getToken();
      
      // Add auth header if token exists and checkAuth is true
      final finalHeaders = Map<String, String>.from(headers ?? {});
      if (checkAuth && token != null) {
        finalHeaders['Authorization'] = 'Bearer $token';
      }
      
      final response = await _client.post(url, headers: finalHeaders, body: body).timeout(
        const Duration(seconds: 30),
      );

      // Check for invalid token
      if (checkAuth && _isInvalidTokenResponse(response)) {
        await handleInvalidToken();
        throw Exception('Token is invalid. User has been logged out.');
      }

      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Wrapper for HTTP PUT requests with automatic token validation
  static Future<http.Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    bool checkAuth = true,
  }) async {
    try {
      final token = await StorageService.getToken();
      
      // Add auth header if token exists and checkAuth is true
      final finalHeaders = Map<String, String>.from(headers ?? {});
      if (checkAuth && token != null) {
        finalHeaders['Authorization'] = 'Bearer $token';
      }
      
      final response = await _client.put(url, headers: finalHeaders, body: body).timeout(
        const Duration(seconds: 30),
      );

      // Check for invalid token
      if (checkAuth && _isInvalidTokenResponse(response)) {
        await handleInvalidToken();
        throw Exception('Token is invalid. User has been logged out.');
      }

      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Wrapper for HTTP DELETE requests with automatic token validation
  static Future<http.Response> delete(
    Uri url, {
    Map<String, String>? headers,
    bool checkAuth = true,
  }) async {
    try {
      final token = await StorageService.getToken();
      
      // Add auth header if token exists and checkAuth is true
      final finalHeaders = Map<String, String>.from(headers ?? {});
      if (checkAuth && token != null) {
        finalHeaders['Authorization'] = 'Bearer $token';
      }
      
      final response = await _client.delete(url, headers: finalHeaders).timeout(
        const Duration(seconds: 30),
      );

      // Check for invalid token
      if (checkAuth && _isInvalidTokenResponse(response)) {
        await handleInvalidToken();
        throw Exception('Token is invalid. User has been logged out.');
      }

      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Helper method to check response and handle invalid token
  /// Use this in existing services that use http package directly
  /// If token is invalid, it will automatically logout and navigate to login screen
  /// Services should check response status code after calling this method
  static Future<void> checkResponseAndHandleAuth(http.Response response) async {
    if (_isInvalidTokenResponse(response)) {
      await handleInvalidToken();
      // Don't throw exception - let services handle the response status code
      // The navigation has already happened, so services will naturally fail
      // when they try to process the error response
    }
  }

  /// Check if token is null and handle auto-logout
  /// Call this method in services when token is null before making API calls
  /// This ensures users are logged out when token is missing
  static Future<void> checkTokenAndHandleLogout() async {
    final token = await StorageService.getToken();
    if (token == null) {
      debugPrint('Token is null. Triggering auto-logout...');
      await handleInvalidToken();
    }
  }
}

