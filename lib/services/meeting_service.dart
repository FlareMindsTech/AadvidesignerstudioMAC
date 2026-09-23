import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../models/meeting.dart';
import 'storage_service.dart';
import 'http_interceptor_service.dart';

class MeetingService {
  // Create Meeting
  static Future<Meeting> createMeeting({
    required String className,
    required String date,
    required String startTime,
    required String endTime,
    String? meetingUrl,
    String? courseId,
  }) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw MeetingServiceException('Not authenticated. Please login again.');
      }

      // Build request body
      final requestBody = <String, dynamic>{
        'className': className,
        'date': date,
        'startTime': startTime,
        'endTime': endTime,
      };
      
      // Add optional fields
      if (meetingUrl != null && meetingUrl.isNotEmpty) {
        requestBody['meetingUrl'] = meetingUrl;
      }
      
      if (courseId != null && courseId.isNotEmpty) {
        requestBody['courseId'] = courseId;
      } else {
        requestBody['courseId'] = null;
      }

      debugPrint("Api Url: ${ApiConfig.meetingBaseUrl}");
      debugPrint("Request body: ${jsonEncode(requestBody)}");
      
      final response = await http
          .post(
            Uri.parse(ApiConfig.meetingBaseUrl),
            headers: ApiConfig.getAuthHeaders(token),
            body: jsonEncode(requestBody),
          )
          .timeout(ApiConfig.timeout);

      debugPrint('Create meeting status code: ${response.statusCode}');
      debugPrint('Create meeting response body: ${response.body}');

      // Check for invalid token and handle auto-logout
      await HttpInterceptorService.checkResponseAndHandleAuth(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final meetingData = data['meeting'] ?? data;
        
        // Extract course title if courseId exists
        String courseTitle = '';
        if (meetingData['courseId'] != null) {
          if (meetingData['courseId'] is Map) {
            courseTitle = meetingData['courseId']['title'] ?? '';
          }
        }
        
        // Build description with course info
        String description = courseTitle.isNotEmpty 
            ? 'Course: $courseTitle' 
            : meetingData['className'] ?? 'Meeting';
        
        // Parse date and time
        DateTime startDateTime = _parseDateWithTime(meetingData['date'], meetingData['startTime']);
        DateTime endDateTime = _parseDateWithTime(meetingData['date'], meetingData['endTime']);
        
        // If duration is provided, calculate endTime from startTime + duration
        if (meetingData['duration'] != null && meetingData['endTime'] == null) {
          int durationMinutes = meetingData['duration'] is int 
              ? meetingData['duration'] 
              : int.tryParse(meetingData['duration'].toString()) ?? 60;
          endDateTime = startDateTime.add(Duration(minutes: durationMinutes));
        }
        
        // Map API response to Meeting model format
        return Meeting(
          id: meetingData['_id'] ?? meetingData['id'] ?? '',
          title: meetingData['className'] ?? meetingData['title'] ?? 'Untitled Meeting',
          description: description,
          startTime: startDateTime,
          endTime: endDateTime,
          status: _mapStatusString(meetingData['status']),
          organizerId: meetingData['created_by'] ?? meetingData['organizerId'] ?? '',
          participantIds: (meetingData['students'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ?? [],
          meetingUrl: meetingData['meetingUrl'] as String?,
          meetingId: meetingData['meetingId'] as String?,
          password: meetingData['password'] as String?,
        );
      } else {
        // Try to parse error response
        try {
          final error = jsonDecode(response.body);
          throw MeetingServiceException(
            error['message'] ?? 'Failed to create meeting. Status: ${response.statusCode}',
          );
        } catch (e) {
          // If response is not JSON (like HTML error page)
          throw MeetingServiceException(
            'Failed to create meeting. Status: ${response.statusCode}. Server returned non-JSON response.',
          );
        }
      }
    } catch (e) {
      if (e is MeetingServiceException) {
        rethrow;
      }
      debugPrint('Create meeting error: $e');
      debugPrint('Error type: ${e.runtimeType}');
      
      // Provide more specific error messages based on error type
      String errorMessage = 'Network error. Please check your connection.';
      if (e.toString().contains('HandshakeException') || e.toString().contains('handshake')) {
        errorMessage = 'Connection failed. The server may be unreachable or having SSL issues. Please try again later.';
      } else if (e.toString().contains('TimeoutException') || e.toString().contains('timeout')) {
        errorMessage = 'Request timed out. Please check your internet connection and try again.';
      } else if (e.toString().contains('SocketException') || e.toString().contains('socket')) {
        errorMessage = 'Unable to connect to the server. Please check your internet connection.';
      } else if (e.toString().contains('Connection')) {
        errorMessage = 'Connection error. Please try again.';
      }
      
      throw MeetingServiceException(errorMessage);
    }
  }

  // Get All Meetings (for admin/owner)
  static Future<List<Meeting>> getMeetings() async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw MeetingServiceException('Not authenticated. Please login again.');
      }
      
      // Check user role
      final role = await StorageService.getRole();
      final isStudent = role?.toLowerCase() == 'student' || role?.toLowerCase() == 'user';
      
      // Use different endpoint based on role
      final endpoint = isStudent 
          ? ApiConfig.getMyMeetingsEndpoint // Use my-meetings endpoint for students
          : ApiConfig.getAllMeetingsEndpoint; // Use all meetings endpoint for admin/owner
      
      debugPrint("Api Url: $endpoint");
      debugPrint("User Role: $role");
      
      final response = await http
          .get(
            Uri.parse(endpoint),
            headers: ApiConfig.getAuthHeaders(token),
          )
          .timeout(ApiConfig.timeout);

      debugPrint('Get meetings status code: ${response.statusCode}');
      debugPrint('Get meetings response body: ${response.body}');

      // Check for invalid token and handle auto-logout
      await HttpInterceptorService.checkResponseAndHandleAuth(response);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Handle different response formats
        List<dynamic> meetingsJson;
        if (data is List) {
          meetingsJson = data;
        } else if (data is Map && data['meetings'] != null) {
          // Handle my-meetings response format: { count, meetings: [...] }
          meetingsJson = data['meetings'];
        } else if (data is Map && data['data'] != null) {
          meetingsJson = data['data'];
        } else if (data is Map && data['meeting'] != null) {
          meetingsJson = [data['meeting']];
        } else {
          meetingsJson = [];
        }

        // Map API response to Meeting model format
        return meetingsJson.map((meetingData) {
          // Extract course title if courseId exists
          String courseTitle = '';
          if (meetingData['courseId'] != null) {
            if (meetingData['courseId'] is Map) {
              courseTitle = meetingData['courseId']['title'] ?? '';
            } else if (meetingData['courseId'] is String) {
              courseTitle = meetingData['courseId'];
            }
          }
          
          // Build description with course info
          String description = courseTitle.isNotEmpty 
              ? 'Course: $courseTitle' 
              : meetingData['className'] ?? 'Meeting';
          
          // Parse date and time
          DateTime startTime = _parseDateWithTime(meetingData['date'], meetingData['startTime']);
          DateTime endTime = _parseDateWithTime(meetingData['date'], meetingData['endTime']);
          
          // If duration is provided, calculate endTime from startTime + duration
          if (meetingData['duration'] != null && meetingData['endTime'] == null) {
            int durationMinutes = meetingData['duration'] is int 
                ? meetingData['duration'] 
                : int.tryParse(meetingData['duration'].toString()) ?? 60;
            endTime = startTime.add(Duration(minutes: durationMinutes));
          }

          return Meeting(
            id: meetingData['_id'] ?? meetingData['id'] ?? '',
            title: meetingData['className'] ?? meetingData['title'] ?? 'Untitled Meeting',
            description: description,
            startTime: startTime,
            endTime: endTime,
            status: _mapStatusString(meetingData['status']),
            organizerId: meetingData['created_by'] ?? meetingData['organizerId'] ?? '',
            participantIds: (meetingData['students'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ?? [],
            meetingUrl: meetingData['meetingUrl'] as String?,
            meetingId: meetingData['meetingId'] as String?,
            password: meetingData['password'] as String?,
          );
        }).toList();
      } else {
        try {
          final error = jsonDecode(response.body);
          throw MeetingServiceException(
            error['message'] ?? 'Failed to fetch meetings. Please try again.',
          );
        } catch (e) {
          throw MeetingServiceException(
            'Failed to fetch meetings. Status: ${response.statusCode}',
          );
        }
      }
    } catch (e) {
      if (e is MeetingServiceException) {
        rethrow;
      }
      debugPrint('Get meetings error: $e');
      debugPrint('Error type: ${e.runtimeType}');
      
      // Provide more specific error messages based on error type
      String errorMessage = 'Network error. Please check your connection.';
      if (e.toString().contains('HandshakeException') || e.toString().contains('handshake')) {
        errorMessage = 'Connection failed. The server may be unreachable or having SSL issues. Please try again later.';
      } else if (e.toString().contains('TimeoutException') || e.toString().contains('timeout')) {
        errorMessage = 'Request timed out. Please check your internet connection and try again.';
      } else if (e.toString().contains('SocketException') || e.toString().contains('socket')) {
        errorMessage = 'Unable to connect to the server. Please check your internet connection.';
      } else if (e.toString().contains('Connection')) {
        errorMessage = 'Connection error. Please try again.';
      }
      
      throw MeetingServiceException(errorMessage);
    }
  }

  // Delete Meeting
  static Future<bool> deleteMeeting(String meetingId) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw MeetingServiceException('Not authenticated. Please login again.');
      }

      final endpoint = '${ApiConfig.baseUrl}/meetings/$meetingId';
      
      debugPrint("Delete meeting Api Url: $endpoint");

      final response = await http
          .delete(
            Uri.parse(endpoint),
            headers: ApiConfig.getAuthHeaders(token),
          )
          .timeout(ApiConfig.timeout);

      debugPrint('Delete meeting status code: ${response.statusCode}');
      debugPrint('Delete meeting response body: ${response.body}');

      // Check for invalid token and handle auto-logout
      await HttpInterceptorService.checkResponseAndHandleAuth(response);

      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      } else {
        final error = jsonDecode(response.body);
        throw MeetingServiceException(
          error['message'] ?? 'Failed to delete meeting. Please try again.',
        );
      }
    } catch (e) {
      if (e is MeetingServiceException) {
        rethrow;
      }
      debugPrint('Delete meeting error: $e');
      debugPrint('Error type: ${e.runtimeType}');
      
      // Provide more specific error messages based on error type
      String errorMessage = 'Network error. Please check your connection.';
      if (e.toString().contains('HandshakeException') || e.toString().contains('handshake')) {
        errorMessage = 'Connection failed. The server may be unreachable or having SSL issues. Please try again later.';
      } else if (e.toString().contains('TimeoutException') || e.toString().contains('timeout')) {
        errorMessage = 'Request timed out. Please check your internet connection and try again.';
      } else if (e.toString().contains('SocketException') || e.toString().contains('socket')) {
        errorMessage = 'Unable to connect to the server. Please check your internet connection.';
      } else if (e.toString().contains('Connection')) {
        errorMessage = 'Connection error. Please try again.';
      }
      
      throw MeetingServiceException(errorMessage);
    }
  }

  // Reschedule Meeting
  static Future<Meeting> rescheduleMeeting({
    required String meetingId,
    required String date,
    required String startTime,
    required String endTime,
  }) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw MeetingServiceException('Not authenticated. Please login again.');
      }

      final endpoint = '${ApiConfig.baseUrl}/meetings/$meetingId/reschedule';
      
      debugPrint("Reschedule Api Url: $endpoint");
      debugPrint("Request body: {'date': '$date', 'startTime': '$startTime', 'endTime': '$endTime'}");

      final response = await http
          .put(
            Uri.parse(endpoint),
            headers: ApiConfig.getAuthHeaders(token),
            body: jsonEncode({
              'date': date,
              'startTime': startTime,
              'endTime': endTime,
            }),
          )
          .timeout(ApiConfig.timeout);

      debugPrint('Reschedule meeting status code: ${response.statusCode}');
      debugPrint('Reschedule meeting response body: ${response.body}');

      // Check for invalid token and handle auto-logout
      await HttpInterceptorService.checkResponseAndHandleAuth(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final meetingData = data['meeting'] ?? data;

        // Map API response to Meeting model format
        return Meeting(
          id: meetingData['_id'] ?? meetingData['id'] ?? '',
          title: meetingData['className'] ?? meetingData['title'] ?? 'Untitled Meeting',
          description: meetingData['description'] ?? meetingData['className'] ?? '',
          startTime: _parseDateWithTime(meetingData['date'], meetingData['startTime']),
          endTime: _parseDateWithTime(meetingData['date'], meetingData['endTime']),
          status: _mapStatusString(meetingData['status']),
          organizerId: meetingData['organizerId'] ?? '',
          participantIds: (meetingData['students'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ?? [],
          meetingUrl: meetingData['meetingUrl'] as String?,
          meetingId: meetingData['meetingId'] as String?,
          password: meetingData['password'] as String?,
        );
      } else {
        try {
          final error = jsonDecode(response.body);
          throw MeetingServiceException(
            error['message'] ?? 'Failed to reschedule meeting. Status: ${response.statusCode}',
          );
        } catch (e) {
          throw MeetingServiceException(
            'Failed to reschedule meeting. Status: ${response.statusCode}. Server returned non-JSON response.',
          );
        }
      }
    } catch (e) {
      if (e is MeetingServiceException) {
        rethrow;
      }
      debugPrint('Reschedule meeting error: $e');
      debugPrint('Error type: ${e.runtimeType}');

      String errorMessage = 'Network error. Please check your connection.';
      if (e.toString().contains('HandshakeException') || e.toString().contains('handshake')) {
        errorMessage = 'Connection failed. The server may be unreachable or having SSL issues. Please try again later.';
      } else if (e.toString().contains('TimeoutException') || e.toString().contains('timeout')) {
        errorMessage = 'Request timed out. Please check your internet connection and try again.';
      } else if (e.toString().contains('SocketException') || e.toString().contains('socket')) {
        errorMessage = 'Unable to connect to the server. Please check your internet connection.';
      } else if (e.toString().contains('Connection')) {
        errorMessage = 'Connection error. Please try again.';
      }

      throw MeetingServiceException(errorMessage);
    }
  }

  // Helper method to map API status string to MeetingStatus enum
  static MeetingStatus _mapStatusString(dynamic status) {
    if (status == null) return MeetingStatus.yetToStart;
    
    final String statusStr = status.toString().toLowerCase();
    switch (statusStr) {
      case 'upcoming':
      case 'yet_to_start':
      case 'yettostart':
        return MeetingStatus.yetToStart;
      case 'in_progress':
      case 'inprogress':
      case 'ongoing':
      case 'live':
        return MeetingStatus.inProgress;
      case 'completed':
      case 'finished':
        return MeetingStatus.completed;
      case 'cancelled':
      case 'canceled':
        return MeetingStatus.cancelled;
      default:
        return MeetingStatus.yetToStart;
    }
  }

  // Helper method to parse date and time from API response
  static DateTime _parseDateWithTime(String? dateStr, String? timeStr) {
    if (dateStr == null || dateStr.isEmpty) {
      return DateTime.now();
    }
    
    try {
      // Parse the date string (e.g., "2025-10-28T00:00:00.000Z")
      DateTime baseDate = DateTime.parse(dateStr);
      
      // If timeStr is provided, try to combine it with the date
      if (timeStr != null && timeStr.isNotEmpty) {
        // Convert time from "9:00 PM" format to 24-hour format
        // This is a simple implementation - you may need to adjust based on your needs
        try {
          // Try to parse as DateTime first
          if (timeStr.contains('PM') || timeStr.contains('AM')) {
            // Handle 12-hour format
            String time24 = _convertTo24Hour(timeStr);
            List<String> timeParts = time24.split(':');
            int hour = int.parse(timeParts[0]);
            int minute = int.parse(timeParts[1]);
            
            return DateTime(baseDate.year, baseDate.month, baseDate.day, hour, minute);
          } else {
            // Try to parse as ISO format
            return DateTime.parse(timeStr);
          }
        } catch (e) {
          // If parsing fails, return the base date
          return baseDate;
        }
      }
      
      return baseDate;
    } catch (e) {
      debugPrint('Error parsing date: $e');
      return DateTime.now();
    }
  }

  // Helper method to convert 12-hour format to 24-hour format
  static String _convertTo24Hour(String time12) {
    try {
      time12 = time12.replaceAll(' ', '').toUpperCase();
      bool isPM = time12.contains('PM');
      time12 = time12.replaceAll('AM', '').replaceAll('PM', '');
      
      List<String> parts = time12.split(':');
      int hour = int.parse(parts[0]);
      int minute = int.parse(parts.length > 1 ? parts[1] : '0');
      
      if (isPM && hour != 12) {
        hour += 12;
      } else if (!isPM && hour == 12) {
        hour = 0;
      }
      
      return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '12:00';
    }
  }

  // Allocate Students to Meeting
  static Future<Map<String, dynamic>> allocateStudents({
    required String meetingId,
    required List<String> studentIds,
  }) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw MeetingServiceException('Not authenticated. Please login again.');
      }

      final endpoint = '${ApiConfig.baseUrl}/meetings/$meetingId/allocate';
      
      debugPrint("Api Url: $endpoint");
      debugPrint("Request body: {'studentIds': $studentIds}");
      
      final response = await http
          .post(
            Uri.parse(endpoint),
            headers: ApiConfig.getAuthHeaders(token),
            body: jsonEncode({
              'studentIds': studentIds,
            }),
          )
          .timeout(ApiConfig.timeout);

      debugPrint('Allocate students status code: ${response.statusCode}');
      debugPrint('Allocate students response body: ${response.body}');

      // Check for invalid token and handle auto-logout
      await HttpInterceptorService.checkResponseAndHandleAuth(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'message': data['message'] ?? 'Students allocated successfully',
          'meetingId': data['meetingId'] ?? meetingId,
          'allocatedCount': data['allocatedCount'] ?? studentIds.length,
          'emailResults': data['emailResults'] ?? [],
        };
      } else {
        // Extract error message from response
        String errorMessage = 'Failed to allocate students. Please try again.';
        try {
          final error = jsonDecode(response.body);
          if (error is Map && error.containsKey('message')) {
            errorMessage = error['message'].toString();
            debugPrint('Extracted error message: $errorMessage');
          } else if (error is Map && error.containsKey('error')) {
            errorMessage = error['error'].toString();
            debugPrint('Extracted error from error field: $errorMessage');
          }
        } catch (e) {
          debugPrint('Error parsing response body: $e');
          // If JSON parsing fails, try to extract message from raw body
          if (response.body.contains('message')) {
            try {
              final match = RegExp(r'"message"\s*:\s*"([^"]+)"').firstMatch(response.body);
              if (match != null) {
                errorMessage = match.group(1)!;
                debugPrint('Extracted error message from regex: $errorMessage');
              }
            } catch (regexError) {
              debugPrint('Error extracting message with regex: $regexError');
            }
          }
        }
        debugPrint('Throwing MeetingServiceException with message: $errorMessage');
        throw MeetingServiceException(errorMessage);
      }
    } catch (e) {
      if (e is MeetingServiceException) {
        rethrow;
      }
      debugPrint('Allocate students error: $e');
      throw MeetingServiceException(
        'Network error. Please check your connection.',
      );
    }
  }

  // Join Meeting (for students)
  static Future<Map<String, dynamic>> joinMeeting(String meetingId) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw MeetingServiceException('Not authenticated. Please login again.');
      }

      final endpoint = ApiConfig.joinMeetingEndpoint(meetingId);
      
      debugPrint("Join meeting Api Url: $endpoint");
      
      final response = await http
          .post(
            Uri.parse(endpoint),
            headers: ApiConfig.getAuthHeaders(token),
          )
          .timeout(ApiConfig.timeout);

      debugPrint('Join meeting status code: ${response.statusCode}');
      debugPrint('Join meeting response body: ${response.body}');

      // Check for invalid token and handle auto-logout
      await HttpInterceptorService.checkResponseAndHandleAuth(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'message': data['message'] ?? 'Access granted',
          'meetingUrl': data['meetingUrl'] ?? '',
          'className': data['className'] ?? '',
        };
      } else {
        try {
          final error = jsonDecode(response.body);
          throw MeetingServiceException(
            error['message'] ?? 'Failed to join meeting. Please try again.',
          );
        } catch (e) {
          throw MeetingServiceException(
            'Failed to join meeting. Status: ${response.statusCode}',
          );
        }
      }
    } catch (e) {
      if (e is MeetingServiceException) {
        rethrow;
      }
      debugPrint('Join meeting error: $e');
      throw MeetingServiceException(
        'Network error. Please check your connection.',
      );
    }
  }
}

class MeetingServiceException implements Exception {
  final String message;

  MeetingServiceException(this.message);

  @override
  String toString() => message;
}

