import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import '../config/api_config.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import 'storage_service.dart';
import 'http_interceptor_service.dart';

class ChatServiceException implements Exception {
  final String message;
  ChatServiceException(this.message);

  @override
  String toString() => message;
}

class ChatService {
  // Get all conversations
  static Future<List<Conversation>> getAllConversations() async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw ChatServiceException('Not authenticated. Please login again.');
      }

      debugPrint("API Url: ${ApiConfig.getAllConversationsEndpoint}");
      final response = await http
          .get(
            Uri.parse(ApiConfig.getAllConversationsEndpoint),
            headers: ApiConfig.getAuthHeaders(token),
          )
          .timeout(ApiConfig.timeout);

      debugPrint('Get conversations status code: ${response.statusCode}');
      debugPrint('Get conversations response body: ${response.body}');

      // Check for invalid token and handle auto-logout
      await HttpInterceptorService.checkResponseAndHandleAuth(response);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> conversationsJson = data['data'];
          return conversationsJson
              .map((json) => Conversation.fromJson(json as Map<String, dynamic>))
              .toList();
        } else {
          throw ChatServiceException(
            data['message'] ?? 'Failed to fetch conversations.',
          );
        }
      } else {
        try {
          final error = jsonDecode(response.body);
          throw ChatServiceException(
            error['message'] ??
                'Failed to fetch conversations. Status: ${response.statusCode}',
          );
        } catch (e) {
          throw ChatServiceException(
            'Failed to fetch conversations. Status: ${response.statusCode}. Server returned non-JSON response.',
          );
        }
      }
    } catch (e) {
      if (e is ChatServiceException) {
        rethrow;
      }
      debugPrint('Get conversations error: $e');
      throw ChatServiceException(
          'Network error. Please check your connection.');
    }
  }

  // Create single chat (one-on-one)
  static Future<Conversation> createSingleChat({
    required String receiverId,
  }) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw ChatServiceException('Not authenticated. Please login again.');
      }

      debugPrint("API Url: ${ApiConfig.createSingleChatEndpoint}");
      final response = await http
          .post(
            Uri.parse(ApiConfig.createSingleChatEndpoint),
            headers: ApiConfig.getAuthHeaders(token),
            body: jsonEncode({
              'receiver_id': receiverId,
            }),
          )
          .timeout(ApiConfig.timeout);

      debugPrint('Create single chat status code: ${response.statusCode}');
      debugPrint('Create single chat response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true && data['data'] != null) {
          return Conversation.fromJson(data['data'] as Map<String, dynamic>);
        } else {
          throw ChatServiceException(
            data['message'] ?? 'Failed to create chat.',
          );
        }
      } else {
        try {
          final error = jsonDecode(response.body);
          throw ChatServiceException(
            error['message'] ??
                'Failed to create chat. Status: ${response.statusCode}',
          );
        } catch (e) {
          throw ChatServiceException(
            'Failed to create chat. Status: ${response.statusCode}. Server returned non-JSON response.',
          );
        }
      }
    } catch (e) {
      if (e is ChatServiceException) {
        rethrow;
      }
      debugPrint('Create single chat error: $e');
      throw ChatServiceException(
          'Network error. Please check your connection.');
    }
  }

  // Create group chat
  static Future<Conversation> createGroupChat({
    required String title,
    required String courseId,
    required List<String> participants,
  }) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw ChatServiceException('Not authenticated. Please login again.');
      }

      debugPrint("API Url: ${ApiConfig.createGroupChatEndpoint}");
      final response = await http
          .post(
            Uri.parse(ApiConfig.createGroupChatEndpoint),
            headers: ApiConfig.getAuthHeaders(token),
            body: jsonEncode({
              'title': title,
              'course_id': courseId,
              'participants': participants,
            }),
          )
          .timeout(ApiConfig.timeout);

      debugPrint('Create group chat status code: ${response.statusCode}');
      debugPrint('Create group chat response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true && data['data'] != null) {
          return Conversation.fromJson(data['data'] as Map<String, dynamic>);
        } else {
          throw ChatServiceException(
            data['message'] ?? 'Failed to create group chat.',
          );
        }
      } else {
        try {
          final error = jsonDecode(response.body);
          throw ChatServiceException(
            error['message'] ??
                'Failed to create group chat. Status: ${response.statusCode}',
          );
        } catch (e) {
          throw ChatServiceException(
            'Failed to create group chat. Status: ${response.statusCode}. Server returned non-JSON response.',
          );
        }
      }
    } catch (e) {
      if (e is ChatServiceException) {
        rethrow;
      }
      debugPrint('Create group chat error: $e');
      throw ChatServiceException(
          'Network error. Please check your connection.');
    }
  }

  // Send a message
  static Future<Message> sendMessage({
    required String conversationId,
    required String messageType,
    required String content,
  }) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw ChatServiceException('Not authenticated. Please login again.');
      }

      debugPrint("API Url: ${ApiConfig.sendMessageEndpoint}");
      final response = await http
          .post(
            Uri.parse(ApiConfig.sendMessageEndpoint),
            headers: ApiConfig.getAuthHeaders(token),
            body: jsonEncode({
              'conversation_id': conversationId,
              'message_type': messageType,
              'content': content,
            }),
          )
          .timeout(ApiConfig.timeout);

      debugPrint('Send message status code: ${response.statusCode}');
      debugPrint('Send message response body: ${response.body}');

      // Check for invalid token and handle auto-logout
      await HttpInterceptorService.checkResponseAndHandleAuth(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true && data['data'] != null) {
          return Message.fromJson(data['data'] as Map<String, dynamic>);
        } else {
          throw ChatServiceException(
            data['message'] ?? 'Failed to send message.',
          );
        }
      } else {
        try {
          final error = jsonDecode(response.body);
          throw ChatServiceException(
            error['message'] ??
                'Failed to send message. Status: ${response.statusCode}',
          );
        } catch (e) {
          throw ChatServiceException(
            'Failed to send message. Status: ${response.statusCode}. Server returned non-JSON response.',
          );
        }
      }
    } catch (e) {
      if (e is ChatServiceException) {
        rethrow;
      }
      debugPrint('Send message error: $e');
      throw ChatServiceException(
          'Network error. Please check your connection.');
    }
  }

  // Get messages for a conversation
  static Future<List<Message>> getMessages({
    required String conversationId,
  }) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw ChatServiceException('Not authenticated. Please login again.');
      }

      final url = Uri.parse(ApiConfig.getMessagesEndpoint).replace(
        queryParameters: {'conversation_id': conversationId},
      );

      debugPrint("API Url: $url");
      final response = await http
          .get(
            url,
            headers: ApiConfig.getAuthHeaders(token),
          )
          .timeout(ApiConfig.timeout);

      debugPrint('Get messages status code: ${response.statusCode}');
      debugPrint('Get messages response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> messagesJson = data['data'];
          return messagesJson
              .map((json) => Message.fromJson(json as Map<String, dynamic>))
              .toList();
        } else {
          throw ChatServiceException(
            data['message'] ?? 'Failed to fetch messages.',
          );
        }
      } else {
        try {
          final error = jsonDecode(response.body);
          throw ChatServiceException(
            error['message'] ??
                'Failed to fetch messages. Status: ${response.statusCode}',
          );
        } catch (e) {
          throw ChatServiceException(
            'Failed to fetch messages. Status: ${response.statusCode}. Server returned non-JSON response.',
          );
        }
      }
    } catch (e) {
      if (e is ChatServiceException) {
        rethrow;
      }
      debugPrint('Get messages error: $e');
      throw ChatServiceException(
          'Network error. Please check your connection.');
    }
  }

  // Mark message as read
  static Future<void> markMessageAsRead({
    required String conversationId,
    required String messageId,
  }) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw ChatServiceException('Not authenticated. Please login again.');
      }

      debugPrint("API Url: ${ApiConfig.markMessageReadEndpoint}");
      final response = await http
          .post(
            Uri.parse(ApiConfig.markMessageReadEndpoint),
            headers: ApiConfig.getAuthHeaders(token),
            body: jsonEncode({
              'conversation_id': conversationId,
              'message_id': messageId,
            }),
          )
          .timeout(ApiConfig.timeout);

      debugPrint('Mark message read status code: ${response.statusCode}');
      debugPrint('Mark message read response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        
        if (data['success'] != true) {
          throw ChatServiceException(
            data['message'] ?? 'Failed to mark message as read.',
          );
        }
      } else {
        try {
          final error = jsonDecode(response.body);
          throw ChatServiceException(
            error['message'] ??
                'Failed to mark message as read. Status: ${response.statusCode}',
          );
        } catch (e) {
          throw ChatServiceException(
            'Failed to mark message as read. Status: ${response.statusCode}. Server returned non-JSON response.',
          );
        }
      }
    } catch (e) {
      if (e is ChatServiceException) {
        rethrow;
      }
      debugPrint('Mark message read error: $e');
      throw ChatServiceException(
          'Network error. Please check your connection.');
    }
  }

  // Manage group user (add/remove)
  static Future<void> manageGroupUser({
    required String conversationId,
    required String userId,
    required String action, // "add" or "remove"
  }) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw ChatServiceException('Not authenticated. Please login again.');
      }

      final url = ApiConfig.manageGroupUserEndpoint(conversationId);
      debugPrint("API Url: $url");
      final response = await http
          .post(
            Uri.parse(url),
            headers: ApiConfig.getAuthHeaders(token),
            body: jsonEncode({
              'user_id': userId,
              'action': action,
            }),
          )
          .timeout(ApiConfig.timeout);

      debugPrint('Manage group user status code: ${response.statusCode}');
      debugPrint('Manage group user response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        
        if (data['success'] != true) {
          throw ChatServiceException(
            data['message'] ?? 'Failed to manage group user.',
          );
        }
      } else {
        try {
          final error = jsonDecode(response.body);
          throw ChatServiceException(
            error['message'] ??
                'Failed to manage group user. Status: ${response.statusCode}',
          );
        } catch (e) {
          throw ChatServiceException(
            'Failed to manage group user. Status: ${response.statusCode}. Server returned non-JSON response.',
          );
        }
      }
    } catch (e) {
      if (e is ChatServiceException) {
        rethrow;
      }
      debugPrint('Manage group user error: $e');
      throw ChatServiceException(
          'Network error. Please check your connection.');
    }
  }

  // Delete conversation
  static Future<void> deleteConversation(String conversationId) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw ChatServiceException('Not authenticated. Please login again.');
      }

      final url = ApiConfig.deleteConversationEndpoint(conversationId);
      debugPrint("Delete Chat API Url: $url");
      final response = await http
          .delete(
            Uri.parse(url),
            headers: ApiConfig.getAuthHeaders(token),
          )
          .timeout(ApiConfig.timeout);

      debugPrint('Delete chat status code: ${response.statusCode}');
      debugPrint('Delete chat response body: ${response.body}');

      if (response.statusCode != 200 && response.statusCode != 204) {
        final data = jsonDecode(response.body);
        throw ChatServiceException(
          data['message'] ?? 'Failed to delete chat.',
        );
      }
    } catch (e) {
      if (e is ChatServiceException) {
        rethrow;
      }
      debugPrint('Delete chat error: $e');
      throw ChatServiceException(
          'Network error. Please check your connection.');
    }
  }

  // Update group details (title, photo)
  static Future<Conversation> updateGroupChat({
    required String conversationId,
    String? title,
    File? photo,
  }) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw ChatServiceException('Not authenticated. Please login again.');
      }

      final url = ApiConfig.updateGroupDetailsEndpoint(conversationId);
      debugPrint("API Url: $url");

      var request = http.MultipartRequest('PUT', Uri.parse(url));
      request.headers.addAll(ApiConfig.getAuthHeadersMultipart(token));

      if (title != null) request.fields['title'] = title;

      if (photo != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'photo',
            photo.path,
            filename: path.basename(photo.path),
          ),
        );
      } else {
        // If photo is null, it means we want to remove it
        request.fields['removePhoto'] = 'true';
      }

      final streamedResponse = await request.send().timeout(ApiConfig.timeout);
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('Update group chat status code: ${response.statusCode}');
      debugPrint('Update group chat response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return Conversation.fromJson(data['data'] as Map<String, dynamic>);
        } else {
          throw ChatServiceException(
            data['message'] ?? 'Failed to update group details.',
          );
        }
      } else {
        final error = jsonDecode(response.body);
        throw ChatServiceException(
          error['message'] ?? 'Failed to update group details.',
        );
      }
    } catch (e) {
      if (e is ChatServiceException) rethrow;
      debugPrint('Update group chat error: $e');
      throw ChatServiceException('Network error or server error.');
    }
  }
}

