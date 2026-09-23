import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../models/course_progress.dart';
import 'storage_service.dart';
import 'http_interceptor_service.dart';

class ProgressService {
  // Mark Lesson as Complete
  static Future<int> markLessonComplete(String lessonId) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw ProgressServiceException('Not authenticated. Please login again.');
      }

      debugPrint("Mark Lesson Complete API Url: ${ApiConfig.markLessonCompleteEndpoint(lessonId)}");
      final response = await http
          .post(
            Uri.parse(ApiConfig.markLessonCompleteEndpoint(lessonId)),
            headers: ApiConfig.getAuthHeaders(token),
          )
          .timeout(ApiConfig.timeout);

      // Check for invalid token and handle auto-logout
      await HttpInterceptorService.checkResponseAndHandleAuth(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        debugPrint('Mark Lesson Complete Success: ${response.body}');
        
        // Return the new percentage completed
        return data['percentageCompleted'] ?? data['percentage'] ?? 0;
      } else {
        debugPrint('Error Mark Lesson Complete Status: ${response.statusCode}');
        debugPrint('Error Mark Lesson Complete Body: ${response.body}');
        final error = jsonDecode(response.body);
        throw ProgressServiceException(
          error['message'] ?? 'Failed to mark lesson as complete. Please try again.',
        );
      }
    } catch (e) {
      if (e is ProgressServiceException) {
        rethrow;
      }
      debugPrint('Mark lesson complete error: $e');
      throw ProgressServiceException('Failed to mark lesson as complete. Please try again.');
    }
  }

  // Get My Course Progress
  static Future<List<CourseProgress>> getCourseProgress() async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw ProgressServiceException('Not authenticated. Please login again.');
      }

      debugPrint("Get Course Progress API Url: ${ApiConfig.getCourseProgressEndpoint}");
      final response = await http
          .get(
            Uri.parse(ApiConfig.getCourseProgressEndpoint),
            headers: ApiConfig.getAuthHeaders(token),
          )
          .timeout(ApiConfig.timeout);

      // Check for invalid token and handle auto-logout
      await HttpInterceptorService.checkResponseAndHandleAuth(response);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('Get Course Progress Success: ${response.body}');
        
        List<dynamic> progressJson;
        if (data is List) {
          progressJson = data;
        } else if (data is Map && data['courses'] != null) {
          progressJson = data['courses'];
        } else if (data is Map && data['data'] != null) {
          progressJson = data['data'];
        } else {
          progressJson = [];
        }

        return progressJson.map((json) => CourseProgress.fromJson(json)).toList();
      } else {
        debugPrint('Error Get Course Progress Status: ${response.statusCode}');
        debugPrint('Error Get Course Progress Body: ${response.body}');
        final error = jsonDecode(response.body);
        throw ProgressServiceException(
          error['message'] ?? 'Failed to fetch course progress. Please try again.',
        );
      }
    } catch (e) {
      if (e is ProgressServiceException) {
        rethrow;
      }
      debugPrint('Get course progress error: $e');
      throw ProgressServiceException('Failed to fetch course progress. Please try again.');
    }
  }

  // Get Specific Module Progress
  static Future<ModuleProgress> getModuleProgress(String moduleId) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw ProgressServiceException('Not authenticated. Please login again.');
      }

      debugPrint("Get Module Progress API Url: ${ApiConfig.getModuleProgressEndpoint(moduleId)}");
      final response = await http
          .get(
            Uri.parse(ApiConfig.getModuleProgressEndpoint(moduleId)),
            headers: ApiConfig.getAuthHeaders(token),
          )
          .timeout(ApiConfig.timeout);

      // Check for invalid token and handle auto-logout
      await HttpInterceptorService.checkResponseAndHandleAuth(response);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('Get Module Progress Success: ${response.body}');
        
        return ModuleProgress.fromJson(data);
      } else {
        debugPrint('Error Get Module Progress Status: ${response.statusCode}');
        debugPrint('Error Get Module Progress Body: ${response.body}');
        final error = jsonDecode(response.body);
        throw ProgressServiceException(
          error['message'] ?? 'Failed to fetch module progress. Please try again.',
        );
      }
    } catch (e) {
      if (e is ProgressServiceException) {
        rethrow;
      }
      debugPrint('Get module progress error: $e');
      throw ProgressServiceException('Failed to fetch module progress. Please try again.');
    }
  }
}

class ProgressServiceException implements Exception {
  final String message;
  ProgressServiceException(this.message);

  @override
  String toString() => message;
}

