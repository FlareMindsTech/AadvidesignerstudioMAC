import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../models/cms_page.dart';
import 'storage_service.dart';
import 'http_interceptor_service.dart';

class CmsService {
  // Public endpoints (No Auth)
  
  // Get About Us page
  static Future<CmsPage> getAboutUs() async {
    try {
      debugPrint("Api Url: ${ApiConfig.getAboutUsEndpoint}");
      final response = await http
          .get(
            Uri.parse(ApiConfig.getAboutUsEndpoint),
            headers: ApiConfig.headers,
          )
          .timeout(ApiConfig.timeout);

      debugPrint('Get About Us status code: ${response.statusCode}');
      debugPrint('Get About Us response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return CmsPage.fromJson(data);
      } else {
        final error = jsonDecode(response.body);
        throw CmsServiceException(
          error['message'] ?? 'Failed to fetch About Us page. Please try again.',
        );
      }
    } catch (e) {
      if (e is CmsServiceException) rethrow;
      debugPrint('Get About Us error: $e');
      throw CmsServiceException('Network error. Please check your connection.');
    }
  }

  // Get Privacy Policy page
  static Future<CmsPage> getPrivacyPolicy() async {
    try {
      debugPrint("Api Url: ${ApiConfig.getPrivacyPolicyEndpoint}");
      final response = await http
          .get(
            Uri.parse(ApiConfig.getPrivacyPolicyEndpoint),
            headers: ApiConfig.headers,
          )
          .timeout(ApiConfig.timeout);

      debugPrint('Get Privacy Policy status code: ${response.statusCode}');
      debugPrint('Get Privacy Policy response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return CmsPage.fromJson(data);
      } else {
        final error = jsonDecode(response.body);
        throw CmsServiceException(
          error['message'] ?? 'Failed to fetch Privacy Policy page. Please try again.',
        );
      }
    } catch (e) {
      if (e is CmsServiceException) rethrow;
      debugPrint('Get Privacy Policy error: $e');
      throw CmsServiceException('Network error. Please check your connection.');
    }
  }

  // Get Terms & Conditions page
  static Future<CmsPage> getTerms() async {
    try {
      debugPrint("Api Url: ${ApiConfig.getTermsEndpoint}");
      final response = await http
          .get(
            Uri.parse(ApiConfig.getTermsEndpoint),
            headers: ApiConfig.headers,
          )
          .timeout(ApiConfig.timeout);

      debugPrint('Get Terms status code: ${response.statusCode}');
      debugPrint('Get Terms response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return CmsPage.fromJson(data);
      } else {
        final error = jsonDecode(response.body);
        throw CmsServiceException(
          error['message'] ?? 'Failed to fetch Terms & Conditions page. Please try again.',
        );
      }
    } catch (e) {
      if (e is CmsServiceException) rethrow;
      debugPrint('Get Terms error: $e');
      throw CmsServiceException('Network error. Please check your connection.');
    }
  }

  // Admin endpoints (Requires Auth)

  // Get All CMS Pages (List)
  static Future<List<CmsPageListItem>> getAllCmsPages() async {
    try {
      final token = await StorageService.getToken();
      if (token == null) {
        throw CmsServiceException('Not authenticated. Please login again.');
      }

      debugPrint("Api Url: ${ApiConfig.getAllCmsPagesEndpoint}");
      final response = await http
          .get(
            Uri.parse(ApiConfig.getAllCmsPagesEndpoint),
            headers: ApiConfig.getAuthHeaders(token),
          )
          .timeout(ApiConfig.timeout);

      // Check for invalid token and handle auto-logout
      await HttpInterceptorService.checkResponseAndHandleAuth(response);

      debugPrint('Get All CMS Pages status code: ${response.statusCode}');
      debugPrint('Get All CMS Pages response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic> pagesJson = data is List ? data : (data['pages'] ?? data['data'] ?? []);
        return pagesJson.map((json) => CmsPageListItem.fromJson(json)).toList();
      } else {
        final error = jsonDecode(response.body);
        throw CmsServiceException(
          error['message'] ?? 'Failed to fetch CMS pages. Please try again.',
        );
      }
    } catch (e) {
      if (e is CmsServiceException) rethrow;
      debugPrint('Get All CMS Pages error: $e');
      throw CmsServiceException('Network error. Please check your connection.');
    }
  }

  // Update CMS Page Content
  static Future<CmsPage> updateCmsPage({
    required String pageId,
    required String title,
    required String content,
  }) async {
    try {
      final token = await StorageService.getToken();
      if (token == null) {
        throw CmsServiceException('Not authenticated. Please login again.');
      }

      debugPrint("Api Url: ${ApiConfig.updateCmsPageEndpoint(pageId)}");
      final response = await http
          .put(
            Uri.parse(ApiConfig.updateCmsPageEndpoint(pageId)),
            headers: ApiConfig.getAuthHeaders(token),
            body: jsonEncode({
              'title': title,
              'content': content,
            }),
          )
          .timeout(ApiConfig.timeout);

      // Check for invalid token and handle auto-logout
      await HttpInterceptorService.checkResponseAndHandleAuth(response);

      debugPrint('Update CMS Page status code: ${response.statusCode}');
      debugPrint('Update CMS Page response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return CmsPage.fromJson(data['page'] ?? data);
      } else {
        final error = jsonDecode(response.body);
        throw CmsServiceException(
          error['message'] ?? 'Failed to update CMS page. Please try again.',
        );
      }
    } catch (e) {
      if (e is CmsServiceException) rethrow;
      debugPrint('Update CMS Page error: $e');
      throw CmsServiceException('Network error. Please check your connection.');
    }
  }
}

class CmsServiceException implements Exception {
  final String message;

  CmsServiceException(this.message);

  @override
  String toString() => message;
}

