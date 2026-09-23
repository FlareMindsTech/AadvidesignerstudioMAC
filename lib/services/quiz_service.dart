import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../models/quiz.dart';
import '../models/question.dart';
import 'storage_service.dart';
import 'http_interceptor_service.dart';

class QuizService {
  // Create Quiz
  static Future<Quiz> createQuiz({
    required String moduleId,
    required String title,
    required List<Question> questions,
  }) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw QuizServiceException('Not authenticated. Please login again.');
      }

      final body = {
        'moduleId': moduleId,
        'title': title,
        'questions': questions.map((q) => q.toJson()).toList(),
      };

      debugPrint("Create Quiz API Url: ${ApiConfig.createQuizEndpoint}");
      debugPrint("Create Quiz Body: ${jsonEncode(body)}");
      
      final response = await http
          .post(
            Uri.parse(ApiConfig.createQuizEndpoint),
            headers: ApiConfig.getAuthHeaders(token),
            body: jsonEncode(body),
          )
          .timeout(ApiConfig.timeout);

      // Check for invalid token and handle auto-logout
      await HttpInterceptorService.checkResponseAndHandleAuth(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        debugPrint('Create Quiz Success: ${response.body}');
        return Quiz.fromJson(data['quiz'] ?? data);
      } else {
        debugPrint('Error Create Quiz Status: ${response.statusCode}');
        debugPrint('Error Create Quiz Body: ${response.body}');
        final error = jsonDecode(response.body);
        throw QuizServiceException(
          error['message'] ?? 'Failed to create quiz. Please try again.',
        );
      }
    } catch (e) {
      if (e is QuizServiceException) {
        rethrow;
      }
      debugPrint('Create quiz error: $e');
      throw QuizServiceException(
          'Network error. Please check your connection.');
    }
  }

  // Get All Quizzes
  static Future<List<Quiz>> getAllQuizzes() async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw QuizServiceException('Not authenticated. Please login again.');
      }

      debugPrint("Get All Quizzes API Url: ${ApiConfig.getAllQuizzesEndpoint}");
      final response = await http
          .get(
            Uri.parse(ApiConfig.getAllQuizzesEndpoint),
            headers: ApiConfig.getAuthHeaders(token),
          )
          .timeout(ApiConfig.timeout);

      // Check for invalid token and handle auto-logout
      await HttpInterceptorService.checkResponseAndHandleAuth(response);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('Get All Quizzes Success: ${response.body}');
        
        List<dynamic> quizzesJson;
        if (data is List) {
          quizzesJson = data;
        } else if (data is Map && data['quizzes'] != null) {
          quizzesJson = data['quizzes'];
        } else if (data is Map && data['data'] != null) {
          quizzesJson = data['data'];
        } else {
          quizzesJson = [];
        }

        return quizzesJson.map((json) => Quiz.fromJson(json)).toList();
      } else {
        debugPrint('Error Get All Quizzes Status: ${response.statusCode}');
        debugPrint('Error Get All Quizzes Body: ${response.body}');
        final error = jsonDecode(response.body);
        throw QuizServiceException(
          error['message'] ?? 'Failed to fetch quizzes. Please try again.',
        );
      }
    } catch (e) {
      if (e is QuizServiceException) {
        rethrow;
      }
      debugPrint('Get all quizzes error: $e');
      throw QuizServiceException(
          'Network error. Please check your connection.');
    }
  }

  // Add Questions to Existing Quiz
  static Future<Quiz> addQuestionsToQuiz({
    required String quizId,
    required List<Question> questions,
  }) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw QuizServiceException('Not authenticated. Please login again.');
      }

      final body = {
        'questions': questions.map((q) => q.toJson()).toList(),
      };

      debugPrint("Add Questions to Quiz API Url: ${ApiConfig.addQuestionsToQuizEndpoint(quizId)}");
      debugPrint("Add Questions Body: ${jsonEncode(body)}");
      
      final response = await http
          .post(
            Uri.parse(ApiConfig.addQuestionsToQuizEndpoint(quizId)),
            headers: ApiConfig.getAuthHeaders(token),
            body: jsonEncode(body),
          )
          .timeout(ApiConfig.timeout);

      // Check for invalid token and handle auto-logout
      await HttpInterceptorService.checkResponseAndHandleAuth(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        debugPrint('Add Questions to Quiz Success: ${response.body}');
        return Quiz.fromJson(data['quiz'] ?? data);
      } else {
        debugPrint('Error Add Questions Status: ${response.statusCode}');
        debugPrint('Error Add Questions Body: ${response.body}');
        final error = jsonDecode(response.body);
        throw QuizServiceException(
          error['message'] ?? 'Failed to add questions. Please try again.',
        );
      }
    } catch (e) {
      if (e is QuizServiceException) {
        rethrow;
      }
      debugPrint('Add questions error: $e');
      throw QuizServiceException(
          'Network error. Please check your connection.');
    }
  }

  // Update Quiz Metadata
  static Future<Quiz> updateQuiz({
    required String quizId,
    String? title,
  }) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw QuizServiceException('Not authenticated. Please login again.');
      }

      final body = <String, dynamic>{};
      if (title != null) body['title'] = title;

      debugPrint("Update Quiz API Url: ${ApiConfig.updateQuizEndpoint(quizId)}");
      debugPrint("Update Quiz Body: ${jsonEncode(body)}");
      
      final response = await http
          .put(
            Uri.parse(ApiConfig.updateQuizEndpoint(quizId)),
            headers: ApiConfig.getAuthHeaders(token),
            body: jsonEncode(body),
          )
          .timeout(ApiConfig.timeout);

      // Check for invalid token and handle auto-logout
      await HttpInterceptorService.checkResponseAndHandleAuth(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        debugPrint('Update Quiz Success: ${response.body}');
        return Quiz.fromJson(data['quiz'] ?? data);
      } else {
        debugPrint('Error Update Quiz Status: ${response.statusCode}');
        debugPrint('Error Update Quiz Body: ${response.body}');
        final error = jsonDecode(response.body);
        throw QuizServiceException(
          error['message'] ?? 'Failed to update quiz. Please try again.',
        );
      }
    } catch (e) {
      if (e is QuizServiceException) {
        rethrow;
      }
      debugPrint('Update quiz error: $e');
      throw QuizServiceException(
          'Network error. Please check your connection.');
    }
  }

  // Delete Quiz
  static Future<void> deleteQuiz(String quizId) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw QuizServiceException('Not authenticated. Please login again.');
      }

      debugPrint("Delete Quiz API Url: ${ApiConfig.deleteQuizEndpoint(quizId)}");
      final response = await http
          .delete(
            Uri.parse(ApiConfig.deleteQuizEndpoint(quizId)),
            headers: ApiConfig.getAuthHeaders(token),
          )
          .timeout(ApiConfig.timeout);

      // Check for invalid token and handle auto-logout
      await HttpInterceptorService.checkResponseAndHandleAuth(response);

      if (response.statusCode == 200 || response.statusCode == 204) {
        debugPrint('Delete Quiz Success: ${response.body}');
        return;
      } else {
        debugPrint('Error Delete Quiz Status: ${response.statusCode}');
        debugPrint('Error Delete Quiz Body: ${response.body}');
        final error = jsonDecode(response.body);
        throw QuizServiceException(
          error['message'] ?? 'Failed to delete quiz. Please try again.',
        );
      }
    } catch (e) {
      if (e is QuizServiceException) {
        rethrow;
      }
      debugPrint('Delete quiz error: $e');
      throw QuizServiceException(
          'Network error. Please check your connection.');
    }
  }

  // ========== STUDENT QUIZ METHODS ==========

  // Get Quiz for Module (Student) - Returns questions without correct answers
  static Future<Quiz> getModuleQuiz(String moduleId) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw QuizServiceException('Not authenticated. Please login again.');
      }

      debugPrint("Get Module Quiz API Url: ${ApiConfig.getModuleQuizEndpoint(moduleId)}");
      final response = await http
          .get(
            Uri.parse(ApiConfig.getModuleQuizEndpoint(moduleId)),
            headers: ApiConfig.getAuthHeaders(token),
          )
          .timeout(ApiConfig.timeout);

      // Check for invalid token and handle auto-logout
      await HttpInterceptorService.checkResponseAndHandleAuth(response);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('Get Module Quiz Success: ${response.body}');
        return Quiz.fromJson(data['quiz'] ?? data);
      } else {
        debugPrint('Error Get Module Quiz Status: ${response.statusCode}');
        debugPrint('Error Get Module Quiz Body: ${response.body}');
        final error = jsonDecode(response.body);
        throw QuizServiceException(
          error['message'] ?? 'Failed to fetch quiz. Please try again.',
        );
      }
    } catch (e) {
      if (e is QuizServiceException) {
        rethrow;
      }
      debugPrint('Get module quiz error: $e');
      throw QuizServiceException(
          'Network error. Please check your connection.');
    }
  }

  // Submit Quiz Answers (Student)
  static Future<void> submitQuiz({
    required String quizId,
    required List<Map<String, dynamic>> answers, // [{questionId: "...", selectedOption: 0}]
  }) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw QuizServiceException('Not authenticated. Please login again.');
      }

      final body = {
        'answers': answers,
      };

      debugPrint("Submit Quiz API Url: ${ApiConfig.submitQuizEndpoint(quizId)}");
      debugPrint("Submit Quiz Body: ${jsonEncode(body)}");
      
      final response = await http
          .post(
            Uri.parse(ApiConfig.submitQuizEndpoint(quizId)),
            headers: ApiConfig.getAuthHeaders(token),
            body: jsonEncode(body),
          )
          .timeout(ApiConfig.timeout);

      // Check for invalid token and handle auto-logout
      await HttpInterceptorService.checkResponseAndHandleAuth(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('Submit Quiz Success: ${response.body}');
        return;
      } else {
        debugPrint('Error Submit Quiz Status: ${response.statusCode}');
        debugPrint('Error Submit Quiz Body: ${response.body}');
        final error = jsonDecode(response.body);
        throw QuizServiceException(
          error['message'] ?? 'Failed to submit quiz. Please try again.',
        );
      }
    } catch (e) {
      if (e is QuizServiceException) {
        rethrow;
      }
      debugPrint('Submit quiz error: $e');
      throw QuizServiceException(
          'Network error. Please check your connection.');
    }
  }

  // Get Quiz Result (Student)
  static Future<Map<String, dynamic>> getQuizResult(String quizId) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw QuizServiceException('Not authenticated. Please login again.');
      }

      debugPrint("Get Quiz Result API Url: ${ApiConfig.getQuizResultEndpoint(quizId)}");
      final response = await http
          .get(
            Uri.parse(ApiConfig.getQuizResultEndpoint(quizId)),
            headers: ApiConfig.getAuthHeaders(token),
          )
          .timeout(ApiConfig.timeout);

      // Check for invalid token and handle auto-logout
      await HttpInterceptorService.checkResponseAndHandleAuth(response);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('Get Quiz Result Success: ${response.body}');
        return Map<String, dynamic>.from(data);
      } else {
        debugPrint('Error Get Quiz Result Status: ${response.statusCode}');
        debugPrint('Error Get Quiz Result Body: ${response.body}');
        final error = jsonDecode(response.body);
        throw QuizServiceException(
          error['message'] ?? 'Failed to fetch quiz result. Please try again.',
        );
      }
    } catch (e) {
      if (e is QuizServiceException) {
        rethrow;
      }
      debugPrint('Get quiz result error: $e');
      throw QuizServiceException(
          'Network error. Please check your connection.');
    }
  }
}

class QuizServiceException implements Exception {
  final String message;

  QuizServiceException(this.message);

  @override
  String toString() => message;
}

