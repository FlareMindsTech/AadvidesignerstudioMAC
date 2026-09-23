import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import '../config/api_config.dart';
import '../models/course.dart';
import '../models/module.dart';
import '../models/user.dart';
import 'storage_service.dart';
import 'http_interceptor_service.dart';

class CourseService {
  // Create Course (Paid with EMI/Full Payment or Free)
  static Future<Course> createCourse({
    required String title,
    required String description,
    required String category,
    required double price,
    double? discount,
    required String createBy,
    required String duration,
    File? thumbnail,
    required bool isLiveCourse,
    required bool isRecurring,
    required int durationinDays,
    List<String>? paymentOptions, // ['EMI', 'FULL'] for paid, null for free
    int? emiDuration, // Number of EMI installments
    double? emiAmount, // Amount per installment
    String? emiPlanId, // Plan ID for EMI (optional)
  }) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw CourseServiceException('Not authenticated. Please login again.');
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConfig.createCourseEndpoint),
      );

      // Add headers
      request.headers.addAll(ApiConfig.getAuthHeadersMultipart(token));

      // Add form fields - using exact field names as shown in the form
      request.fields['title'] = title;
      request.fields['description'] = description;
      request.fields['category'] = category;
      request.fields['price'] = price.toString();
      if (discount != null) {
        request.fields['discount'] = discount.toString();
      }
      request.fields['createdBy'] =
          createBy; // Fixed: image shows 'createdBy' not 'createBy'
      request.fields['duration'] = duration;
      request.fields['isLiveCourse'] =
          isLiveCourse.toString().toLowerCase(); // Ensure lowercase true/false
      request.fields['isRecurring'] =
          isRecurring.toString().toLowerCase(); // Renewal / recurring flag
      request.fields['durationInDays'] = durationinDays
          .toString(); // Fixed: image shows 'durationInDays' with capital D
      // Build payment options (allowEMI / allowFullPayment) and EMI plans object
      bool allowEMI = false;
      bool allowFullPayment = false;

      if (paymentOptions != null && paymentOptions.isNotEmpty) {
        allowEMI = paymentOptions.contains('EMI');
        allowFullPayment = paymentOptions.contains('FULL');
      } else if (price > 0) {
        // For paid courses without explicit options, default to full payment only
        allowEMI = false;
        allowFullPayment = true;
      }

      // Send flags as separate fields (used by API)
      request.fields['allowEMI'] = allowEMI.toString().toLowerCase();
      request.fields['allowFullPayment'] =
          allowFullPayment.toString().toLowerCase();

      // Build structured paymentOptions object expected by backend
      final Map<String, dynamic> paymentOptionsObj = {
        'allowEMI': allowEMI,
        'allowFullPayment': allowFullPayment,
      };

      // If EMI is enabled and we have a single plan from the form, include it
      if (allowEMI &&
          emiDuration != null &&
          emiDuration > 0 &&
          emiAmount != null &&
          emiAmount > 0) {
        final totalAmount = emiAmount * emiDuration;
        final Map<String, dynamic> emiPlan = {
          // Match backend sample structure
          'name': '${emiDuration} months EMI',
          'installments': emiDuration,
          'interestPercent': 0,
          'perInstallmentAmount': emiAmount,
          'totalAmount': totalAmount,
        };
        // Add plan_id if provided (optional, if your backend uses it)
        if (emiPlanId != null && emiPlanId.isNotEmpty) {
          emiPlan['plan_id'] = emiPlanId;
        }
        paymentOptionsObj['emiPlans'] = [emiPlan];
      }

      // Send as JSON string in paymentOptions field
      request.fields['paymentOptions'] = jsonEncode(paymentOptionsObj);

      // Add thumbnail file if provided - image shows field name as 'thumbnail'
      if (thumbnail != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'thumbnail', // Fixed: image shows 'thumbnail' not 'thumline'
            thumbnail.path,
            filename: path.basename(thumbnail.path),
          ),
        );
      }

      debugPrint("Create Course API Url: ${ApiConfig.createCourseEndpoint}");
      debugPrint("Create Course Fields: ${request.fields}");
      debugPrint(
          "Create Course Files: ${request.files.map((f) => f.field).toList()}");
      final streamedResponse = await request.send().timeout(ApiConfig.timeout);
      final response = await http.Response.fromStream(streamedResponse);

      // Check for invalid token and handle auto-logout
      await HttpInterceptorService.checkResponseAndHandleAuth(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        debugPrint('Create Course Success: ${response.body}');
        return Course.fromJson(data['course'] ?? data);
      } else {
        debugPrint('Error Create Course: ${response.body}');
        final error = jsonDecode(response.body);
        throw CourseServiceException(
          error['message'] ?? 'Failed to create course. Please try again.',
        );
      }
    } catch (e) {
      if (e is CourseServiceException) {
        rethrow;
      }
      debugPrint('Create course error: $e');
      throw CourseServiceException(
          'Network error. Please check your connection.');
    }
  }

  // Get All Courses (No Auth, optional query params: type=recorded or type=live)
  static Future<List<Course>> getAllCourses({String? type}) async {
    try {
      debugPrint("Get All Courses API Url: ${ApiConfig.getAllCoursesEndpoint}");

      // Build URL with optional query params
      Uri url = Uri.parse(ApiConfig.getAllCoursesEndpoint);
      if (type != null && (type == 'recorded' || type == 'live')) {
        url = url.replace(queryParameters: {'type': type});
      }

      final token = await StorageService.getToken();
      
      final response = await http
          .get(
            url,
            headers: token != null 
              ? ApiConfig.getAuthHeaders(token) 
              : ApiConfig.headers,
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        // Check if response is HTML (error page)
        if (response.body.trim().startsWith('<!DOCTYPE') ||
            response.body.trim().startsWith('<html')) {
          throw CourseServiceException(
              'Invalid endpoint. Please check the API URL.');
        }

        final data = jsonDecode(response.body);
        debugPrint('Get All Courses Success: ${response.body}');

        // Handle different response formats
        List<dynamic> coursesJson;
        if (data is List) {
          coursesJson = data;
        } else if (data is Map && data['courses'] != null) {
          coursesJson = data['courses'];
        } else if (data is Map && data['data'] != null) {
          coursesJson = data['data'];
        } else {
          coursesJson = [];
        }

        return coursesJson.map((json) => Course.fromJson(json)).toList();
      } else {
        debugPrint('Error Get All Courses Status: ${response.statusCode}');
        debugPrint('Error Get All Courses Body: ${response.body}');

        // Try to parse error if it's JSON, otherwise show generic message
        try {
          if (response.body.trim().startsWith('<!DOCTYPE') ||
              response.body.trim().startsWith('<html')) {
            throw CourseServiceException(
                'Server error: ${response.statusCode}');
          }
          final error = jsonDecode(response.body);
          throw CourseServiceException(
            error['message'] ?? 'Failed to fetch courses. Please try again.',
          );
        } catch (e) {
          if (e is CourseServiceException) {
            rethrow;
          }
          throw CourseServiceException(
              'Failed to fetch courses. Status: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (e is CourseServiceException) {
        rethrow;
      }
      debugPrint('Get all courses error: $e');
      throw CourseServiceException(
          'Network error. Please check your connection.');
    }
  }

  // Get Paginated Courses
  static Future<Map<String, dynamic>> getPaginatedCourses({String? type, int page = 1, int limit = 20}) async {
    try {
      Uri url = Uri.parse(ApiConfig.getAllCoursesEndpoint);
      Map<String, String> params = {
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (type != null && (type == 'recorded' || type == 'live')) {
        params['type'] = type;
      }
      url = url.replace(queryParameters: params);

      final token = await StorageService.getToken();
      final response = await http
          .get(
            url,
            headers: token != null 
              ? ApiConfig.getAuthHeaders(token) 
              : ApiConfig.headers,
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        if (response.body.trim().startsWith('<!DOCTYPE') ||
            response.body.trim().startsWith('<html')) {
          throw CourseServiceException('Invalid endpoint.');
        }

        final data = jsonDecode(response.body);
        List<dynamic> coursesJson = data is List ? data : (data['courses'] ?? data['data'] ?? []);
        List<Course> courses = coursesJson.map((json) => Course.fromJson(json)).toList();
        
        int totalPages = 1;
        if (response.headers.containsKey('x-total-pages')) {
          totalPages = int.tryParse(response.headers['x-total-pages']!) ?? 1;
        }
        
        return {
          'courses': courses,
          'totalPages': totalPages,
        };
      } else {
        throw CourseServiceException('Failed to load courses.');
      }
    } catch (e) {
      if (e is CourseServiceException) rethrow;
      throw CourseServiceException('Network error.');
    }
  }

  // Get Single Course Details (Auth Required) - includes modules
  static Future<Course> getSingleCourse(String courseId) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw CourseServiceException('Not authenticated. Please login again.');
      }

      debugPrint(
          "Get Single Course API Url: ${ApiConfig.getSingleCourseEndpoint(courseId)}");
      final response = await http
          .get(
            Uri.parse(ApiConfig.getSingleCourseEndpoint(courseId)),
            headers: ApiConfig.getAuthHeaders(token), // Auth required
          )
          .timeout(ApiConfig.timeout);

      // Check for invalid token and handle auto-logout
      await HttpInterceptorService.checkResponseAndHandleAuth(response);

      if (response.statusCode == 200) {
        // Check if response is HTML (error page)
        if (response.body.trim().startsWith('<!DOCTYPE') ||
            response.body.trim().startsWith('<html')) {
          throw CourseServiceException(
              'Invalid endpoint. Please check the API URL.');
        }

        final data = jsonDecode(response.body);
        debugPrint('Get Single Course Success: ${response.body}');

        // Handle different response formats
        Map<String, dynamic> courseJson;
        if (data is Map && data['course'] != null) {
          courseJson = Map<String, dynamic>.from(data['course'] as Map);
        } else if (data is Map && data['data'] != null) {
          courseJson = Map<String, dynamic>.from(data['data'] as Map);
        } else if (data is Map) {
          courseJson = Map<String, dynamic>.from(data);
        } else {
          throw CourseServiceException('Invalid response format.');
        }

        return Course.fromJson(courseJson);
      } else {
        debugPrint('Error Get Single Course Status: ${response.statusCode}');
        debugPrint('Error Get Single Course Body: ${response.body}');

        // Try to parse error if it's JSON, otherwise show generic message
        try {
          if (response.body.trim().startsWith('<!DOCTYPE') ||
              response.body.trim().startsWith('<html')) {
            throw CourseServiceException(
                'Server error: ${response.statusCode}');
          }
          final error = jsonDecode(response.body);
          throw CourseServiceException(
            error['message'] ?? 'Failed to fetch course. Please try again.',
          );
        } catch (e) {
          if (e is CourseServiceException) {
            rethrow;
          }
          throw CourseServiceException(
              'Failed to fetch course. Status: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (e is CourseServiceException) {
        rethrow;
      }
      debugPrint('Get single course error: $e');
      throw CourseServiceException(
          'Network error. Please check your connection.');
    }
  }

  // Get Single Course Details with Modules - returns course info + modules list
  static Future<CourseWithModules> getSingleCourseWithModules(
      String courseId) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw CourseServiceException('Not authenticated. Please login again.');
      }

      debugPrint(
          "Get Single Course with Modules API Url: ${ApiConfig.getSingleCourseEndpoint(courseId)}");
      final response = await http
          .get(
            Uri.parse(ApiConfig.getSingleCourseEndpoint(courseId)),
            headers: ApiConfig.getAuthHeaders(token), // Auth required
          )
          .timeout(ApiConfig.timeout);

      // Check for invalid token and handle auto-logout
      await HttpInterceptorService.checkResponseAndHandleAuth(response);

      if (response.statusCode == 200) {
        // Check if response is HTML (error page)
        if (response.body.trim().startsWith('<!DOCTYPE') ||
            response.body.trim().startsWith('<html')) {
          throw CourseServiceException(
              'Invalid endpoint. Please check the API URL.');
        }

        final data = jsonDecode(response.body);
        debugPrint('Get Single Course with Modules Success: ${response.body}');

        // Handle different response formats
        Map<String, dynamic> courseJson;
        if (data is Map && data['course'] != null) {
          courseJson = Map<String, dynamic>.from(data['course'] as Map);
        } else if (data is Map && data['data'] != null) {
          courseJson = Map<String, dynamic>.from(data['data'] as Map);
        } else if (data is Map) {
          courseJson = Map<String, dynamic>.from(data);
        } else {
          throw CourseServiceException('Invalid response format.');
        }

        // Parse course
        final course = Course.fromJson(courseJson);

        // Parse modules if they exist in the response
        List<Module> modules = [];
        if (courseJson['modules'] != null && courseJson['modules'] is List) {
          try {
            modules = (courseJson['modules'] as List)
                .map((moduleJson) => Module.fromJson(
                    Map<String, dynamic>.from(moduleJson as Map)))
                .toList();
          } catch (e) {
            debugPrint('Error parsing modules: $e');
            // Continue with empty modules list if parsing fails
          }
        }

        return CourseWithModules(course: course, modules: modules);
      } else {
        debugPrint(
            'Error Get Single Course with Modules Status: ${response.statusCode}');
        debugPrint(
            'Error Get Single Course with Modules Body: ${response.body}');

        // Try to parse error if it's JSON, otherwise show generic message
        try {
          if (response.body.trim().startsWith('<!DOCTYPE') ||
              response.body.trim().startsWith('<html')) {
            throw CourseServiceException(
                'Server error: ${response.statusCode}');
          }
          final error = jsonDecode(response.body);
          throw CourseServiceException(
            error['message'] ?? 'Failed to fetch course. Please try again.',
          );
        } catch (e) {
          if (e is CourseServiceException) {
            rethrow;
          }
          throw CourseServiceException(
              'Failed to fetch course. Status: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (e is CourseServiceException) {
        rethrow;
      }
      debugPrint('Get single course with modules error: $e');
      throw CourseServiceException(
          'Network error. Please check your connection.');
    }
  }

  // Update Course
  static Future<Course> updateCourse({
    required String courseId,
    String? title,
    String? description,
    String? category,
    double? price,
    double? discount,
    String? createBy,
    String? duration,
    File? thumbnail,
    bool? isLiveCourse,
    bool? isRecurring,
    int? durationinDays,
    List<String>? paymentOptions,
    int? emiDuration, // Number of EMI installments
    double? emiAmount, // Amount per installment
    String? emiPlanId, // Plan ID for EMI (optional)
  }) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw CourseServiceException('Not authenticated. Please login again.');
      }

      var request = http.MultipartRequest(
        'PUT',
        Uri.parse(ApiConfig.updateCourseEndpoint(courseId)),
      );

      // Add headers
      request.headers.addAll(ApiConfig.getAuthHeadersMultipart(token));

      // Add form fields only if provided - using exact field names as shown in the form
      if (title != null) request.fields['title'] = title;
      if (description != null) request.fields['description'] = description;
      if (category != null) request.fields['category'] = category;
      if (price != null) request.fields['price'] = price.toString();
      if (discount != null) {
        request.fields['discount'] = discount.toString();
      }
      if (createBy != null)
        request.fields['createdBy'] =
            createBy; // Fixed: image shows 'createdBy'
      if (duration != null) request.fields['duration'] = duration;
      if (isLiveCourse != null)
        request.fields['isLiveCourse'] = isLiveCourse.toString().toLowerCase();
      if (isRecurring != null) {
        request.fields['isRecurring'] =
            isRecurring.toString().toLowerCase(); // Renewal / recurring flag
      }
      if (durationinDays != null) {
        request.fields['durationInDays'] =
            durationinDays.toString(); // Fixed: image shows 'durationInDays'
      }
      // Build payment options (allowEMI / allowFullPayment) and EMI plans object
      if (paymentOptions != null && paymentOptions.isNotEmpty) {
        final allowEMI = paymentOptions.contains('EMI');
        final allowFullPayment = paymentOptions.contains('FULL');

        // Send flags as separate fields (used by API)
        request.fields['allowEMI'] = allowEMI.toString().toLowerCase();
        request.fields['allowFullPayment'] =
            allowFullPayment.toString().toLowerCase();

        // Build structured paymentOptions object expected by backend
        final Map<String, dynamic> paymentOptionsObj = {
          'allowEMI': allowEMI,
          'allowFullPayment': allowFullPayment,
        };

        // If EMI is enabled and we have a single plan from the form, include it
        if (allowEMI &&
            emiDuration != null &&
            emiDuration > 0 &&
            emiAmount != null &&
            emiAmount > 0) {
          final totalAmount = emiAmount * emiDuration;
          final Map<String, dynamic> emiPlan = {
            // Match backend sample structure
            'name': '${emiDuration} months EMI',
            'installments': emiDuration,
            'interestPercent': 0,
            'perInstallmentAmount': emiAmount,
            'totalAmount': totalAmount,
          };
          // Add plan_id if provided (optional, if your backend uses it)
          if (emiPlanId != null && emiPlanId.isNotEmpty) {
            emiPlan['plan_id'] = emiPlanId;
          }
          paymentOptionsObj['emiPlans'] = [emiPlan];
        }

        // Send as JSON string in paymentOptions field
        request.fields['paymentOptions'] = jsonEncode(paymentOptionsObj);
      }

      // Add thumbnail file if provided
      if (thumbnail != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'thumbnail',
            thumbnail.path,
            filename: path.basename(thumbnail.path),
          ),
        );
      }

      // Debug: log request fields and attached files for update
      debugPrint(
          "Update Course API Url: ${ApiConfig.updateCourseEndpoint(courseId)}");
      debugPrint("Update Course Fields: ${request.fields}");
      debugPrint(
          "Update Course Files: ${request.files.map((f) => f.field).toList()}");
      final streamedResponse = await request.send().timeout(ApiConfig.timeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        debugPrint('Update Course Success: ${response.body}');
        return Course.fromJson(data['course'] ?? data);
      } else {
        debugPrint('Error Update Course: ${response.body}');
        final error = jsonDecode(response.body);
        throw CourseServiceException(
          error['message'] ?? 'Failed to update course. Please try again.',
        );
      }
    } catch (e) {
      if (e is CourseServiceException) {
        rethrow;
      }
      debugPrint('Update course error: $e');
      throw CourseServiceException(
          'Network error. Please check your connection.');
    }
  }

  // Delete Course
  static Future<bool> deleteCourse(String courseId) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw CourseServiceException('Not authenticated. Please login again.');
      }

      debugPrint(
          "Delete Course API Url: ${ApiConfig.deleteCourseEndpoint(courseId)}");
      final response = await http
          .delete(
            Uri.parse(ApiConfig.deleteCourseEndpoint(courseId)),
            headers: ApiConfig.getAuthHeaders(token),
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200 || response.statusCode == 204) {
        debugPrint('Delete Course Success');
        return true;
      } else {
        debugPrint('Error Delete Course: ${response.body}');
        final error = jsonDecode(response.body);
        throw CourseServiceException(
          error['message'] ?? 'Failed to delete course. Please try again.',
        );
      }
    } catch (e) {
      if (e is CourseServiceException) {
        rethrow;
      }
      debugPrint('Delete course error: $e');
      throw CourseServiceException(
          'Network error. Please check your connection.');
    }
  }

  // Get Enrolled Students for a specific course (Admin Token)
  static Future<List<User>> getEnrolledStudents(String courseId) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw CourseServiceException('Not authenticated. Please login again.');
      }

      debugPrint(
          "Get Enrolled Students API Url: ${ApiConfig.getEnrolledStudentsEndpoint(courseId)}");
      final response = await http
          .get(
            Uri.parse(ApiConfig.getEnrolledStudentsEndpoint(courseId)),
            headers: ApiConfig.getAuthHeaders(token),
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        // Check if response is HTML (error page)
        if (response.body.trim().startsWith('<!DOCTYPE') ||
            response.body.trim().startsWith('<html')) {
          throw CourseServiceException(
              'Invalid endpoint. Please check the API URL.');
        }

        final data = jsonDecode(response.body);
        debugPrint('Get Enrolled Students Success: ${response.body}');

        // Handle different response formats
        List<dynamic> studentsJson;
        if (data is List) {
          studentsJson = data;
        } else if (data is Map && data['students'] != null) {
          studentsJson = data['students'];
        } else if (data is Map && data['data'] != null) {
          studentsJson = data['data'];
        } else {
          studentsJson = [];
        }

        // Parse enrolled students - API returns different format
        return studentsJson.map((json) {
          // Handle the enrolled students API format which has 'username' instead of 'FirstName'/'LastName'
          if (json is Map<String, dynamic>) {
            // If it has 'username', parse it differently
            if (json.containsKey('username') &&
                !json.containsKey('FirstName')) {
              final username = json['username'] as String? ?? '';
              // Split username into first and last name
              final nameParts = username.trim().split(' ');
              final firstName = nameParts.isNotEmpty ? nameParts[0] : '';
              final lastName =
                  nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

              // Parse subscription dates
              final subscribedAt = json['subscribedAt'] != null
                  ? DateTime.tryParse(json['subscribedAt'].toString())
                  : null;
              final expiresAt = json['expiresAt'] != null
                  ? DateTime.tryParse(json['expiresAt'].toString())
                  : null;

              return User(
                id: json['_id'] as String?,
                firstName: firstName.isNotEmpty ? firstName : null,
                lastName: lastName.isNotEmpty ? lastName : null,
                email: json['email'] as String? ?? '',
                role: json['role'] as String? ??
                    'student', // Default to 'student' if not provided
                phoneNumber: json['phoneNumber'] as String?,
                isActive: json['isActive'] as bool? ?? true,
                createdAt: subscribedAt ??
                    (json['createdAt'] != null
                        ? DateTime.tryParse(json['createdAt'].toString())
                        : null),
                updatedAt: expiresAt ??
                    (json['updatedAt'] != null
                        ? DateTime.tryParse(json['updatedAt'].toString())
                        : null),
              );
            } else {
              // Standard User format
              try {
                return User.fromJson(json);
              } catch (e) {
                // Fallback if parsing fails
                return User(
                  id: json['_id'] as String?,
                  firstName: json['FirstName'] as String?,
                  lastName: json['LastName'] as String?,
                  email: json['email'] as String? ?? '',
                  role: json['role'] as String? ?? 'student',
                  phoneNumber: json['phoneNumber'] as String?,
                  isActive: json['isActive'] as bool? ?? true,
                );
              }
            }
          }
          // Fallback
          return User(
            email: '',
            role: 'student',
          );
        }).toList();
      } else {
        debugPrint(
            'Error Get Enrolled Students Status: ${response.statusCode}');
        debugPrint('Error Get Enrolled Students Body: ${response.body}');

        // Try to parse error if it's JSON, otherwise show generic message
        try {
          if (response.body.trim().startsWith('<!DOCTYPE') ||
              response.body.trim().startsWith('<html')) {
            throw CourseServiceException(
                'Server error: ${response.statusCode}');
          }
          final error = jsonDecode(response.body);
          throw CourseServiceException(
            error['message'] ??
                'Failed to fetch enrolled students. Please try again.',
          );
        } catch (e) {
          if (e is CourseServiceException) {
            rethrow;
          }
          throw CourseServiceException(
              'Failed to fetch enrolled students. Status: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (e is CourseServiceException) {
        rethrow;
      }
      debugPrint('Get enrolled students error: $e');
      throw CourseServiceException(
          'Network error. Please check your connection.');
    }
  }

  // Manually enroll a student (Admin only)
  static Future<bool> manualEnroll({
    required String studentId,
    required String courseId,
  }) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw CourseServiceException('Not authenticated. Please login again.');
      }

      debugPrint("Manual Enroll API Url: ${ApiConfig.manualEnrollEndpoint}");
      final response = await http
          .post(
            Uri.parse(ApiConfig.manualEnrollEndpoint),
            headers: ApiConfig.getAuthHeaders(token),
            body: jsonEncode({
              'student_id': studentId,
              'course_id': courseId,
            }),
          )
          .timeout(ApiConfig.timeout);

      // Check for invalid token and handle auto-logout
      await HttpInterceptorService.checkResponseAndHandleAuth(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('Manual Enroll Success: ${response.body}');
        return true;
      } else {
        debugPrint('Error Manual Enroll status: ${response.statusCode}');
        debugPrint('Error Manual Enroll Body: ${response.body}');
        final error = jsonDecode(response.body);
        throw CourseServiceException(
          error['message'] ?? 'Failed to enroll student. Please try again.',
        );
      }
    } catch (e) {
      if (e is CourseServiceException) {
        rethrow;
      }
      debugPrint('Manual enroll error: $e');
      throw CourseServiceException(
          'Network error. Please check your connection.');
    }
  }
}

// Helper class to hold Course with Modules
class CourseWithModules {
  final Course course;
  final List<Module> modules;

  CourseWithModules({
    required this.course,
    required this.modules,
  });
}

class CourseServiceException implements Exception {
  final String message;

  CourseServiceException(this.message);

  @override
  String toString() => message;
}
