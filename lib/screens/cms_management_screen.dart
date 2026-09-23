import 'package:flutter/material.dart';
import 'package:meeting_app/screens/student_notifications_screen.dart';
import '../services/cms_service.dart';
import '../models/cms_page.dart';
import '../widgets/app_drawer.dart';
import '../widgets/skeleton_loader.dart';

class CmsManagementScreen extends StatefulWidget {
  const CmsManagementScreen({super.key});

  @override
  State<CmsManagementScreen> createState() => _CmsManagementScreenState();
}

class _CmsManagementScreenState extends State<CmsManagementScreen> {
  List<CmsPageListItem> _pages = [];
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadPages();
  }

  Future<void> _loadPages() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final pages = await CmsService.getAllCmsPages();
      if (mounted) {
        setState(() {
          _pages = pages;
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
          _errorMessage = 'Failed to load CMS pages. Please try again.';
        });
      }
    }
  }

  String _getPageDisplayName(String slug) {
    switch (slug) {
      case 'about-us':
        return 'About Us';
      case 'privacy-policy':
        return 'Privacy Policy';
      case 'terms':
        return 'Terms & Conditions';
      default:
        return slug.replaceAll('-', ' ').split(' ').map((word) {
          return word[0].toUpperCase() + word.substring(1);
        }).join(' ');
    }
  }

  IconData _getPageIcon(String slug) {
    switch (slug) {
      case 'about-us':
        return Icons.info_outline;
      case 'privacy-policy':
        return Icons.privacy_tip;
      case 'terms':
        return Icons.description;
      default:
        return Icons.article;
    }
  }

  Future<void> _editPage(CmsPageListItem page) async {
    // First, fetch the full page content
    CmsPage? fullPage;
    try {
      // We need to fetch the page based on slug
      if (page.slug == 'about-us') {
        fullPage = await CmsService.getAboutUs();
      } else if (page.slug == 'privacy-policy') {
        fullPage = await CmsService.getPrivacyPolicy();
      } else if (page.slug == 'terms') {
        fullPage = await CmsService.getTerms();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load page content: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (fullPage == null) return;

    final titleController = TextEditingController(text: fullPage.title);
    final contentController = TextEditingController(text: fullPage.content);
    bool isSaving = false;

    if (!mounted) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Edit ${_getPageDisplayName(page.slug)}'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: contentController,
                    decoration: const InputDecoration(
                      labelText: 'Content (HTML)',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 15,
                    minLines: 10,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'You can use HTML tags like <h1>, <p>, <ul>, <li>, etc.',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (titleController.text.trim().isEmpty) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Title is required'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                        return;
                      }

                      setDialogState(() {
                        isSaving = true;
                      });

                      try {
                        await CmsService.updateCmsPage(
                          pageId: page.id,
                          title: titleController.text.trim(),
                          content: contentController.text.trim(),
                        );

                        if (context.mounted) {
                          Navigator.pop(context, true);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Page updated successfully!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() {
                          isSaving = false;
                        });
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to update page: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      _loadPages();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('CMS Management'),
        backgroundColor: const Color(0xFF5a189a),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const StudentNotificationsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading && _pages.isEmpty
          ? ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 3,
              itemBuilder: (context, index) => Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const SkeletonLoader(
                  width: double.infinity,
                  height: 80,
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
              ),
            )
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline,
                            size: 64, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadPages,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _pages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.article_outlined,
                              size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No CMS pages found',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadPages,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _pages.length,
                        itemBuilder: (context, index) {
                          final page = _pages[index];
                          return _buildPageCard(page);
                        },
                      ),
                    ),
        ),
    );
  }

  Widget _buildPageCard(CmsPageListItem page) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF5a189a).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _getPageIcon(page.slug),
            color: const Color(0xFF5a189a),
            size: 24,
          ),
        ),
        title: Text(
          _getPageDisplayName(page.slug),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          'Slug: ${page.slug}',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit, color: Color(0xFF5a189a)),
          onPressed: () => _editPage(page),
        ),
        onTap: () => _editPage(page),
      ),
    );
  }
}
