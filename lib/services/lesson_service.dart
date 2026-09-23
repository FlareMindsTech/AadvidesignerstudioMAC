import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import '../config/api_config.dart';
import '../models/lesson.dart';
import 'storage_service.dart';
import 'http_interceptor_service.dart';

class LessonService {
  static http.Client? _activeUploadClient;

  static MediaType _getMediaType(String filePath) {
    final ext = path.extension(filePath).toLowerCase().replaceAll('.', '');
    switch (ext) {
      case 'pdf': return MediaType('application', 'pdf');
      case 'mp4': return MediaType('video', 'mp4');
      case 'mov': return MediaType('video', 'quicktime');
      case 'avi': return MediaType('video', 'x-msvideo');
      case 'png': return MediaType('image', 'png');
      case 'jpg':
      case 'jpeg': return MediaType('image', 'jpeg');
      case 'webp': return MediaType('image', 'webp');
      case 'doc': return MediaType('application', 'msword');
      case 'docx': return MediaType('application', 'vnd.openxmlformats-officedocument.wordprocessingml.document');
      default: return MediaType('application', 'octet-stream');
    }
  }

  static void cancelActiveUpload() {
    _activeUploadClient?.close();
    _activeUploadClient = null;
  }

  // Get All Lessons in a Submodule (Student Token)
  static Future<List<Lesson>> getModuleLessons(String submoduleId) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw LessonServiceException('Not authenticated. Please login again.');
      }

      debugPrint(
        "Get Module Lessons API Url: ${ApiConfig.getModuleLessonsEndpoint(submoduleId)}",
      );
      final response = await http
          .get(
            Uri.parse(ApiConfig.getModuleLessonsEndpoint(submoduleId)),
            headers: ApiConfig.getAuthHeaders(token),
          )
          .timeout(ApiConfig.timeout);

      // Check for invalid token and handle auto-logout
      await HttpInterceptorService.checkResponseAndHandleAuth(response);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('Get Module Lessons Success: ${response.body}');

        List<dynamic> lessonsJson;
        if (data is List) {
          lessonsJson = data;
        } else if (data is Map && data['lessons'] != null) {
          lessonsJson = data['lessons'];
        } else if (data is Map && data['data'] != null) {
          lessonsJson = data['data'];
        } else {
          lessonsJson = [];
        }

        return lessonsJson.map((json) => Lesson.fromJson(json)).toList();
      } else {
        debugPrint('Error Get Module Lessons Status: ${response.statusCode}');
        debugPrint('Error Get Module Lessons Body: ${response.body}');
        final error = jsonDecode(response.body);
        throw LessonServiceException(
          error['message'] ?? 'Failed to fetch lessons. Please try again.',
        );
      }
    } catch (e) {
      if (e is LessonServiceException) {
        rethrow;
      }
      debugPrint('Get module lessons error: $e');
      throw LessonServiceException(
        'Network error. Please check your connection.',
      );
    }
  }


  static Future<Map<String, dynamic>> createBunnyStreamUpload(
    String title,
  ) async {
    final token = await StorageService.getToken();
    if (token == null) throw LessonServiceException('Not authenticated.');

    final response = await http
        .post(
          Uri.parse(ApiConfig.bunnyStreamUploadEndpoint),
          headers: ApiConfig.getAuthHeaders(token),
          body: jsonEncode({'title': title}),
        )
        .timeout(ApiConfig.timeout);

    await HttpInterceptorService.checkResponseAndHandleAuth(response);
    if (response.statusCode != 200) {
      throw LessonServiceException(
        jsonDecode(response.body)['message'] ??
            'Failed to initialize Bunny Stream upload.',
      );
    }
    return Map<String, dynamic>.from(jsonDecode(response.body));
  }

  static Future<void> uploadFileToBunnyStream(
    File file,
    Map<String, dynamic> uploadData, {
    void Function(double)? onProgress,
  }) async {
    final client = http.Client();
    _activeUploadClient = client;
    final fileSize = await file.length();
    try {
      const chunkSize = 5 * 1024 * 1024;
      final createRequest = http.Request(
        'POST',
        Uri.parse(uploadData['uploadUrl'] as String),
      );
      createRequest.headers.addAll({
        'AuthorizationSignature': uploadData['authorizationSignature'] as String,
        'AuthorizationExpire': '${uploadData['authorizationExpire']}',
        'VideoId': uploadData['videoId'] as String,
        'LibraryId': uploadData['libraryId'] as String,
        'Tus-Resumable': '1.0.0',
        'Upload-Length': '$fileSize',
        'Upload-Metadata':
            'filename ${base64Encode(utf8.encode(path.basename(file.path)))}',
      });
      final createResponse = await client.send(createRequest).timeout(
        const Duration(seconds: 30),
      );
      if (createResponse.statusCode != 201) {
        throw LessonServiceException(
          'Failed to initialize TUS upload session (${createResponse.statusCode}).',
        );
      }

      final locationHeader = createResponse.headers['location'];
      if (locationHeader == null || locationHeader.isEmpty) {
        throw LessonServiceException(
          'Bunny Stream did not return an upload location.',
        );
      }
      var uploadUri = Uri.parse(locationHeader);
      if (!uploadUri.isAbsolute) {
        final uploadUrl = uploadData['uploadUrl'] as String;
        final baseUrl = uploadUrl.endsWith('/') ? uploadUrl : '$uploadUrl/';
        uploadUri = Uri.parse(baseUrl).resolve(locationHeader);
      }

      var offset = 0;
      while (offset < fileSize) {
      final end = (offset + chunkSize < fileSize)
          ? offset + chunkSize
          : fileSize;
      final length = end - offset;

        final request = http.StreamedRequest('PATCH', uploadUri);
        request.contentLength = length;
        request.headers.addAll({
          'AuthorizationSignature': uploadData['authorizationSignature'] as String,
          'AuthorizationExpire': '${uploadData['authorizationExpire']}',
          'VideoId': uploadData['videoId'] as String,
          'LibraryId': uploadData['libraryId'] as String,
          'Tus-Resumable': '1.0.0',
          'Upload-Offset': '$offset',
          'Content-Type': 'application/offset+octet-stream',
        });

        final responseFuture = client.send(request).timeout(
          const Duration(minutes: 10),
        );
        await file.openRead(offset, end).pipe(request.sink);
        final response = await responseFuture;

        if (response.statusCode != 204) {
          throw LessonServiceException(
            'Bunny Stream upload failed at byte $offset (${response.statusCode}).',
          );
        }

        offset = end;
        onProgress?.call(offset / fileSize);
      }
    } finally {
      if (identical(_activeUploadClient, client)) {
        _activeUploadClient = null;
      }
      client.close();
    }
  }


  // Removed legacy Cloudinary signature and upload functions
  // Create Lesson (Admin Token) - Uses Direct Upload for large files
  static Future<Lesson> createLesson({
    String? moduleId,
    required String submoduleId,
    required String title,
    String? description,
    required String type,
    String? duration,
    required bool isFree,
    File? contentFile,
    void Function(double)? onProgress,
  }) async {
    try {
      final token = await StorageService.getToken();
      if (token == null) {
        throw LessonServiceException('Not authenticated. Please login again.');
      }

      String? uploadedUrl;
      Map<String, dynamic>? streamData;
      var isVideo = type.toLowerCase() == 'video';

      // If file is large (> 4MB) or it's a video, use direct upload to bypass Vercel limits
      if (contentFile != null) {
        final fileSize = await contentFile.length();
        isVideo =
            isVideo ||
            ['mp4', 'mov', 'avi', 'mkv'].contains(
              path
                  .extension(contentFile.path)
                  .toLowerCase()
                  .replaceFirst('.', ''),
            );

        if (isVideo) {
          streamData = await createBunnyStreamUpload(title);
          await uploadFileToBunnyStream(
            contentFile,
            streamData,
            onProgress: onProgress,
          );
          uploadedUrl = streamData['playbackUrl'] as String?;
        } else {
          // Non-video files (PDFs, etc.) go through backend → Cloudinary
          return await _createLessonViaBackend(
            submoduleId: submoduleId,
            title: title,
            description: description,
            type: type,
            duration: duration,
            isFree: isFree,
            contentFile: contentFile,
            token: token,
          );
        }
      }

      if (uploadedUrl == null && contentFile != null) {
        // Fallback for small files: standard multipart via backend
        return await _createLessonViaBackend(
          submoduleId: submoduleId,
          title: title,
          description: description,
          type: type,
          duration: duration,
          isFree: isFree,
          contentFile: contentFile,
          token: token,
        );
      } else {
        return await _createLessonRecordOnly(
          submoduleId: submoduleId,
          title: title,
          description: description,
          type: type,
          duration: duration,
          isFree: isFree,
          contentUrl: uploadedUrl,
          videoProvider: isVideo ? 'bunny-stream' : null,
          bunnyVideoId: streamData?['videoId']?.toString(),
          bunnyLibraryId: streamData?['libraryId']?.toString(),
          token: token,
        );
      }
    } catch (e) {
      if (e is LessonServiceException) rethrow;
      throw LessonServiceException('Failed to create lesson: ${e.toString()}');
    }
  }

  // Helper: Create lesson using multipart (Original way)
  static Future<Lesson> _createLessonViaBackend({
    required String submoduleId,
    required String title,
    String? description,
    required String type,
    String? duration,
    required bool isFree,
    required File contentFile,
    required String token,
  }) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse(ApiConfig.createLessonEndpoint),
    );
    request.headers.addAll(ApiConfig.getAuthHeadersMultipart(token));
    request.fields['subModuleId'] = submoduleId;
    request.fields['title'] = title;
    if (description != null) request.fields['description'] = description;
    request.fields['type'] = type;
    if (duration != null) request.fields['duration'] = duration;
    request.fields['isFree'] = isFree.toString();

    request.files.add(
      await http.MultipartFile.fromPath(
        'contentFile',
        contentFile.path,
        filename: path.basename(contentFile.path),
        contentType: _getMediaType(contentFile.path),
      ),
    );

    final streamedResponse = await request.send().timeout(
      const Duration(minutes: 10),
    );
    final response = await http.Response.fromStream(streamedResponse);
    await HttpInterceptorService.checkResponseAndHandleAuth(response);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return Lesson.fromJson(data['lesson'] ?? data);
    } else {
      try {
        final errorData = jsonDecode(response.body);
        throw LessonServiceException(errorData['message'] ?? 'Failed to create lesson.');
      } catch (e) {
        if (e is LessonServiceException) rethrow;
        
        // Handle HTML responses gracefully
        if (response.statusCode == 413) throw LessonServiceException('File is too large for the current server limit (Max 4.5MB on Vercel).');
        if (response.statusCode == 504) throw LessonServiceException('Upload timed out. File might be too large or internet is slow.');
        if (response.statusCode >= 500) throw LessonServiceException('Server Error (${response.statusCode}). Please check Vercel Logs. Your API keys/Cloudinary connection might be broken.');
        
        throw LessonServiceException('Unexpected server response: ${response.statusCode}');
      }
    }
  }

  // Helper: Create lesson record with existing URL
  static Future<Lesson> _createLessonRecordOnly({
    required String submoduleId,
    required String title,
    String? description,
    required String type,
    String? duration,
    required bool isFree,
    String? contentUrl,
    String? videoProvider,
    String? bunnyVideoId,
    String? bunnyLibraryId,
    required String token,
  }) async {
    final response = await http
        .post(
          Uri.parse(ApiConfig.createLessonEndpoint),
          headers: ApiConfig.getAuthHeaders(token),
          body: jsonEncode({
            'subModuleId': submoduleId,
            'title': title,
            'description': description,
            'type': type,
            'duration': duration,
            'isFree': isFree,
            'contentUrl': contentUrl,
            if (videoProvider != null) 'videoProvider': videoProvider,
            if (bunnyVideoId != null) 'bunnyVideoId': bunnyVideoId,
            if (bunnyLibraryId != null) 'bunnyLibraryId': bunnyLibraryId,
          }),
        )
        .timeout(ApiConfig.timeout);

    await HttpInterceptorService.checkResponseAndHandleAuth(response);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return Lesson.fromJson(data['lesson'] ?? data);
    } else {
      try {
        final errorData = jsonDecode(response.body);
        throw LessonServiceException(errorData['message'] ?? 'Failed to create lesson record.');
      } catch (e) {
        if (e is LessonServiceException) rethrow;
        throw LessonServiceException('Server Error (${response.statusCode}). Please check Vercel Logs.');
      }
    }
  }

  // Update Lesson (Admin Token)
  static Future<Lesson> updateLesson({
    required String lessonId,
    String? title,
    String? description,
    String? type,
    String? duration,
    bool? isFree,
    File? contentFile,
    void Function(double)? onProgress,
  }) async {
    try {
      final token = await StorageService.getToken();
      if (token == null) {
        throw LessonServiceException('Not authenticated. Please login again.');
      }

      String? uploadedUrl;
      Map<String, dynamic>? streamData;
      if (contentFile != null) {
        final fileSize = await contentFile.length();
        if (type != null && type.toLowerCase() == 'video') {
          streamData = await createBunnyStreamUpload(title ?? 'Course video');
          await uploadFileToBunnyStream(
            contentFile,
            streamData,
            onProgress: onProgress,
          );
          uploadedUrl = streamData['playbackUrl'] as String?;
        }
        // Non-video files will be sent as multipart below via the existing request
      }

      var request = http.MultipartRequest(
        'PUT',
        Uri.parse(ApiConfig.updateLessonEndpoint(lessonId)),
      );
      request.headers.addAll(ApiConfig.getAuthHeadersMultipart(token));

      if (title != null) request.fields['title'] = title;
      if (description != null) request.fields['description'] = description;
      if (type != null) request.fields['type'] = type;
      if (duration != null) request.fields['duration'] = duration;
      if (isFree != null) request.fields['isFree'] = isFree.toString();

      if (uploadedUrl != null) {
        request.fields['contentUrl'] = uploadedUrl;
        if (type?.toLowerCase() == 'video') {
          request.fields['videoProvider'] = 'bunny-stream';
          if (streamData?['videoId'] != null) {
            request.fields['bunnyVideoId'] = streamData!['videoId'].toString();
          }
          if (streamData?['libraryId'] != null) {
            request.fields['bunnyLibraryId'] = streamData!['libraryId']
                .toString();
          }
        }
      } else if (contentFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'contentFile', 
            contentFile.path,
            filename: path.basename(contentFile.path),
            contentType: _getMediaType(contentFile.path),
          ),
        );
      }

      final streamedResponse = await request.send().timeout(
        const Duration(minutes: 10),
      );
      final response = await http.Response.fromStream(streamedResponse);
      await HttpInterceptorService.checkResponseAndHandleAuth(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return Lesson.fromJson(data['lesson'] ?? data);
      } else {
        try {
          final errorData = jsonDecode(response.body);
          throw LessonServiceException(errorData['message'] ?? 'Failed to update lesson.');
        } catch (e) {
          if (e is LessonServiceException) rethrow;
          if (response.statusCode == 413) throw LessonServiceException('File is too large for the current server limit (Max 4.5MB).');
          throw LessonServiceException('Server Error (${response.statusCode}). Check Vercel Logs.');
        }
      }
    } catch (e) {
      if (e is LessonServiceException) rethrow;
      throw LessonServiceException('Failed to update lesson: ${e.toString()}');
    }
  }

  // Standalone upload util - uses backend multipart → Cloudinary
  static Future<String> uploadResource(File contentFile) async {
    try {
      final token = await StorageService.getToken();
      if (token == null) throw LessonServiceException('Not authenticated.');

      var request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConfig.uploadLessonEndpoint),
      );
      request.headers.addAll(ApiConfig.getAuthHeadersMultipart(token));
      request.files.add(
        await http.MultipartFile.fromPath(
          'contentFile',
          contentFile.path,
          filename: path.basename(contentFile.path),
          contentType: _getMediaType(contentFile.path),
        ),
      );

      final streamedResponse = await request.send().timeout(
        const Duration(minutes: 10),
      );
      final response = await http.Response.fromStream(streamedResponse);
      await HttpInterceptorService.checkResponseAndHandleAuth(response);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['url'] ?? '';
      } else {
        throw LessonServiceException(
          jsonDecode(response.body)['message'] ?? 'Upload failed.',
        );
      }
    } catch (e) {
      if (e is LessonServiceException) rethrow;
      throw LessonServiceException('Upload failed: $e');
    }
  }

  // Delete Lesson (Admin Token)
  static Future<void> deleteLesson(String lessonId) async {
    try {
      final token = await StorageService.getToken();

      if (token == null) {
        throw LessonServiceException('Not authenticated. Please login again.');
      }

      debugPrint(
        "Delete Lesson API Url: ${ApiConfig.deleteLessonEndpoint(lessonId)}",
      );
      final response = await http
          .delete(
            Uri.parse(ApiConfig.deleteLessonEndpoint(lessonId)),
            headers: ApiConfig.getAuthHeaders(token),
          )
          .timeout(ApiConfig.timeout);

      // Check for invalid token and handle auto-logout
      await HttpInterceptorService.checkResponseAndHandleAuth(response);

      if (response.statusCode == 200 || response.statusCode == 204) {
        debugPrint('Delete Lesson Success: ${response.body}');
        return;
      } else {
        debugPrint('Error Delete Lesson Status: ${response.statusCode}');
        debugPrint('Error Delete Lesson Body: ${response.body}');
        final error = jsonDecode(response.body);
        throw LessonServiceException(
          error['message'] ?? 'Failed to delete lesson. Please try again.',
        );
      }
    } catch (e) {
      if (e is LessonServiceException) {
        rethrow;
      }
      debugPrint('Delete lesson error: $e');
      throw LessonServiceException(
        'Network error. Please check your connection.',
      );
    }
  }
}

class LessonServiceException implements Exception {
  final String message;

  LessonServiceException(this.message);

  @override
  String toString() => message;
}
