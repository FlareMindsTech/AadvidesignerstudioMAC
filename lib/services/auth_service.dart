import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../models/user.dart';
import 'storage_service.dart';

class AuthService {
  // Login
  static Future<LoginResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.loginEndpoint),
            headers: ApiConfig.headers,
            body: jsonEncode({
              'email': email,
              'password': password,
            }),
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final loginResponse = LoginResponse.fromJson(data);

        // Save token and user data to SharedPreferences
        await StorageService.saveToken(loginResponse.token);
        await StorageService.saveUser(loginResponse.user);
        print(
            'Login Success Responsecode: ${response.statusCode} Body: ${response.body}');
        return loginResponse;
      } else {
        final error = jsonDecode(response.body);
        print(
            'Failed Login code: ${response.statusCode} Body: ${response.body}');
        throw AuthException(
          error['message'] ?? 'Login failed. Please try again.',
        );
      }
    } catch (e) {
      print('Login Exception: $e');
      if (e is AuthException) {
        rethrow;
      }
      throw AuthException('Network error. Please check your connection.');
    }
  }

  // Send OTP
  static Future<bool> sendOtp(String phoneNumber, {String? mode}) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.requestOtpEndpoint),
            headers: ApiConfig.headers,
            body: jsonEncode({
              'phoneNumber': phoneNumber,
              if (mode != null) 'mode': mode,
            }),
          )
          .timeout(ApiConfig.timeout);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        String errorMessage = 'Failed to send OTP.';
        try {
          final data = jsonDecode(response.body);
          errorMessage = data['message'] ?? errorMessage;
        } catch (_) {
          // If body is not JSON, use a default error or the status code
          errorMessage = 'Server error (${response.statusCode}).';
        }
        throw AuthException(errorMessage);
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      debugPrint('OTP Error: $e');
      throw AuthException('Network error. Please check your connection.');
    }
  }

  // Verify OTP
  static Future<LoginResponse> verifyOtp(
      String phoneNumber, String otp) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.verifyOtpEndpoint),
            headers: ApiConfig.headers,
            body: jsonEncode({
              'phoneNumber': phoneNumber,
              'otp': otp,
            }),
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final loginResponse = LoginResponse.fromJson(data);

        // Save token and user data
        await StorageService.saveToken(loginResponse.token);
        await StorageService.saveUser(loginResponse.user);

        return loginResponse;
      } else {
        final data = jsonDecode(response.body);
        throw AuthException(data['message'] ?? 'Invalid OTP.');
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Network error. Failed to verify OTP.');
    }
  }

  // Register
  static Future<LoginResponse> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String phoneNumber,
    String role = 'student',
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.registerEndpoint),
            headers: ApiConfig.headers,
            body: jsonEncode({
              'FirstName': firstName,
              'LastName': lastName,
              'email': email,
              'password': password,
              'phoneNumber': phoneNumber,
              'role': role,
            }),
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final loginResponse = LoginResponse.fromJson(data);

        // Save token and user data to SharedPreferences
        await StorageService.saveToken(loginResponse.token);
        await StorageService.saveUser(loginResponse.user);
        print(
            'Register Success Responsecode: ${response.statusCode} Body: ${response.body}');
        return loginResponse;
      } else {
        final error = jsonDecode(response.body);
        print(
            'Failed Register code: ${response.statusCode} Body: ${response.body}');
        throw AuthException(
          error['message'] ?? 'Registration failed. Please try again.',
        );
      }
    } catch (e) {
      print('Register Exception: $e');
      if (e is AuthException) {
        rethrow;
      }
      throw AuthException('Network error. Please check your connection.');
    }
  }

  // Logout
  static Future<bool> logout() async {
    try {
      final token = await StorageService.getToken();

      if (token != null) {
        // Call logout API
        try {
          debugPrint("Logout API Url: ${ApiConfig.logoutEndpoint}");
          final response = await http
              .post(
                Uri.parse(ApiConfig.logoutEndpoint),
                headers: ApiConfig.getAuthHeaders(token),
              )
              .timeout(ApiConfig.timeout);

          debugPrint('Logout API Response Status: ${response.statusCode}');
          debugPrint('Logout API Response Body: ${response.body}');

          if (response.statusCode == 200 || response.statusCode == 201) {
            debugPrint('Logout API call successful');
          } else {
            // Even if API call fails, we should still clear local data
            debugPrint('Logout API call returned status: ${response.statusCode}');
          }
        } catch (e) {
          // Even if API call fails, we should still clear local data
          debugPrint('Logout API call failed: $e');
        }
      }

      // Always clear local storage regardless of API call result
      final cleared = await StorageService.clearUserData();
      if (cleared) {
        debugPrint('Local user data cleared successfully');
      } else {
        debugPrint('Failed to clear local user data');
      }
      
      return cleared;
    } catch (e) {
      debugPrint('Logout error: $e');
      // Try to clear local data even if there's an error
      try {
        await StorageService.clearUserData();
      } catch (clearError) {
        debugPrint('Error clearing user data: $clearError');
      }
      return false;
    }
  }

  // Get current user
  static Future<User?> getCurrentUser() async {
    return await StorageService.getUser();
  }

  // Check if user is authenticated
  static Future<bool> isAuthenticated() async {
    return await StorageService.isLoggedIn();
  }

  // Get auth token
  static Future<String?> getToken() async {
    return await StorageService.getToken();
  }
}

class AuthException implements Exception {
  final String message;

  AuthException(this.message);

  @override
  String toString() => message;
}
