import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import '../config/api_config.dart';
import '../models/user.dart';
import '../models/student_detail.dart';
import 'storage_service.dart';
import 'http_interceptor_service.dart';

class UserService {
  // Create Admin
  static Future<User> createAdmin({
    required String firstName,
    required String lastName,
    required String email,
    required String phoneNumber,
    required String password,
    String role = 'admin',
    String? ownerToken,
  }) async {
    try {
      // Use owner token if provided, otherwise try to get from storage
      String? token = ownerToken ?? await StorageService.getOwnerToken();

      // If no owner token, try regular token (but this will likely fail)
      if (token == null) {
        token = await StorageService.getToken();
        if (token == null) {
          // Trigger auto-logout when token is null
          await HttpInterceptorService.checkTokenAndHandleLogout();
          throw UserServiceException('Not authenticated. Please login again.');
        }
        // Warn that owner token is required
        debugPrint(
            'Warning: Using regular token. Owner token is required for this endpoint.');
      }

      debugPrint("Api Url: ${ApiConfig.createAdminEndpoint}");
      final response = await http
          .post(
            Uri.parse(ApiConfig.createAdminEndpoint),
            headers: ApiConfig.getAuthHeaders(token),
            body: jsonEncode({
              'FirstName': firstName,
              'LastName': lastName,
              'email': email,
              'phoneNumber': phoneNumber,
              'password': password,
              'role': role,
            }),
          )
          .timeout(ApiConfig.timeout);

      // Check for invalid token and handle auto-logout
      await HttpInterceptorService.checkResponseAndHandleAuth(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        // Assuming the API returns the created user
        return User.fromJson(data['user'] ?? data);
      } else {
        print('Error Create Admin: ${response.body}');
        final error = jsonDecode(response.body);
        String errorMessage =
            error['message'] ?? 'Failed to create admin. Please try again.';

        // Provide helpful message if access is denied
        if (errorMessage.toLowerCase().contains('access denied') ||
            errorMessage.toLowerCase().contains('unauthorized')) {
          errorMessage =
              'Access denied. This endpoint requires an owner token. Please provide an owner token.';
        }

        throw UserServiceException(errorMessage);
      }
    } catch (e) {
      if (e is UserServiceException) {
        rethrow;
      }
      debugPrint('Create admin error: $e');
      throw UserServiceException(
          'Network error. Please check your connection.');
    }
  }

  // Create Student (Admin/Owner) - New API
  static Future<User> createStudentAdmin({
    required String firstName,
    required String lastName,
    required String email,
    String? password,
    required String phoneNumber,
    String role = 'student',
  }) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        // Trigger auto-logout when token is null
        await HttpInterceptorService.checkTokenAndHandleLogout();
        throw UserServiceException('Not authenticated. Please login again.');
      }
      debugPrint("Api Url: ${ApiConfig.adminCreateStudentEndpoint}");
      final response = await http
          .post(
            Uri.parse(ApiConfig.adminCreateStudentEndpoint),
            headers: ApiConfig.getAuthHeaders(token),
            body: jsonEncode({
              'FirstName': firstName,
              'LastName': lastName,
              'email': email,
              if (password != null && password.isNotEmpty) 'password': password,
              'phoneNumber': phoneNumber,
              'role': role,
            }),
          )
          .timeout(ApiConfig.timeout);

      debugPrint('Create student status code: ${response.statusCode}');
      debugPrint('Create student response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return User.fromJson(data['user'] ?? data);
      } else {
        try {
          final error = jsonDecode(response.body);
          throw UserServiceException(
            error['message'] ??
                'Failed to create student. Status: ${response.statusCode}',
          );
        } catch (e) {
          throw UserServiceException(
            'Failed to create student. Status: ${response.statusCode}. Server returned non-JSON response.',
          );
        }
      }
    } catch (e) {
      if (e is UserServiceException) {
        rethrow;
      }
      debugPrint('Create student error: $e');
      throw UserServiceException(
          'Network error. Please check your connection.');
    }
  }

  // Create Student (Legacy - keeping for backward compatibility)
  static Future<User> createStudent({
    required String firstName,
    required String lastName,
    required String email,
    String? password,
    required String phoneNumber,
    String role = 'student',
  }) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        // Trigger auto-logout when token is null
        await HttpInterceptorService.checkTokenAndHandleLogout();
        throw UserServiceException('Not authenticated. Please login again.');
      }
      debugPrint("Api Url: ${ApiConfig.createStudentEndpoint}");
      final response = await http
          .post(
            Uri.parse(ApiConfig.createStudentEndpoint),
            headers: ApiConfig.getAuthHeaders(token),
            body: jsonEncode({
              'FirstName': firstName,
              'LastName': lastName,
              'email': email,
              if (password != null && password.isNotEmpty) 'password': password,
              'phoneNumber': phoneNumber,
              'role': role,
            }),
          )
          .timeout(ApiConfig.timeout);

      debugPrint('Create student status code: ${response.statusCode}');
      debugPrint('Create student response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return User.fromJson(data['user'] ?? data);
      } else {
        try {
          final error = jsonDecode(response.body);
          throw UserServiceException(
            error['message'] ??
                'Failed to create student. Status: ${response.statusCode}',
          );
        } catch (e) {
          throw UserServiceException(
            'Failed to create student. Status: ${response.statusCode}. Server returned non-JSON response.',
          );
        }
      }
    } catch (e) {
      if (e is UserServiceException) {
        rethrow;
      }
      debugPrint('Create student error: $e');
      throw UserServiceException(
          'Network error. Please check your connection.');
    }
  }

  // Get All Users
  static Future<List<User>> getUsers() async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        // Trigger auto-logout when token is null
        await HttpInterceptorService.checkTokenAndHandleLogout();
        throw UserServiceException('Not authenticated. Please login again.');
      }
      debugPrint("Api Url: ${ApiConfig.getUsersEndpoint}");
      final response = await http
          .get(
            Uri.parse(ApiConfig.getUsersEndpoint),
            headers: ApiConfig.getAuthHeaders(token),
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint("Success: ${response.body}");
        // Handle different response formats
        List<dynamic> usersJson;
        if (data is List) {
          usersJson = data;
        } else if (data is Map && data['users'] != null) {
          usersJson = data['users'];
        } else if (data is Map && data['data'] != null) {
          usersJson = data['data'];
        } else {
          usersJson = [];
        }

        return usersJson.map((json) => User.fromJson(json)).toList();
      } else {
        final error = jsonDecode(response.body);
        debugPrint(
            "Failed: Code: ${response.statusCode} Body: ${response.body}");
        throw UserServiceException(
          error['message'] ?? 'Failed to fetch users. Please try again.',
        );
      }
    } catch (e) {
      if (e is UserServiceException) {
        rethrow;
      }
      debugPrint('Get users error: $e');
      throw UserServiceException(
          'Network error. Please check your connection.');
    }
  }

  // Delete current user's own account
  static Future<bool> deleteMyAccount() async {
    try {
      final token = await StorageService.getToken();
      if (token == null) {
        // Trigger auto-logout when token is null
        await HttpInterceptorService.checkTokenAndHandleLogout();
        throw UserServiceException('Not authenticated. Please login again.');
      }

      debugPrint("Delete My Account API Url: ${ApiConfig.deleteAccountEndpoint}");
      final response = await http
          .delete(
            Uri.parse(ApiConfig.deleteAccountEndpoint),
            headers: ApiConfig.getAuthHeaders(token),
          )
          .timeout(ApiConfig.timeout);

      // Check for invalid token and handle auto-logout
      await HttpInterceptorService.checkResponseAndHandleAuth(response);

      debugPrint(
          'Delete My Account Status: ${response.statusCode}, Body: ${response.body}');

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204) {
        return true;
      } else {
        try {
          final data = jsonDecode(response.body);
          throw UserServiceException(
            data['message'] ??
                'Failed to delete account. Please try again later.',
          );
        } catch (e) {
          throw UserServiceException(
            'Failed to delete account. Status: ${response.statusCode}.',
          );
        }
      }
    } catch (e) {
      if (e is UserServiceException) rethrow;
      debugPrint('Delete my account error: $e');
      throw UserServiceException(
          'Network error. Please check your connection.');
    }
  }

  // Get Student Profile (Legacy)
  static Future<User> getStudentProfile() async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        // Trigger auto-logout when token is null
        await HttpInterceptorService.checkTokenAndHandleLogout();
        throw UserServiceException('Not authenticated. Please login again.');
      }
      debugPrint("Api Url: ${ApiConfig.studentProfileEndpoint}");
      final response = await http
          .get(
            Uri.parse(ApiConfig.studentProfileEndpoint),
            headers: ApiConfig.getAuthHeaders(token),
          )
          .timeout(ApiConfig.timeout);

      debugPrint('Get profile status code: ${response.statusCode}');
      debugPrint('Get profile response body: ${response.body}');

      // Check for invalid token and handle auto-logout
      await HttpInterceptorService.checkResponseAndHandleAuth(response);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return User.fromJson(data);
      } else {
        final error = jsonDecode(response.body);
        throw UserServiceException(
          error['message'] ?? 'Failed to fetch profile. Please try again.',
        );
      }
    } catch (e) {
      if (e is UserServiceException) {
        rethrow;
      }
      debugPrint('Get profile error: $e');
      throw UserServiceException(
          'Network error. Please check your connection.');
    }
  }

  // Get User Profile (GET /api/user/profile)
  static Future<User> getUserProfile() async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        // Trigger auto-logout when token is null
        await HttpInterceptorService.checkTokenAndHandleLogout();
        throw UserServiceException('Not authenticated. Please login again.');
      }
      debugPrint("Get User Profile API Url: ${ApiConfig.userProfileEndpoint}");
      final response = await http
          .get(
            Uri.parse(ApiConfig.userProfileEndpoint),
            headers: ApiConfig.getAuthHeaders(token),
          )
          .timeout(ApiConfig.timeout);

      debugPrint('Get User Profile Status: ${response.statusCode}');
      debugPrint('Get User Profile Body: ${response.body}');

      // Check for invalid token and handle auto-logout
      await HttpInterceptorService.checkResponseAndHandleAuth(response);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return User.fromJson(data);
      } else {
        final error = jsonDecode(response.body);
        throw UserServiceException(
          error['message'] ?? 'Failed to fetch profile. Please try again.',
        );
      }
    } catch (e) {
      if (e is UserServiceException) {
        rethrow;
      }
      debugPrint('Get user profile error: $e');
      throw UserServiceException(
          'Network error. Please check your connection.');
    }
  }

  // Update User Profile (PUT /api/user/profile)
  static Future<User> updateUserProfile({
    String? firstName,
    String? lastName,
    String? email,
    File? photo,
  }) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        // Trigger auto-logout when token is null
        await HttpInterceptorService.checkTokenAndHandleLogout();
        throw UserServiceException('Not authenticated. Please login again.');
      }

      var request = http.MultipartRequest(
        'PUT',
        Uri.parse(ApiConfig.userProfileEndpoint),
      );

      // Add headers
      request.headers.addAll(ApiConfig.getAuthHeadersMultipart(token));

      // Add form fields
      if (firstName != null) request.fields['FirstName'] = firstName;
      if (lastName != null) request.fields['LastName'] = lastName;
      if (email != null) request.fields['email'] = email;

      // Add photo file if provided
      if (photo != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'photo',
            photo.path,
            filename: path.basename(photo.path),
          ),
        );
      }

      debugPrint(
          "Update User Profile API Url: ${ApiConfig.userProfileEndpoint}");
      debugPrint("Update User Profile Fields: ${request.fields}");
      debugPrint(
          "Update User Profile Files: ${request.files.map((f) => f.field).toList()}");

      final streamedResponse = await request.send().timeout(ApiConfig.timeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        debugPrint('Update User Profile Success: ${response.body}');
        final updatedUser = User.fromJson(data['user'] ?? data);
        
        // Save the updated user data to local storage
        await StorageService.saveUser(updatedUser);
        
        return updatedUser;
      } else {
        debugPrint('Error Update User Profile Status: ${response.statusCode}');
        debugPrint('Error Update User Profile Body: ${response.body}');
        final error = jsonDecode(response.body);
        throw UserServiceException(
          error['message'] ?? 'Failed to update profile. Please try again.',
        );
      }
    } catch (e) {
      if (e is UserServiceException) {
        rethrow;
      }
      debugPrint('Update user profile error: $e');
      throw UserServiceException('Failed to update profile. Please try again.');
    }
  }

  // Delete User (if needed)
  static Future<bool> deleteUser(String userId) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        // Trigger auto-logout when token is null
        await HttpInterceptorService.checkTokenAndHandleLogout();
        throw UserServiceException('Not authenticated. Please login again.');
      }

      final response = await http
          .delete(
            Uri.parse('${ApiConfig.usersBaseUrl}/$userId'),
            headers: ApiConfig.getAuthHeaders(token),
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      } else {
        final error = jsonDecode(response.body);
        throw UserServiceException(
          error['message'] ?? 'Failed to delete user. Please try again.',
        );
      }
    } catch (e) {
      if (e is UserServiceException) {
        rethrow;
      }
      debugPrint('Delete user error: $e');
      throw UserServiceException(
          'Network error. Please check your connection.');
    }
  }

  // Update Student Password
  static Future<bool> updateStudentPassword({
    required String studentId,
    required String newPassword,
  }) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        // Trigger auto-logout when token is null
        await HttpInterceptorService.checkTokenAndHandleLogout();
        throw UserServiceException('Not authenticated. Please login again.');
      }

      debugPrint(
          "Update Password Api Url: ${ApiConfig.baseUrl}/student/update-password");
      final response = await http
          .put(
            Uri.parse('${ApiConfig.baseUrl}/student/update-password'),
            headers: ApiConfig.getAuthHeaders(token),
            body: jsonEncode({
              'studentId': studentId,
              'newPassword': newPassword,
            }),
          )
          .timeout(ApiConfig.timeout);

      debugPrint('Update password status code: ${response.statusCode}');
      debugPrint('Update password response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        try {
          final error = jsonDecode(response.body);
          throw UserServiceException(
            error['message'] ??
                'Failed to update password. Status: ${response.statusCode}',
          );
        } catch (e) {
          throw UserServiceException(
            'Failed to update password. Status: ${response.statusCode}.',
          );
        }
      }
    } catch (e) {
      if (e is UserServiceException) {
        rethrow;
      }
      debugPrint('Update password error: $e');
      throw UserServiceException(
          'Network error. Please check your connection.');
    }
  }

  // ========== ADMIN - STUDENT MANAGEMENT ==========

  // Get All Students (Admin/Owner)
  static Future<List<User>> getAllStudents() async {
    try {
      final token = await StorageService.getToken();
      if (token == null) {
        // Trigger auto-logout when token is null
        await HttpInterceptorService.checkTokenAndHandleLogout();
        throw UserServiceException('Not authenticated. Please login again.');
      }

      debugPrint("Api Url: ${ApiConfig.adminGetAllStudentsEndpoint}");
      final response = await http
          .get(
            Uri.parse(ApiConfig.adminGetAllStudentsEndpoint),
            headers: ApiConfig.getAuthHeaders(token),
          )
          .timeout(ApiConfig.timeout);

      // Check for invalid token and handle auto-logout
      await HttpInterceptorService.checkResponseAndHandleAuth(response);

      if (response.statusCode == 200) {
        debugPrint("Students Response: ${response.body}");
        final data = jsonDecode(response.body);
        List<dynamic> studentsJson =
            data is List ? data : (data['students'] ?? data['data'] ?? []);
        return studentsJson.map((json) => User.fromJson(json)).toList();
      } else {
        print("Failed Response: ${response.body}");
        final error = jsonDecode(response.body);
        throw UserServiceException(
          error['message'] ?? 'Failed to fetch students. Please try again.',
        );
      }
    } catch (e) {
      if (e is UserServiceException) rethrow;
      debugPrint('Get all students error: $e');
      throw UserServiceException(
          'Network error. Please check your connection.');
    }
  }

  // Get Student Detail (Admin/Owner)
  static Future<User> getStudentDetail(String studentId) async {
    try {
      final token = await StorageService.getToken();
      if (token == null) {
        // Trigger auto-logout when token is null
        await HttpInterceptorService.checkTokenAndHandleLogout();
        throw UserServiceException('Not authenticated. Please login again.');
      }

      debugPrint(
          "Api Url: ${ApiConfig.adminGetStudentDetailEndpoint(studentId)}");
      final response = await http
          .get(
            Uri.parse(ApiConfig.adminGetStudentDetailEndpoint(studentId)),
            headers: ApiConfig.getAuthHeaders(token),
          )
          .timeout(ApiConfig.timeout);

      // Check for invalid token and handle auto-logout
      await HttpInterceptorService.checkResponseAndHandleAuth(response);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return User.fromJson(data['student'] ?? data);
      } else {
        final error = jsonDecode(response.body);
        throw UserServiceException(
          error['message'] ??
              'Failed to fetch student details. Please try again.',
        );
      }
    } catch (e) {
      if (e is UserServiceException) rethrow;
      debugPrint('Get student detail error: $e');
      throw UserServiceException(
          'Network error. Please check your connection.');
    }
  }

  // Get Student Detail with Subscribed Courses (Admin/Owner)
  static Future<StudentDetail> getStudentDetailWithCourses(
      String studentId) async {
    try {
      final token = await StorageService.getToken();
      if (token == null) {
        // Trigger auto-logout when token is null
        await HttpInterceptorService.checkTokenAndHandleLogout();
        throw UserServiceException('Not authenticated. Please login again.');
      }

      debugPrint(
          "Api Url: ${ApiConfig.adminGetStudentDetailEndpoint(studentId)}");
      final response = await http
          .get(
            Uri.parse(ApiConfig.adminGetStudentDetailEndpoint(studentId)),
            headers: ApiConfig.getAuthHeaders(token),
          )
          .timeout(ApiConfig.timeout);

      // Check for invalid token and handle auto-logout
      await HttpInterceptorService.checkResponseAndHandleAuth(response);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('Get Student Detail Success: ${response.body}');
        return StudentDetail.fromJson(data);
      } else {
        final error = jsonDecode(response.body);
        throw UserServiceException(
          error['message'] ??
              'Failed to fetch student details. Please try again.',
        );
      }
    } catch (e) {
      if (e is UserServiceException) rethrow;
      debugPrint('Get student detail error: $e');
      throw UserServiceException(
          'Network error. Please check your connection.');
    }
  }

  // Update Student with Photo (Admin/Owner)
  static Future<User> updateStudent({
    required String studentId,
    String? firstName,
    String? phoneNumber,
    File? photo,
  }) async {
    try {
      final token = await StorageService.getToken();
      if (token == null) {
        // Trigger auto-logout when token is null
        await HttpInterceptorService.checkTokenAndHandleLogout();
        throw UserServiceException('Not authenticated. Please login again.');
      }

      debugPrint("Api Url: ${ApiConfig.adminUpdateStudentEndpoint(studentId)}");
      final request = http.MultipartRequest(
        'PUT',
        Uri.parse(ApiConfig.adminUpdateStudentEndpoint(studentId)),
      );

      request.headers.addAll(ApiConfig.getAuthHeadersMultipart(token));

      if (firstName != null) {
        request.fields['FirstName'] = firstName;
      }
      if (phoneNumber != null) {
        request.fields['phoneNumber'] = phoneNumber;
      }
      if (photo != null) {
        request.files.add(
          await http.MultipartFile.fromPath('photo', photo.path),
        );
      }

      final streamedResponse = await request.send().timeout(ApiConfig.timeout);
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('Update student status code: ${response.statusCode}');
      debugPrint('Update student response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        // API returns 'user' field, not 'student'
        final userData = data['user'] ?? data['student'] ?? data;

        // Ensure email and role are not null (required fields)
        if (userData is Map<String, dynamic>) {
          userData['email'] = userData['email'] ?? '';
          userData['role'] = userData['role'] ?? 'student';
        }

        return User.fromJson(userData as Map<String, dynamic>);
      } else {
        final error = jsonDecode(response.body);
        throw UserServiceException(
          error['message'] ?? 'Failed to update student. Please try again.',
        );
      }
    } catch (e) {
      if (e is UserServiceException) rethrow;
      debugPrint('Update student error: $e');
      throw UserServiceException(
          'Network error. Please check your connection.');
    }
  }

  // Deactivate Student (Admin/Owner)
  static Future<bool> deactivateStudent(String studentId) async {
    try {
      final token = await StorageService.getToken();
      if (token == null) {
        // Trigger auto-logout when token is null
        await HttpInterceptorService.checkTokenAndHandleLogout();
        throw UserServiceException('Not authenticated. Please login again.');
      }

      debugPrint(
          "Api Url: ${ApiConfig.adminDeactivateStudentEndpoint(studentId)}");
      final response = await http
          .post(
            Uri.parse(ApiConfig.adminDeactivateStudentEndpoint(studentId)),
            headers: ApiConfig.getAuthHeaders(token),
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        final error = jsonDecode(response.body);
        throw UserServiceException(
          error['message'] ?? 'Failed to deactivate student. Please try again.',
        );
      }
    } catch (e) {
      if (e is UserServiceException) rethrow;
      debugPrint('Deactivate student error: $e');
      throw UserServiceException(
          'Network error. Please check your connection.');
    }
  }

  // Delete Student (Admin/Owner)
  static Future<bool> deleteStudent(String studentId) async {
    try {
      final token = await StorageService.getToken();
      if (token == null) {
        // Trigger auto-logout when token is null
        await HttpInterceptorService.checkTokenAndHandleLogout();
        throw UserServiceException('Not authenticated. Please login again.');
      }

      debugPrint("Api Url: ${ApiConfig.adminDeleteStudentEndpoint(studentId)}");
      final response = await http
          .delete(
            Uri.parse(ApiConfig.adminDeleteStudentEndpoint(studentId)),
            headers: ApiConfig.getAuthHeaders(token),
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      } else {
        final error = jsonDecode(response.body);
        throw UserServiceException(
          error['message'] ?? 'Failed to delete student. Please try again.',
        );
      }
    } catch (e) {
      if (e is UserServiceException) rethrow;
      debugPrint('Delete student error: $e');
      throw UserServiceException(
          'Network error. Please check your connection.');
    }
  }

  // ========== OWNER - ADMIN MANAGEMENT ==========

  // Create Admin with Photo (Owner)
  static Future<User> createAdminOwner({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String phoneNumber,
    String role = 'admin',
    File? photo,
  }) async {
    try {
      final token = await StorageService.getToken();
      if (token == null) {
        // Trigger auto-logout when token is null
        await HttpInterceptorService.checkTokenAndHandleLogout();
        throw UserServiceException('Not authenticated. Please login again.');
      }

      debugPrint("Api Url: ${ApiConfig.ownerCreateAdminEndpoint}");
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConfig.ownerCreateAdminEndpoint),
      );

      request.headers.addAll(ApiConfig.getAuthHeadersMultipart(token));

      request.fields['FirstName'] = firstName;
      request.fields['LastName'] = lastName;
      request.fields['email'] = email;
      request.fields['password'] = password;
      request.fields['phoneNumber'] = phoneNumber;
      request.fields['role'] = role;

      if (photo != null) {
        request.files.add(
          await http.MultipartFile.fromPath('photo', photo.path),
        );
      }

      final streamedResponse = await request.send().timeout(ApiConfig.timeout);
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('Create admin status code: ${response.statusCode}');
      debugPrint('Create admin response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return User.fromJson(data['admin'] ?? data['user'] ?? data);
      } else {
        final error = jsonDecode(response.body);
        throw UserServiceException(
          error['message'] ?? 'Failed to create admin. Please try again.',
        );
      }
    } catch (e) {
      if (e is UserServiceException) rethrow;
      debugPrint('Create admin error: $e');
      throw UserServiceException(
          'Network error. Please check your connection.');
    }
  }

  // Get All Admins (Owner)
  static Future<List<User>> getAllAdmins() async {
    try {
      final token = await StorageService.getToken();
      if (token == null) {
        // Trigger auto-logout when token is null
        await HttpInterceptorService.checkTokenAndHandleLogout();
        throw UserServiceException('Not authenticated. Please login again.');
      }

      debugPrint("Api Url: ${ApiConfig.getAllAdminsEndpoint}");
      final response = await http
          .get(
            Uri.parse(ApiConfig.getAllAdminsEndpoint),
            headers: ApiConfig.getAuthHeaders(token),
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic> adminsJson =
            data is List ? data : (data['admins'] ?? data['data'] ?? []);
        return adminsJson.map((json) => User.fromJson(json)).toList();
      } else {
        final error = jsonDecode(response.body);
        throw UserServiceException(
          error['message'] ?? 'Failed to fetch admins. Please try again.',
        );
      }
    } catch (e) {
      if (e is UserServiceException) rethrow;
      debugPrint('Get all admins error: $e');
      throw UserServiceException(
          'Network error. Please check your connection.');
    }
  }

  // Update Admin with Photo (Owner)
  static Future<User> updateAdmin({
    required String adminId,
    String? firstName,
    String? phoneNumber,
    File? photo,
  }) async {
    try {
      final token = await StorageService.getToken();
      if (token == null) {
        // Trigger auto-logout when token is null
        await HttpInterceptorService.checkTokenAndHandleLogout();
        throw UserServiceException('Not authenticated. Please login again.');
      }

      debugPrint("Api Url: ${ApiConfig.ownerUpdateAdminEndpoint(adminId)}");
      final request = http.MultipartRequest(
        'PUT',
        Uri.parse(ApiConfig.ownerUpdateAdminEndpoint(adminId)),
      );

      request.headers.addAll(ApiConfig.getAuthHeadersMultipart(token));

      if (firstName != null) {
        request.fields['FirstName'] = firstName;
      }
      if (phoneNumber != null) {
        request.fields['phoneNumber'] = phoneNumber;
      }
      if (photo != null) {
        request.files.add(
          await http.MultipartFile.fromPath('photo', photo.path),
        );
      }

      final streamedResponse = await request.send().timeout(ApiConfig.timeout);
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('Update admin status code: ${response.statusCode}');
      debugPrint('Update admin response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return User.fromJson(data['admin'] ?? data['user'] ?? data);
      } else {
        final error = jsonDecode(response.body);
        throw UserServiceException(
          error['message'] ?? 'Failed to update admin. Please try again.',
        );
      }
    } catch (e) {
      if (e is UserServiceException) rethrow;
      debugPrint('Update admin error: $e');
      throw UserServiceException(
          'Network error. Please check your connection.');
    }
  }

  // Delete Admin (Owner)
  static Future<bool> deleteAdmin(String adminId) async {
    try {
      final token = await StorageService.getToken();
      if (token == null) {
        // Trigger auto-logout when token is null
        await HttpInterceptorService.checkTokenAndHandleLogout();
        throw UserServiceException('Not authenticated. Please login again.');
      }

      debugPrint("Api Url: ${ApiConfig.ownerDeleteAdminEndpoint(adminId)}");
      final response = await http
          .delete(
            Uri.parse(ApiConfig.ownerDeleteAdminEndpoint(adminId)),
            headers: ApiConfig.getAuthHeaders(token),
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      } else {
        final error = jsonDecode(response.body);
        throw UserServiceException(
          error['message'] ?? 'Failed to delete admin. Please try again.',
        );
      }
    } catch (e) {
      if (e is UserServiceException) rethrow;
      debugPrint('Delete admin error: $e');
      throw UserServiceException(
          'Network error. Please check your connection.');
    }
  }
}

class UserServiceException implements Exception {
  final String message;

  UserServiceException(this.message);

  @override
  String toString() => message;
}
