import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'dart:io';
import '../widgets/app_drawer.dart';
import '../services/cms_service.dart';
import '../models/cms_page.dart';
import '../widgets/skeleton_loader.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> with WidgetsBindingObserver {
  static const platform =
      MethodChannel('com.example.meeting_app/screenshot');
  
  CmsPage? _page;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Call after the frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preventScreenshots();
    });
    _loadPrivacyPolicy();
  }

  Future<void> _loadPrivacyPolicy() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final page = await CmsService.getPrivacyPolicy();
      if (mounted) {
        setState(() {
          _page = page;
          _isLoading = false;
        });
      }
    } on CmsServiceException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load privacy policy. Please try again.';
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _allowScreenshots();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Re-apply screenshot prevention when app resumes
      _preventScreenshots();
    }
  }

  Future<void> _preventScreenshots() async {
    if (Platform.isAndroid) {
      try {
        final result = await platform.invokeMethod('preventScreenshot');
        debugPrint('Screenshot prevention enabled: $result');
      } catch (e) {
        debugPrint('Screenshot prevention error: $e');
      }
    }
  }

  Future<void> _allowScreenshots() async {
    if (Platform.isAndroid) {
      try {
        final result = await platform.invokeMethod('allowScreenshot');
        debugPrint('Screenshot allowed: $result');
      } catch (e) {
        debugPrint('Screenshot allow error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _allowScreenshots();
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        drawer: const AppDrawer(),
        body: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                constraints: const BoxConstraints(minHeight: 56, maxHeight: 64),
                color: const Color(0xFF5a189a),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () {
                        _allowScreenshots();
                        Navigator.of(context).pop();
                      },
                    ),
                    const Expanded(
                      child: Text(
                        'Privacy Policy',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48), // Balance the back button
                  ],
                ),
              ),

              // Content
              Expanded(
                child: _isLoading
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5a189a)),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Loading Privacy Policy...',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : _errorMessage.isNotEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                                  const SizedBox(height: 16),
                                  Text(
                                    _errorMessage,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _loadPrivacyPolicy,
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadPrivacyPolicy,
                            color: const Color(0xFF5a189a),
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Hero Section with Gradient
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.fromLTRB(20, 30, 20, 30),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [Color(0xFF5a189a), Color(0xFF7B2CBF)],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF5a189a).withValues(alpha: 0.3),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Icon(
                                            Icons.privacy_tip,
                                            color: Colors.white,
                                            size: 32,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          _page?.title ?? 'Privacy Policy',
                                          style: const TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            height: 1.2,
                                          ),
                                        ),
                                        if (_page?.updatedAt != null) ...[
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.calendar_today,
                                                size: 14,
                                                color: Colors.white.withValues(alpha: 0.9),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Last updated: ${_formatDate(_page!.updatedAt!)}',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.white.withValues(alpha: 0.9),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),

                                  // Content Card
                                  Container(
                                    margin: const EdgeInsets.all(20),
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.08),
                                          blurRadius: 16,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Html(
                                      data: _page?.content ?? 'Content coming soon...',
                                      style: {
                                        'body': Style(
                                          margin: Margins.zero,
                                          padding: HtmlPaddings.zero,
                                          fontSize: FontSize(15),
                                          lineHeight: LineHeight(1.8),
                                          color: Colors.black87,
                                        ),
                                        'h1': Style(
                                          fontSize: FontSize(24),
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF5a189a),
                                          margin: Margins.only(bottom: 16, top: 8),
                                        ),
                                        'h2': Style(
                                          fontSize: FontSize(20),
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF5a189a),
                                          margin: Margins.only(bottom: 14, top: 8),
                                        ),
                                        'h3': Style(
                                          fontSize: FontSize(18),
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                          margin: Margins.only(bottom: 12, top: 8),
                                        ),
                                        'p': Style(
                                          margin: Margins.only(bottom: 16),
                                          fontSize: FontSize(15),
                                          lineHeight: LineHeight(1.8),
                                        ),
                                        'ul': Style(
                                          margin: Margins.only(bottom: 16, left: 8),
                                        ),
                                        'ol': Style(
                                          margin: Margins.only(bottom: 16, left: 8),
                                        ),
                                        'li': Style(
                                          margin: Margins.only(bottom: 8),
                                          fontSize: FontSize(15),
                                          lineHeight: LineHeight(1.8),
                                        ),
                                        'strong': Style(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                        'em': Style(
                                          fontStyle: FontStyle.italic,
                                        ),
                                        'a': Style(
                                          color: const Color(0xFF5a189a),
                                          textDecoration: TextDecoration.underline,
                                        ),
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                ],
                              ),
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
