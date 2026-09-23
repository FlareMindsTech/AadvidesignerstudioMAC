import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../models/notification.dart';
import 'storage_service.dart';
import 'http_interceptor_service.dart';

class NotificationService {
  // Get My Notifications (Student)
  static Future<List<AppNotification>> getNotifications() async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw NotificationServiceException(
            'Not authenticated. Please login again.');
      }

      debugPrint(
          "Get Notifications API Url: ${ApiConfig.getNotificationsEndpoint}");
      final response = await http
          .get(
            Uri.parse(ApiConfig.getNotificationsEndpoint),
            headers: ApiConfig.getAuthHeaders(token),
          )
          .timeout(ApiConfig.timeout);

      // Check for invalid token and handle auto-logout
      await HttpInterceptorService.checkResponseAndHandleAuth(response);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('Get Notifications Success: ${response.body}');

        List<dynamic> notificationsJson;
        if (data is List) {
          notificationsJson = data;
        } else if (data is Map && data['notifications'] != null) {
          notificationsJson = data['notifications'];
        } else if (data is Map && data['data'] != null) {
          notificationsJson = data['data'];
        } else {
          notificationsJson = [];
        }

        return notificationsJson
            .map((json) => AppNotification.fromJson(json))
            .toList();
      } else {
        debugPrint('Error Get Notifications Status: ${response.statusCode}');
        debugPrint('Error Get Notifications Body: ${response.body}');
        final error = jsonDecode(response.body);
        throw NotificationServiceException(
          error['message'] ??
              'Failed to fetch notifications. Please try again.',
        );
      }
    } catch (e) {
      if (e is NotificationServiceException) {
        rethrow;
      }
      debugPrint('Get notifications error: $e');
      throw NotificationServiceException(
          'Network error. Please check your connection.');
    }
  }

  // Mark Notification as Read (Student)
  static Future<void> markNotificationAsRead(String notificationId) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw NotificationServiceException(
            'Not authenticated. Please login again.');
      }

      debugPrint(
          "Mark Notification Read API Url: ${ApiConfig.markNotificationReadEndpoint(notificationId)}");
      final response = await http
          .post(
            Uri.parse(
                ApiConfig.markNotificationReadEndpoint(notificationId)),
            headers: ApiConfig.getAuthHeaders(token),
          )
          .timeout(ApiConfig.timeout);

      // Check for invalid token and handle auto-logout
      await HttpInterceptorService.checkResponseAndHandleAuth(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('Mark Notification Read Success: ${response.body}');
        return;
      } else {
        debugPrint(
            'Error Mark Notification Read Status: ${response.statusCode}');
        debugPrint('Error Mark Notification Read Body: ${response.body}');
        final error = jsonDecode(response.body);
        throw NotificationServiceException(
          error['message'] ??
              'Failed to mark notification as read. Please try again.',
        );
      }
    } catch (e) {
      if (e is NotificationServiceException) {
        rethrow;
      }
      debugPrint('Mark notification as read error: $e');
      throw NotificationServiceException(
          'Network error. Please check your connection.');
    }
  }
}

class NotificationServiceException implements Exception {
  final String message;

  NotificationServiceException(this.message);

  @override
  String toString() => message;
}

