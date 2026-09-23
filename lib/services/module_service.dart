import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../models/module.dart';
import '../models/submodule.dart';
import 'storage_service.dart';
import 'http_interceptor_service.dart';

class ModuleService {
  // Get Course Modules (No Auth)
  static Future<List<Module>> getCourseModules(String courseId) async {
    try {
      final url = ApiConfig.getCourseModulesEndpoint(courseId);
      debugPrint("Get Course Modules API Url: $url");
      final response = await http
          .get(
            Uri.parse(url),
            headers: ApiConfig.headers,
          )
          .timeout(ApiConfig.timeout);

      debugPrint('Get Course Modules Status Code: ${response.statusCode}');
      debugPrint('Get Course Modules Response: ${response.body}');

      // Check if response is HTML (error page)
      if (response.body.trim().startsWith('<!DOCTYPE') ||
          response.body.trim().startsWith('<html')) {
        debugPrint('Error: Received HTML response instead of JSON');
        throw ModuleServiceException(
          'Invalid endpoint. Please check the API configuration.',
        );
      }

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          debugPrint('Get Course Modules Success: ${response.body}');

          List<dynamic> modulesJson;
          if (data is List) {
            modulesJson = data;
          } else if (data is Map && data['modules'] != null) {
            modulesJson = data['modules'];
          } else if (data is Map && data['data'] != null) {
            modulesJson = data['data'];
          } else {
            modulesJson = [];
          }

          return modulesJson.map((json) => Module.fromJson(json)).toList()
            ..sort((a, b) => a.order.compareTo(b.order));
        } catch (e) {
          debugPrint('JSON decode error: $e');
          throw ModuleServiceException(
            'Invalid response format. Please try again.',
          );
        }
      } else if (response.statusCode == 404) {
        // Handle 404 - check if it's "No modules found" (valid state) or actual error
        try {
          final error = jsonDecode(response.body);
          final message = error['message'] ?? '';

          // If the message indicates no modules found, return empty list (valid state)
          if (message.toLowerCase().contains('no modules found') ||
              message.toLowerCase().contains('no module')) {
            debugPrint(
                'No modules found for this course - returning empty list');
            return [];
          } else {
            // Actual 404 error
            throw ModuleServiceException(
              message.isNotEmpty
                  ? message
                  : 'Course not found. Please try again.',
            );
          }
        } catch (e) {
          if (e is ModuleServiceException) {
            rethrow;
          }
          // If can't parse JSON, assume it's a "no modules" case
          debugPrint('404 response - assuming no modules found');
          return [];
        }
      } else {
        debugPrint('Error Get Course Modules: ${response.body}');
        // Try to parse error message
        try {
          final error = jsonDecode(response.body);
          throw ModuleServiceException(
            error['message'] ?? 'Failed to fetch modules. Please try again.',
          );
        } catch (e) {
          // If not JSON, return generic error
          throw ModuleServiceException(
            'Failed to fetch modules (Status: ${response.statusCode}). Please try again.',
          );
        }
      }
    } catch (e) {
      if (e is ModuleServiceException) {
        rethrow;
      }
      debugPrint('Get course modules error: $e');
      throw ModuleServiceException(
          'Network error. Please check your connection.');
    }
  }

  // Enroll Student in Free Course
  static Future<void> enrollInCourse(String courseId) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw ModuleServiceException('Not authenticated. Please login again.');
      }

      debugPrint(
          "Enroll Course API Url: ${ApiConfig.enrollCourseEndpoint(courseId)}");
      final response = await http
          .post(
            Uri.parse(ApiConfig.enrollCourseEndpoint(courseId)),
            headers: ApiConfig.getAuthHeaders(token),
          )
          .timeout(ApiConfig.timeout);

      // Check for invalid token and handle auto-logout
      await HttpInterceptorService.checkResponseAndHandleAuth(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('Enroll Course Success: ${response.body}');
        return;
      } else {
        debugPrint('Error Enroll Course: ${response.body}');
        final error = jsonDecode(response.body);
        throw ModuleServiceException(
          error['message'] ?? 'Failed to enroll in course. Please try again.',
        );
      }
    } catch (e) {
      if (e is ModuleServiceException) {
        rethrow;
      }
      debugPrint('Enroll course error: $e');
      throw ModuleServiceException(
          'Network error. Please check your connection.');
    }
  }

  // Add Module to Course (Admin)
  static Future<Module> addModule({
    required String courseId,
    required String title,
    required int order,
  }) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw ModuleServiceException('Not authenticated. Please login again.');
      }

      debugPrint(
          "Add Module API Url: ${ApiConfig.addModuleEndpoint(courseId)}");
      final response = await http
          .post(
            Uri.parse(ApiConfig.addModuleEndpoint(courseId)),
            headers: ApiConfig.getAuthHeaders(token),
            body: jsonEncode({
              'title': title,
              'order': order,
            }),
          )
          .timeout(ApiConfig.timeout);

      // Check for invalid token and handle auto-logout
      await HttpInterceptorService.checkResponseAndHandleAuth(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        debugPrint('Add Module Success: ${response.body}');
        return Module.fromJson(data['module'] ?? data);
      } else {
        debugPrint('Error Add Module: ${response.body}');
        final error = jsonDecode(response.body);
        throw ModuleServiceException(
          error['message'] ?? 'Failed to add module. Please try again.',
        );
      }
    } catch (e) {
      if (e is ModuleServiceException) {
        rethrow;
      }
      debugPrint('Add module error: $e');
      throw ModuleServiceException(
          'Network error. Please check your connection.');
    }
  }

  // Update Module (Admin)
  static Future<Module> updateModule({
    required String moduleId,
    String? title,
    int? order,
  }) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw ModuleServiceException('Not authenticated. Please login again.');
      }

      final body = <String, dynamic>{};
      if (title != null) body['title'] = title;
      if (order != null) body['order'] = order;

      debugPrint(
          "Update Module API Url: ${ApiConfig.updateModuleEndpoint(moduleId)}");
      final response = await http
          .put(
            Uri.parse(ApiConfig.updateModuleEndpoint(moduleId)),
            headers: ApiConfig.getAuthHeaders(token),
            body: jsonEncode(body),
          )
          .timeout(ApiConfig.timeout);

      // Check for invalid token and handle auto-logout
      await HttpInterceptorService.checkResponseAndHandleAuth(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        debugPrint('Update Module Success: ${response.body}');
        return Module.fromJson(data['module'] ?? data);
      } else {
        debugPrint('Error Update Module: ${response.body}');
        final error = jsonDecode(response.body);
        throw ModuleServiceException(
          error['message'] ?? 'Failed to update module. Please try again.',
        );
      }
    } catch (e) {
      if (e is ModuleServiceException) {
        rethrow;
      }
      debugPrint('Update module error: $e');
      throw ModuleServiceException(
          'Network error. Please check your connection.');
    }
  }


  // Delete SubModule (Admin)
  static Future<void> deleteSubModule(String subModuleId) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw ModuleServiceException('Not authenticated');
      }

      final response = await http.delete(
        Uri.parse(ApiConfig.deleteSubModuleEndpoint(subModuleId)),
        headers: ApiConfig.getAuthHeaders(token),
      );

      if (response.statusCode != 200) {
        final body = jsonDecode(response.body);
        throw ModuleServiceException(
            body['message'] ?? 'Failed to delete sub-topic');
      }
    } catch (e) {
      if (e is ModuleServiceException) rethrow;
      throw ModuleServiceException(
          'Network error. Please check your connection.');
    }
  }

  // Delete Module (Admin)
  static Future<void> deleteModule(String moduleId) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw ModuleServiceException('Not authenticated. Please login again.');
      }

      debugPrint(
          "Delete Module API Url: ${ApiConfig.deleteModuleEndpoint(moduleId)}");
      final response = await http
          .delete(
            Uri.parse(ApiConfig.deleteModuleEndpoint(moduleId)),
            headers: ApiConfig.getAuthHeaders(token),
          )
          .timeout(ApiConfig.timeout);

      // Check for invalid token and handle auto-logout
      await HttpInterceptorService.checkResponseAndHandleAuth(response);

      if (response.statusCode == 200 || response.statusCode == 204) {
        debugPrint('Delete Module Success: ${response.body}');
        return;
      } else {
        debugPrint('Error Delete Module: ${response.body}');
        final error = jsonDecode(response.body);
        throw ModuleServiceException(
          error['message'] ?? 'Failed to delete module. Please try again.',
        );
      }
    } catch (e) {
      if (e is ModuleServiceException) {
        rethrow;
      }
      debugPrint('Delete module error: $e');
      throw ModuleServiceException(
          'Network error. Please check your connection.');
    }
  }

  // Create SubModule (Sub-Topic) under a Module (Admin)
  static Future<SubModule> createSubModule({
    required String moduleId,
    required String title,
    required int order,
    String? parentSubModule,
  }) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw ModuleServiceException('Not authenticated. Please login again.');
      }

      debugPrint(
          "Create SubModule API Url: ${ApiConfig.addSubModuleEndpoint(moduleId)}");
      final response = await http
          .post(
            Uri.parse(ApiConfig.addSubModuleEndpoint(moduleId)),
            headers: ApiConfig.getAuthHeaders(token),
            body: jsonEncode({
              'title': title,
              'order': order,
              if (parentSubModule != null) 'parentSubModule': parentSubModule,
            }),
          )
          .timeout(ApiConfig.timeout);

      print("Submodule Url: ${ApiConfig.addSubModuleEndpoint(moduleId)}");

      // Check for invalid token and handle auto-logout
      await HttpInterceptorService.checkResponseAndHandleAuth(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        debugPrint('Create SubModule Success: ${response.body}');
        return SubModule.fromJson(data['submodule'] ?? data);
      } else {
        debugPrint('Error Create SubModule: ${response.body}');
        final error = jsonDecode(response.body);
        throw ModuleServiceException(
          error['message'] ?? 'Failed to create submodule. Please try again.',
        );
      }
    } catch (e) {
      if (e is ModuleServiceException) {
        rethrow;
      }
      debugPrint('Create submodule error: $e');
      throw ModuleServiceException(
          'Network error. Please check your connection.');
    }
  }

  // Update SubModule (Sub-Topic) (Admin)
  static Future<SubModule> updateSubModule({
    required String subModuleId,
    String? title,
    int? order,
  }) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw ModuleServiceException('Not authenticated. Please login again.');
      }

      final body = <String, dynamic>{};
      if (title != null) body['title'] = title;
      if (order != null) body['order'] = order;

      debugPrint(
          "Update SubModule API Url: ${ApiConfig.updateSubModuleEndpoint(subModuleId)}");
      final response = await http
          .put(
            Uri.parse(ApiConfig.updateSubModuleEndpoint(subModuleId)),
            headers: ApiConfig.getAuthHeaders(token),
            body: jsonEncode(body),
          )
          .timeout(ApiConfig.timeout);

      // Check for invalid token and handle auto-logout
      await HttpInterceptorService.checkResponseAndHandleAuth(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        debugPrint('Update SubModule Success: ${response.body}');
        return SubModule.fromJson(data['submodule'] ?? data);
      } else {
        debugPrint('Error Update SubModule: ${response.body}');
        final error = jsonDecode(response.body);
        throw ModuleServiceException(
          error['message'] ?? 'Failed to update submodule. Please try again.',
        );
      }
    } catch (e) {
      if (e is ModuleServiceException) {
        rethrow;
      }
      debugPrint('Update submodule error: $e');
      throw ModuleServiceException(
          'Network error. Please check your connection.');
    }
  }
}

class ModuleServiceException implements Exception {
  final String message;

  ModuleServiceException(this.message);

  @override
  String toString() => message;
}
