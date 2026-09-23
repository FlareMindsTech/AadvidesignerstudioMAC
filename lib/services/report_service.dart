import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:meeting_app/services/http_interceptor_service.dart';
import '../config/api_config.dart';
import '../models/report.dart';
import 'storage_service.dart';

class ReportService {
  // Get Course Performance Report
  static Future<CoursePerformanceReport> getCoursePerformanceReport() async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw ReportServiceException('Not authenticated. Please login again.');
      }

      debugPrint(
          "Get Course Performance Report API Url: ${ApiConfig.coursePerformanceReportEndpoint}");
      final response = await http
          .get(
            Uri.parse(ApiConfig.coursePerformanceReportEndpoint),
            headers: ApiConfig.getAuthHeaders(token),
          )
          .timeout(ApiConfig.timeout);

      // Check for invalid token and handle auto-logout
      await HttpInterceptorService.checkResponseAndHandleAuth(response);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('Get Course Performance Report Success: ${response.body}');

        // Handle both list and map responses
        if (data is List) {
          // If response is a list directly, wrap it in a map
          return CoursePerformanceReport.fromJson({'courses': data});
        } else if (data is Map<String, dynamic>) {
          return CoursePerformanceReport.fromJson(data);
        } else {
          // Empty response
          return CoursePerformanceReport.fromJson({'courses': []});
        }
      } else {
        debugPrint(
            'Error Get Course Performance Report Status: ${response.statusCode}');
        debugPrint(
            'Error Get Course Performance Report Body: ${response.body}');
        final error = jsonDecode(response.body);
        throw ReportServiceException(
          error['message'] ??
              'Failed to fetch course performance report. Please try again.',
        );
      }
    } catch (e) {
      if (e is ReportServiceException) {
        rethrow;
      }
      debugPrint('Get course performance report error: $e');
      throw ReportServiceException(
          'Network error. Please check your connection.');
    }
  }

  // Get Student Activity Report
  static Future<StudentActivityReport> getStudentActivityReport() async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw ReportServiceException('Not authenticated. Please login again.');
      }

      debugPrint(
          "Get Student Activity Report API Url: ${ApiConfig.studentActivityReportEndpoint}");
      final response = await http
          .get(
            Uri.parse(ApiConfig.studentActivityReportEndpoint),
            headers: ApiConfig.getAuthHeaders(token),
          )
          .timeout(ApiConfig.timeout);

      // Check for invalid token and handle auto-logout
      await HttpInterceptorService.checkResponseAndHandleAuth(response);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('Get Student Activity Report Success: ${response.body}');
        return StudentActivityReport.fromJson(data);
      } else {
        debugPrint(
            'Error Get Student Activity Report Status: ${response.statusCode}');
        debugPrint('Error Get Student Activity Report Body: ${response.body}');
        final error = jsonDecode(response.body);
        throw ReportServiceException(
          error['message'] ??
              'Failed to fetch student activity report. Please try again.',
        );
      }
    } catch (e) {
      if (e is ReportServiceException) {
        rethrow;
      }
      debugPrint('Get student activity report error: $e');
      throw ReportServiceException(
          'Network error. Please check your connection.');
    }
  }

  // Get Quiz Performance Report
  static Future<QuizPerformanceReport> getQuizPerformanceReport() async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw ReportServiceException('Not authenticated. Please login again.');
      }

      debugPrint(
          "Get Quiz Performance Report API Url: ${ApiConfig.quizPerformanceReportEndpoint}");
      final response = await http
          .get(
            Uri.parse(ApiConfig.quizPerformanceReportEndpoint),
            headers: ApiConfig.getAuthHeaders(token),
          )
          .timeout(ApiConfig.timeout);

      // Check for invalid token and handle auto-logout
      await HttpInterceptorService.checkResponseAndHandleAuth(response);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('Get Quiz Performance Report Success: ${response.body}');

        // Handle both list and map responses
        if (data is List) {
          // If response is a list directly, wrap it in a map
          return QuizPerformanceReport.fromJson({'quizzes': data});
        } else if (data is Map<String, dynamic>) {
          return QuizPerformanceReport.fromJson(data);
        } else {
          // Empty response
          return QuizPerformanceReport.fromJson({'quizzes': []});
        }
      } else {
        debugPrint(
            'Error Get Quiz Performance Report Status: ${response.statusCode}');
        debugPrint('Error Get Quiz Performance Report Body: ${response.body}');
        final error = jsonDecode(response.body);
        throw ReportServiceException(
          error['message'] ??
              'Failed to fetch quiz performance report. Please try again.',
        );
      }
    } catch (e) {
      if (e is ReportServiceException) {
        rethrow;
      }
      debugPrint('Get quiz performance report error: $e');
      throw ReportServiceException(
          'Network error. Please check your connection.');
    }
  }
}

class ReportServiceException implements Exception {
  final String message;

  ReportServiceException(this.message);

  @override
  String toString() => message;
}
