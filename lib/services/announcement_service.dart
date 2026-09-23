import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../models/announcement.dart';
import 'storage_service.dart';
import 'http_interceptor_service.dart';

class AnnouncementService {
  // Create Announcement
  static Future<Announcement> createAnnouncement({
    required String title,
    required String message,
  }) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw AnnouncementServiceException(
            'Not authenticated. Please login again.');
      }

      final body = {
        'title': title,
        'message': message,
      };

      debugPrint(
          "Create Announcement API Url: ${ApiConfig.createAnnouncementEndpoint}");
      debugPrint("Create Announcement Body: ${jsonEncode(body)}");

      final response = await http
          .post(
            Uri.parse(ApiConfig.createAnnouncementEndpoint),
            headers: ApiConfig.getAuthHeaders(token),
            body: jsonEncode(body),
          )
          .timeout(ApiConfig.timeout);

      // Check for invalid token and handle auto-logout
      await HttpInterceptorService.checkResponseAndHandleAuth(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        debugPrint('Create Announcement Success: ${response.body}');
        return Announcement.fromJson(data['announcement'] ?? data);
      } else {
        debugPrint('Error Create Announcement Status: ${response.statusCode}');
        debugPrint('Error Create Announcement Body: ${response.body}');
        final error = jsonDecode(response.body);
        throw AnnouncementServiceException(
          error['message'] ??
              'Failed to create announcement. Please try again.',
        );
      }
    } catch (e) {
      if (e is AnnouncementServiceException) {
        rethrow;
      }
      debugPrint('Create announcement error: $e');
      throw AnnouncementServiceException(
          'Network error. Please check your connection.');
    }
  }

  // List All Announcements
  static Future<List<Announcement>> listAnnouncements() async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw AnnouncementServiceException(
            'Not authenticated. Please login again.');
      }

      debugPrint(
          "List Announcements API Url: ${ApiConfig.listAnnouncementsEndpoint}");
      final response = await http
          .get(
            Uri.parse(ApiConfig.listAnnouncementsEndpoint),
            headers: ApiConfig.getAuthHeaders(token),
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('List Announcements Success: ${response.body}');

        List<dynamic> announcementsJson;
        if (data is List) {
          announcementsJson = data;
        } else if (data is Map && data['announcements'] != null) {
          announcementsJson = data['announcements'];
        } else if (data is Map && data['data'] != null) {
          announcementsJson = data['data'];
        } else {
          announcementsJson = [];
        }

        return announcementsJson
            .map((json) => Announcement.fromJson(json))
            .toList();
      } else {
        debugPrint('Error List Announcements Status: ${response.statusCode}');
        debugPrint('Error List Announcements Body: ${response.body}');
        final error = jsonDecode(response.body);
        throw AnnouncementServiceException(
          error['message'] ??
              'Failed to fetch announcements. Please try again.',
        );
      }
    } catch (e) {
      if (e is AnnouncementServiceException) {
        rethrow;
      }
      debugPrint('List announcements error: $e');
      throw AnnouncementServiceException(
          'Network error. Please check your connection.');
    }
  }

  // Delete Announcement
  static Future<void> deleteAnnouncement(String announcementId) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw AnnouncementServiceException(
            'Not authenticated. Please login again.');
      }

      debugPrint(
          "Delete Announcement API Url: ${ApiConfig.deleteAnnouncementEndpoint(announcementId)}");
      final response = await http
          .delete(
            Uri.parse(ApiConfig.deleteAnnouncementEndpoint(announcementId)),
            headers: ApiConfig.getAuthHeaders(token),
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 200 || response.statusCode == 204) {
        debugPrint('Delete Announcement Success: ${response.body}');
        return;
      } else {
        debugPrint('Error Delete Announcement Status: ${response.statusCode}');
        debugPrint('Error Delete Announcement Body: ${response.body}');
        final error = jsonDecode(response.body);
        throw AnnouncementServiceException(
          error['message'] ??
              'Failed to delete announcement. Please try again.',
        );
      }
    } catch (e) {
      if (e is AnnouncementServiceException) {
        rethrow;
      }
      debugPrint('Delete announcement error: $e');
      throw AnnouncementServiceException(
          'Network error. Please check your connection.');
    }
  }
}

class AnnouncementServiceException implements Exception {
  final String message;

  AnnouncementServiceException(this.message);

  @override
  String toString() => message;
}

