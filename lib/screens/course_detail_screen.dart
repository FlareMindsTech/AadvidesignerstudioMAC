import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';
import '../models/course.dart';
import '../models/module.dart';
import '../models/submodule.dart';
import '../models/lesson.dart';
import '../models/quiz.dart';
import '../models/question.dart';
import '../services/course_service.dart';
import '../services/module_service.dart';
import '../services/payment_service.dart';
import '../services/razorpay_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_network_image.dart';
import 'module_management_screen.dart';
import 'lesson_list_screen.dart';
import 'enrolled_students_screen.dart';
import 'create_lesson_screen.dart';
import '../utils/submodule_tree_builder.dart';
import 'package:provider/provider.dart';
import 'lesson_detail_screen.dart';

class CourseDetailScreen extends StatefulWidget {
  final Course course;

  const CourseDetailScreen({super.key, required this.course});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  Course? _course; // Store the updated course from API
  List<Module> _modules = [];
  bool _isLoadingModules = false;
  bool _isEnrolling = false;
  bool _isProcessingPayment = false;
  String _errorMessage = '';
  String? _currentUserRole;
  String? _currentUserEmail;
  String? _currentUserPhone;
  bool _paymentOrEnrollmentSucceeded =
      false; // Track if payment/enrollment succeeded
  Map<String, bool> _expandedSubModules = {}; // Track expanded submodules
  Map<String, bool> _expandedQuizzes = {}; // Track expanded quizzes
  DateTime? _subscriptionExpiresAt; // Subscription expiry date
  bool _isSubscriptionExpired = false; // Whether subscription has expired
  String?
  _selectedPaymentOption; // 'full' or 'emi' - user's selected payment option

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Get the current course (use updated one if available, otherwise use widget.course)
  Course get _currentCourse => _course ?? widget.course;

  @override
  void initState() {
    super.initState();
    RazorpayService.initialize();
    _loadCurrentUserRole();
    _loadModules();
  }

  @override
  void dispose() {
    RazorpayService.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUserRole() async {
    final role = await StorageService.getRole();
    final user = await StorageService.getUser();
    setState(() {
      _currentUserRole = role?.toLowerCase();
      _currentUserEmail = user?.email;
      _currentUserPhone = user?.phoneNumber;
    });
  }

  Future<void> _loadModules() async {
    if (widget.course.id == null) return;

    setState(() {
      _isLoadingModules = true;
      _errorMessage = '';
    });

    try {
      final courseWithModules = await CourseService.getSingleCourseWithModules(
        widget.course.id!,
      );
      if (mounted) {
        setState(() {
          _course = courseWithModules
              .course; // Update course with fresh data from API
          _modules = courseWithModules.modules;
          _isLoadingModules = false;
        });

        // Debug: Print subscription details after state update
        debugPrint(
          'Course loaded - isSubscribed: ${_currentCourse.isSubscribed}',
        );
        debugPrint(
          'Course loaded - subscriptionDetails: ${_currentCourse.subscriptionDetails}',
        );

        // Check for subscription expiry if user is subscribed
        if (_isStudent && _currentCourse.isSubscribed == true) {
          _checkSubscriptionExpiry();
        }
      }
    } on CourseServiceException catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingModules = false;
          _errorMessage = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingModules = false;
          _errorMessage = 'Failed to load modules. Please try again.';
        });
      }
    }
  }

  Future<void> _checkSubscriptionExpiry() async {
    if (!_isStudent || _currentCourse.id == null) return;

    try {
      // Get payment history to check for subscription expiry
      final paymentHistory = await PaymentService.getPaymentHistory();

      // Find payment/subscription for this course
      for (final payment in paymentHistory) {
        final courseId = payment['courseId'] ?? payment['course'];
        String? courseIdStr;

        if (courseId is Map) {
          courseIdStr =
              courseId['_id']?.toString() ?? courseId['id']?.toString();
        } else {
          courseIdStr = courseId?.toString();
        }

        if (courseIdStr == _currentCourse.id) {
          // Check for expiry date
          final expiresAt = payment['expiresAt'] ?? payment['expires_at'];
          if (expiresAt != null) {
            try {
              final expiryDate = DateTime.parse(expiresAt.toString());
              final now = DateTime.now();
              final isExpired = now.isAfter(expiryDate);

              if (mounted) {
                setState(() {
                  _subscriptionExpiresAt = expiryDate;
                  _isSubscriptionExpired = isExpired;
                });
              }
              return;
            } catch (e) {
              debugPrint('Error parsing expiry date: $e');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking subscription expiry: $e');
    }
  }

  Future<void> _showAddModuleDialogForCourse() async {
    if (_currentCourse.id == null) return;

    final titleController = TextEditingController();
    final orderController = TextEditingController(
      text: (_modules.length + 1).toString(),
    );

    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Modern Header with Gradient
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF5a189a), Color(0xFF9C27B0)],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.view_module,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Add Module',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context, false),
                    ),
                  ],
                ),
              ),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title Field
                      Text(
                        'Module Title',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: TextField(
                          controller: titleController,
                          autofocus: true,
                          style: const TextStyle(fontSize: 16),
                          decoration: InputDecoration(
                            hintText: 'e.g., Module 1: Introduction',
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            prefixIcon: Icon(
                              Icons.title,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Order Field
                      Text(
                        'Display Order',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: TextField(
                          controller: orderController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 16),
                          decoration: InputDecoration(
                            hintText: 'Enter order number',
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            prefixIcon: Icon(
                              Icons.sort,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Footer Actions
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                  border: Border(top: BorderSide(color: Colors.grey[200]!)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Colors.grey),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          if (titleController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter a module title'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          final order = int.tryParse(orderController.text);
                          if (order == null || order < 1) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please enter a valid order number',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          Navigator.pop(context, true);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5a189a),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Add Module',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result == true) {
      final order = int.parse(orderController.text);
      await _addModuleForCourse(
        title: titleController.text.trim(),
        order: order,
      );
    }
  }

  Future<void> _addModuleForCourse({
    required String title,
    required int order,
  }) async {
    if (_currentCourse.id == null) return;

    setState(() {
      _isLoadingModules = true;
      _errorMessage = '';
    });

    try {
      await ModuleService.addModule(
        courseId: _currentCourse.id!,
        title: title,
        order: order,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Module added successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ),
      );

      await _loadModules();
    } on ModuleServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingModules = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingModules = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to add module. Please try again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ),
      );
    }
  }

  Future<void> _enrollInCourse() async {
    if (_currentCourse.id == null) return;

    if (!_currentCourse.isFree) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'This is a paid course. Please use the payment flow.',
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isEnrolling = true;
      _errorMessage = '';
    });

    try {
      await ModuleService.enrollInCourse(_currentCourse.id!);
      if (mounted) {
        setState(() {
          _paymentOrEnrollmentSucceeded = true; // Mark enrollment as successful
          // Locally mark as subscribed so UI treats it as enrolled
          _course = _currentCourse.copyWith(isSubscribed: true);
        });
        await _loadModules();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('Successfully enrolled in course!')),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } on ModuleServiceException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to enroll. Please try again.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isEnrolling = false;
        });
      }
    }
  }

  bool get _isAdminOrOwner {
    return _currentUserRole == 'admin' || _currentUserRole == 'owner';
  }

  bool get _isStudent {
    return _currentUserRole == 'student' || _currentUserRole == 'user';
  }

  Future<void> _checkSubscriptionAndNavigate(Module module) async {
    // Allow access for admin/owner
    if (_isAdminOrOwner) {
      Navigator.push(
        context,
        PageTransition(
          type: PageTransitionType.rightToLeft,
          child: LessonListScreen(module: module),
        ),
      ).then((_) {
        if (mounted) {
          _loadModules();
        }
      });
      return;
    }

    // For students, check subscription status
    if (_isStudent) {
      // Check if course is free or subscribed
      if (_currentCourse.isFree || _currentCourse.isSubscribed == true) {
        // Allow access
        Navigator.push(
          context,
          PageTransition(
            type: PageTransitionType.rightToLeft,
            child: LessonListScreen(module: module),
          ),
        ).then((_) {
          if (mounted) {
            _loadModules();
          }
        });
      } else {
        // Show warning popup for subscription failed
        _showSubscriptionWarning();
      }
    } else {
      // For other roles, allow access
      Navigator.push(
        context,
        PageTransition(
          type: PageTransitionType.rightToLeft,
          child: LessonListScreen(module: module),
        ),
      ).then((result) {
        if (result == true && mounted) {
          _loadModules();
        }
      });
    }
  }

  void _showSubscriptionWarning() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange[700],
              size: 28,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Payment Required',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Text(
          'Please complete the first payment to access course modules and lessons.',
          style: TextStyle(fontSize: 15, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (_selectedPaymentOption == 'full') {
                _handleFullPayment();
              } else if (_selectedPaymentOption == 'emi') {
                _handleEMIPayment();
              } else {
                _handleFullPayment(); // Fallback
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Make Payment',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;

    return PopScope(
      canPop:
          !_paymentOrEnrollmentSucceeded, // Prevent auto-pop if payment/enrollment succeeded
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _paymentOrEnrollmentSucceeded) {
          // System back button was pressed, manually pop with result
          Navigator.of(context).pop(true);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              // Return result if payment/enrollment succeeded
              Navigator.of(context).pop(_paymentOrEnrollmentSucceeded);
            },
          ),
          title: const Text(
            'Course Details',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          actions: [
            if (_isAdminOrOwner) ...[
              IconButton(
                icon: const Icon(Icons.people),
                onPressed: () {
                  Navigator.push(
                    context,
                    PageTransition(
                      type: PageTransitionType.rightToLeft,
                      child: EnrolledStudentsScreen(course: _currentCourse),
                    ),
                  );
                },
                tooltip: 'View Enrolled Students',
              ),
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  Navigator.push(
                    context,
                    PageTransition(
                      type: PageTransitionType.rightToLeft,
                      child: ModuleManagementScreen(course: _currentCourse),
                    ),
                  ).then((_) => _loadModules());
                },
                tooltip: 'Manage Modules',
              ),
            ],
          ],
        ),
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              // Hero Image Section
              SliverToBoxAdapter(child: _buildHeroSection()),

              // Course Info Card
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                  child: _buildCourseInfoCard(isSmallScreen),
                ),
              ),

              // Payment/Enroll/Renewal Buttons - Only show if NOT loading
              if (_isStudent &&
                  !_paymentOrEnrollmentSucceeded &&
                  !_isLoadingModules)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 12 : 16,
                      vertical: 8,
                    ),
                    child: _isSubscriptionExpired
                        ? _buildRenewalSection(isSmallScreen)
                        : (_currentCourse.isSubscribed == true
                              ? _buildEnrolledStatusCard(isSmallScreen)
                              : (_currentCourse.isFree
                                    ? _buildEnrollButton()
                                    : _buildPaymentButtons(isSmallScreen))),
                  ),
                ),

              // Modules Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                  child: _buildModulesSection(isSmallScreen),
                ),
              ),

              // Live Meetings Section
              if (_currentCourse.liveMeetings != null &&
                  _currentCourse.liveMeetings!.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                    child: _buildLiveMeetingsSection(isSmallScreen),
                  ),
                ),

              // Placeholder Sections (hidden in production)
              // Only show in debug mode or if explicitly enabled
              // These sections are commented out to prevent "Coming Soon" placeholders from showing
              // Uncomment and implement when ready, or remove if not needed
              // if (_showPlaceholderSections || kDebugMode) ...[
              //   // Offline Downloads Section
              //   // SliverToBoxAdapter(
              //   //   child: Padding(
              //   //     padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
              //   //     child: _buildOfflineDownloadsSection(isSmallScreen),
              //   //   ),
              //   // ),
              //
              //   // Free Material Section
              //   // SliverToBoxAdapter(
              //   //   child: Padding(
              //   //     padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
              //   //     child: _buildFreeMaterialSection(isSmallScreen),
              //   //   ),
              //   // ),
              //
              //   // Testimonials Section
              //   // SliverToBoxAdapter(
              //   //   child: Padding(
              //   //     padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
              //   //     child: _buildTestimonialsSection(isSmallScreen),
              //   //   ),
              //   // ),
              // ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    return GestureDetector(
      onTap: () {
        if (_currentCourse.thumbnail != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Scaffold(
                backgroundColor: Colors.black,
                appBar: AppBar(
                  backgroundColor: Colors.black,
                  iconTheme: const IconThemeData(color: Colors.white),
                ),
                body: Center(
                  child: InteractiveViewer(
                    child: Hero(
                      tag: 'course_image_${_currentCourse.id}',
                      child: AppNetworkImage(
                        imageUrl: _currentCourse.thumbnail,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }
      },
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            height: 220,
            decoration: const BoxDecoration(color: Colors.white),
            child: Hero(
              tag: 'course_image_${_currentCourse.id}',
              child: AppNetworkImage(
                imageUrl: _currentCourse.thumbnail,
                fit: BoxFit.contain,
                errorIcon: Icons.book,
              ),
            ),
          ),
        // Gradient overlay
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.4),
                ],
              ),
            ),
          ),
        ),
        // Price Badge
        Positioned(
          top: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _currentCourse.isFree
                  ? Colors.green
                  : AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _currentCourse.isFree
                      ? 'FREE'
                      : '₹${_currentCourse.price.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        _currentCourse.discount != null &&
                            _currentCourse.discount! > 0
                        ? FontWeight.w500
                        : FontWeight.bold,
                    color: Colors.white,
                    decoration:
                        _currentCourse.discount != null &&
                            _currentCourse.discount! > 0
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                ),
                if (_currentCourse.discount != null &&
                    _currentCourse.discount! > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    '₹${(_currentCourse.price * (1 - _currentCourse.discount! / 100)).clamp(0, double.infinity).toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    ),
   );
  }

  Widget _buildCourseInfoCard(bool isSmallScreen) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 14 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              _currentCourse.title,
              style: TextStyle(
                fontSize: isSmallScreen ? 20 : 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),

            // Badges Row
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_currentCourse.isLiveCourse)
                  _buildBadge(
                    Icons.videocam,
                    'Live Course',
                    Colors.red,
                    isSmallScreen,
                  ),
                _buildBadge(
                  Icons.category,
                  _currentCourse.category,
                  AppTheme.primaryColor,
                  isSmallScreen,
                ),
                _buildBadge(
                  Icons.access_time,
                  _currentCourse.duration,
                  Colors.blue,
                  isSmallScreen,
                ),
                if (_currentCourse.durationinDays != null)
                  _buildBadge(
                    Icons.calendar_today,
                    _formatDurationDays(_currentCourse.durationinDays!),
                    Colors.orange,
                    isSmallScreen,
                  ),
                if (_currentCourse.isRecurring)
                  _buildBadge(
                    Icons.sync,
                    'Recurring / Renewal',
                    Colors.green[600]!,
                    isSmallScreen,
                  ),
                if (_currentCourse.discount != null &&
                    _currentCourse.discount! > 0)
                  _buildBadge(
                    Icons.local_offer,
                    'Discount: ${(_currentCourse.discount! > 100 ? 100 : _currentCourse.discount!).toStringAsFixed(0)}% OFF',
                    Colors.pink,
                    isSmallScreen,
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // Description
            Text(
              'About This Course',
              style: TextStyle(
                fontSize: isSmallScreen ? 15 : 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _currentCourse.description.isEmpty
                  ? 'No description available.'
                  : _currentCourse.description,
              style: TextStyle(
                fontSize: isSmallScreen ? 13 : 14,
                color: Colors.grey[700],
                height: 1.6,
              ),
            ),

            // Payment Options - Hide if enrolled/free or loading
            if (_currentCourse.hasPaymentOptions &&
                !_currentCourse.isFree &&
                _currentCourse.isSubscribed != true &&
                !_isLoadingModules) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.payment,
                          size: isSmallScreen ? 18 : 20,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Payment Options',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 14 : 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (_currentCourse.isRecurring)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.green.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.sync,
                                  size: 16,
                                  color: Colors.green[700],
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Renewal Course',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 12 : 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_currentCourse.supportsFullPayment &&
                            !_currentCourse.isRecurring)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.green.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 16,
                                  color: Colors.green[700],
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Full Payment',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 12 : 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_currentCourse.supportsEMI)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.orange.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.credit_card,
                                  size: 16,
                                  color: Colors.orange[700],
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'EMI Available',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 12 : 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    // Show EMI Plans if available
                    if (_currentCourse.supportsEMI &&
                        _currentCourse.paymentOptionsObj != null &&
                        _currentCourse.paymentOptionsObj!['emiPlans'] !=
                            null) ...[
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        'Available EMI Plans:',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 12 : 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...((_currentCourse.paymentOptionsObj!['emiPlans']
                              as List)
                          .map((plan) {
                            final planMap = Map<String, dynamic>.from(
                              plan as Map,
                            );
                            final installments =
                                planMap['installments'] as int? ?? 0;
                            final totalAmount =
                                (planMap['totalAmount'] as num?)?.toDouble() ??
                                _currentCourse.price;
                            final perInstallment = installments > 0
                                ? totalAmount / installments
                                : 0.0;
                            final planName =
                                planMap['name'] as String? ??
                                '$installments months EMI';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.blue.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          planName,
                                          style: TextStyle(
                                            fontSize: isSmallScreen ? 12 : 13,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '₹${perInstallment.toStringAsFixed(0)}/month Ã— $installments months',
                                          style: TextStyle(
                                            fontSize: isSmallScreen ? 11 : 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '₹${totalAmount.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 13 : 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          })
                          .toList()),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Formats duration in days for display
  /// Returns "Lifetime Access" for lifetime courses (99999 days or very large numbers)
  String _formatDurationDays(int days) {
    // Check if it's a lifetime access course (99999 or any very large number >= 99999)
    if (days >= 99999) {
      return 'Lifetime Access';
    }
    return '$days days';
  }

  Widget _buildBadge(
    IconData icon,
    String label,
    Color color,
    bool isSmallScreen,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 10 : 12,
        vertical: isSmallScreen ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: isSmallScreen ? 14 : 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isSmallScreen ? 11 : 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleChip({
    required IconData icon,
    required String label,
    required bool isSmallScreen,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 8 : 10,
        vertical: isSmallScreen ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.grey[300]!, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.grey[700]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: isSmallScreen ? 11 : 12,
              color: Colors.grey[800],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnrollButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isEnrolling ? null : _enrollInCourse,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: _isEnrolling
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Enroll Now (Free)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildRenewalSection(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange[50]!, Colors.orange[100]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange[300]!, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange[700],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Subscription Expired',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 16 : 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[900],
                      ),
                    ),
                    if (_subscriptionExpiresAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Expired on: ${_formatExpiryDate(_subscriptionExpiresAt!)}',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 12 : 13,
                          color: Colors.orange[800],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Info Text
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: Colors.orange[800]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your subscription has expired. Renew now to continue accessing course content.',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 12 : 13,
                      color: Colors.orange[900],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Renewal Button
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _isProcessingPayment ? null : _handleFullPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isProcessingPayment
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.refresh, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Renew Subscription',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 15 : 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentButtons(bool isSmallScreen) {
    double finalPrice =
        _currentCourse.discount != null && _currentCourse.discount! > 0
        ? _currentCourse.price * (1 - _currentCourse.discount! / 100)
        : _currentCourse.price;
    if (finalPrice < 0) finalPrice = 0;

    final bool showBoth =
        _currentCourse.supportsFullPayment && _currentCourse.supportsEMI;

    // If both options are available, show selector first
    if (showBoth) {
      return Column(
        children: [
          // Payment Option Selector
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                // Full Payment Option
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedPaymentOption = 'full';
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedPaymentOption == 'full'
                            ? AppTheme.primaryColor
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.payment,
                            size: 18,
                            color: _selectedPaymentOption == 'full'
                                ? Colors.white
                                : Colors.grey[700],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Full Payment',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 13 : 14,
                              fontWeight: FontWeight.w600,
                              color: _selectedPaymentOption == 'full'
                                  ? Colors.white
                                  : Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // EMI Option
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedPaymentOption = 'emi';
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedPaymentOption == 'emi'
                            ? AppTheme.primaryColor
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.credit_card,
                            size: 18,
                            color: _selectedPaymentOption == 'emi'
                                ? Colors.white
                                : Colors.grey[700],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'EMI',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 13 : 14,
                              fontWeight: FontWeight.w600,
                              color: _selectedPaymentOption == 'emi'
                                  ? Colors.white
                                  : Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Show selected payment button
          if (_selectedPaymentOption == 'full')
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isProcessingPayment ? null : _handleFullPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isProcessingPayment
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.payment, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Pay ₹${finalPrice.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            )
          else if (_selectedPaymentOption == 'emi')
            OutlinedButton(
              onPressed: _isProcessingPayment ? null : _handleEMIPayment,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                side: BorderSide(
                  color: AppTheme.primaryColor.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              child: _isProcessingPayment
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryColor,
                        ),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.credit_card, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Pay in EMI',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 14 : 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            )
          else
            // Default to full payment if nothing selected
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _selectedPaymentOption = 'full';
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[300],
                  foregroundColor: Colors.grey[700],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.touch_app, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Select Payment Option Above',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 13 : 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    }

    // Show single button (full height layout) when only one option is available
    return Column(
      children: [
        // Full Payment Button
        if (_currentCourse.supportsFullPayment)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _isProcessingPayment ? null : _handleFullPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _isProcessingPayment
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.payment, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Pay ₹${finalPrice.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),

        // EMI Button
        if (_currentCourse.supportsEMI)
          OutlinedButton(
            onPressed: _isProcessingPayment ? null : _handleEMIPayment,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              side: BorderSide(
                color: AppTheme.primaryColor.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
            child: _isProcessingPayment
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.primaryColor,
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.credit_card, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Pay in EMI',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 14 : 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
          ),
      ],
    );
  }

  Widget _buildSubscriptionDetailsCard(bool isSmallScreen) {
    final subscriptionDetails = _currentCourse.subscriptionDetails!;

    // STRONG HIDE: If course is recurring/renewal, hide this card completely
    final isRenewal =
        _currentCourse.isRecurring == true ||
        (subscriptionDetails['isRecurring'] == true) ||
        (subscriptionDetails['type']?.toString().toLowerCase() == 'renewal') ||
        (subscriptionDetails['is_recurring'] == true);

    // User requested to hide this card for Renewal courses
    if (isRenewal) return const SizedBox.shrink();

    final status = subscriptionDetails['status']?.toString() ?? 'unknown';

    final totalCount = subscriptionDetails['totalCount'] as int? ?? 0;
    final paidCount = subscriptionDetails['paidCount'] as int? ?? 0;
    final totalAmount =
        (subscriptionDetails['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final paidAmount =
        (subscriptionDetails['paidAmount'] as num?)?.toDouble() ?? 0.0;
    final balanceAmount =
        (subscriptionDetails['balanceAmount'] as num?)?.toDouble() ?? 0.0;

    String? nextPaymentAtStr;
    DateTime? nextPaymentAt;
    if (subscriptionDetails['nextPaymentAt'] != null) {
      try {
        nextPaymentAt = DateTime.parse(subscriptionDetails['nextPaymentAt']);
        nextPaymentAtStr =
            '${nextPaymentAt.day}/${nextPaymentAt.month}/${nextPaymentAt.year}';
      } catch (e) {
        nextPaymentAtStr = subscriptionDetails['nextPaymentAt'].toString();
      }
    }

    String? expiresAtStr;
    DateTime? expiresAt;
    if (subscriptionDetails['expiresAt'] != null) {
      try {
        expiresAt = DateTime.parse(subscriptionDetails['expiresAt']);
        expiresAtStr = '${expiresAt.day}/${expiresAt.month}/${expiresAt.year}';
      } catch (e) {
        expiresAtStr = subscriptionDetails['expiresAt'].toString();
      }
    }

    Color statusColor;
    String statusText;
    switch (status.toLowerCase()) {
      case 'active':
        statusColor = Colors.green;
        statusText = 'Active';
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusText = 'Pending';
        break;
      case 'completed':
        statusColor = Colors.blue;
        statusText = 'Completed';
        break;
      default:
        statusColor = Colors.grey;
        statusText = status.toUpperCase();
    }

    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.subscriptions_rounded,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 12),
                    const Flexible(
                      child: Text(
                        'Subscription Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              // Status Badge with Flexible to avoid overflow
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (status.toLowerCase() == 'pending' ||
                        status.toLowerCase() == 'unknown')
                      IconButton(
                        icon: _isProcessingPayment
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.primaryColor,
                                ),
                              )
                            : const Icon(Icons.refresh, size: 18),
                        onPressed: _isProcessingPayment
                            ? null
                            : () => _loadModules(),
                        tooltip: 'Refresh Status',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    if (status.toLowerCase() == 'pending' ||
                        status.toLowerCase() == 'unknown')
                      const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor, width: 1),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                        softWrap: false,
                        overflow: TextOverflow.clip,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (!isRenewal) ...[
            const SizedBox(height: 16),
            // Payment Progress
            Row(
              children: [
                Expanded(
                  child: _buildDetailItem(
                    'Paid',
                    '₹${paidAmount.toStringAsFixed(0)}',
                    Colors.green,
                    isSmallScreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDetailItem(
                    'Remaining',
                    '₹${balanceAmount.toStringAsFixed(0)}',
                    Colors.orange,
                    isSmallScreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDetailItem(
                    'Total',
                    '₹${totalAmount.toStringAsFixed(0)}',
                    AppTheme.primaryColor,
                    isSmallScreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Installment Progress
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Installments',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 13 : 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  Text(
                    '$paidCount / $totalCount',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 13 : 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: totalCount > 0 ? paidCount / totalCount : 0,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppTheme.primaryColor,
                ),
                minHeight: 8,
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Dates
          if (nextPaymentAtStr != null || expiresAtStr != null) ...[
            const Divider(),
            const SizedBox(height: 12),
            if (nextPaymentAtStr != null && !isRenewal)
              _buildDateItem(
                'Next Payment',
                nextPaymentAtStr,
                Icons.calendar_today,
                Colors.blue,
                isSmallScreen,
              ),
            if (nextPaymentAtStr != null && expiresAtStr != null && !isRenewal)
              const SizedBox(height: 8),
            if (expiresAtStr != null)
              _buildDateItem(
                'Expires On',
                expiresAtStr,
                Icons.event,
                Colors.purple,
                isSmallScreen,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailItem(
    String label,
    String value,
    Color color,
    bool isSmallScreen,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isSmallScreen ? 11 : 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: isSmallScreen ? 14 : 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateItem(
    String label,
    String value,
    IconData icon,
    Color color,
    bool isSmallScreen,
  ) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: isSmallScreen ? 13 : 14,
            color: Colors.grey[600],
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: isSmallScreen ? 13 : 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Future<void> _handleFullPayment() async {
    if (_currentCourse.id == null) return;

    setState(() {
      _isProcessingPayment = true;
      _errorMessage = '';
    });

    try {
      // Initiate payment
      final paymentData = await PaymentService.initiatePayment(
        courseId: _currentCourse.id!,
      );

      if (mounted) {
        setState(() {
          _isProcessingPayment = false;
        });

        // Detect if server returned a subscription or a regular order
        final subscriptionId =
            paymentData['subscriptionId'] ?? paymentData['localSubscriptionId'];
        final orderId = paymentData['orderId'];

        if (subscriptionId != null && subscriptionId.toString().isNotEmpty) {
          // Open Razorpay for subscription (Renewal/Recurring)
          await RazorpayService.openSubscription(
            keyId: paymentData['keyId'] ?? '',
            subscriptionId: subscriptionId.toString(),
            courseTitle: paymentData['courseTitle'] ?? _currentCourse.title,
            courseId: _currentCourse.id!,
            userEmail: _currentUserEmail,
            userContact: _currentUserPhone,
            onSuccess: (paymentResponse) async {
              debugPrint(
                'Razorpay Subscription Success Response: $paymentResponse',
              );
              final paymentId =
                  paymentResponse['razorpay_payment_id'] ??
                  paymentResponse['payment_id'] ??
                  paymentResponse['paymentId'] ??
                  '';
              final signature =
                  paymentResponse['razorpay_signature'] ??
                  paymentResponse['signature'] ??
                  '';
              final subId =
                  paymentResponse['razorpay_subscription_id'] ??
                  paymentResponse['subscription_id'] ??
                  paymentResponse['subscriptionId'] ??
                  subscriptionId.toString();

              await _verifySubscription(
                subscriptionId: subId,
                paymentId: paymentId,
                signature: signature,
              );
            },
            onError: (error) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error), backgroundColor: Colors.red),
                );
              }
            },
          );
        } else {
          // Open regular payment gateway
          await RazorpayService.openPayment(
            keyId: paymentData['keyId'] ?? '',
            orderId: orderId?.toString() ?? '',
            amount: paymentData['amount'] ?? 0,
            courseTitle: paymentData['courseTitle'] ?? _currentCourse.title,
            courseId: _currentCourse.id!,
            userEmail: _currentUserEmail,
            userContact: _currentUserPhone,
            onSuccess: (paymentResponse) async {
              final paymentId = paymentResponse['razorpay_payment_id'] ?? '';
              final signature = paymentResponse['razorpay_signature'] ?? '';
              final rOrderId =
                  paymentResponse['razorpay_order_id'] ??
                  orderId?.toString() ??
                  '';

              await _verifyPayment(
                orderId: rOrderId,
                paymentId: paymentId,
                signature: signature,
              );
            },
            onError: (error) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error), backgroundColor: Colors.red),
                );
              }
            },
          );
        }
      }
    } on PaymentServiceException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessingPayment = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Failed to initiate payment. Please try again.',
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingPayment = false;
        });
      }
    }
  }

  Future<void> _verifySubscription({
    required String subscriptionId,
    required String paymentId,
    required String signature,
  }) async {
    if (_currentCourse.id == null) return;

    setState(() => _isProcessingPayment = true);

    try {
      await PaymentService.verifySubscription(
        courseId: _currentCourse.id!,
        subscriptionId: subscriptionId,
        paymentId: paymentId,
        signature: signature,
      );

      if (mounted) {
        setState(() {
          _paymentOrEnrollmentSucceeded = true;
          _isProcessingPayment = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Subscription activated successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        await Future.delayed(const Duration(seconds: 2));
        await _loadModules();
        await _loadCurrentUserRole();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingPayment = false);
    }
  }

  Future<void> _verifyPayment({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    if (_currentCourse.id == null) return;

    debugPrint('Verifying payment...');
    debugPrint('Course ID: ${_currentCourse.id}');
    debugPrint('Order ID: $orderId');
    debugPrint('Payment ID: $paymentId');
    debugPrint('Signature: $signature');

    setState(() {
      _isProcessingPayment = true;
    });

    try {
      final result = await PaymentService.verifyPayment(
        courseId: _currentCourse.id!,
        razorpayOrderId: orderId,
        razorpayPaymentId: paymentId,
        razorpaySignature: signature,
      );

      debugPrint('Payment verification result: $result');

      if (mounted) {
        setState(() {
          _isProcessingPayment = false;
        });

        setState(() {
          _paymentOrEnrollmentSucceeded = true; // Mark payment as successful
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Payment successful! You have been enrolled in the course.',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 4),
          ),
        );

        // Reload modules to reflect enrollment
        _loadModules();
      }
    } on PaymentServiceException catch (e) {
      if (mounted) {
        setState(() {
          _isProcessingPayment = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessingPayment = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Payment verification failed. Please contact support.',
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _handleEMIPayment() async {
    if (_currentCourse.id == null) return;

    // Get EMI plans from course data
    List<Map<String, dynamic>>? emiPlans;
    if (_currentCourse.paymentOptionsObj != null &&
        _currentCourse.paymentOptionsObj!['emiPlans'] != null) {
      emiPlans = List<Map<String, dynamic>>.from(
        _currentCourse.paymentOptionsObj!['emiPlans'] as List,
      );
    }

    // If no EMI plans available, show error
    if (emiPlans == null || emiPlans.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No EMI plans available for this course.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // Show dialog to select EMI plan
    Map<String, dynamic>? selectedPlanForDialog;
    final selectedPlan = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.credit_card, color: AppTheme.primaryColor, size: 24),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Select EMI Plan',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Choose an EMI plan to proceed with payment:',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ...emiPlans!.map((plan) {
                    final installments = plan['installments'] as int? ?? 0;
                    final totalAmount =
                        (plan['totalAmount'] as num?)?.toDouble() ??
                        _currentCourse.price;
                    final perInstallment = installments > 0
                        ? totalAmount / installments
                        : 0;
                    final planName =
                        plan['name'] as String? ?? '$installments months EMI';
                    final isSelected = selectedPlanForDialog == plan;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primaryColor
                              : Colors.grey[300]!,
                          width: isSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        color: isSelected
                            ? AppTheme.primaryColor.withValues(alpha: 0.05)
                            : Colors.white,
                      ),
                      child: InkWell(
                        onTap: () {
                          setDialogState(() {
                            selectedPlanForDialog = plan;
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? AppTheme.primaryColor
                                        : Colors.grey[400]!,
                                    width: 2,
                                  ),
                                  color: isSelected
                                      ? AppTheme.primaryColor
                                      : Colors.transparent,
                                ),
                                child: isSelected
                                    ? const Icon(
                                        Icons.check,
                                        size: 16,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      planName,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected
                                            ? AppTheme.primaryColor
                                            : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '₹${perInstallment.toStringAsFixed(0)} per month',
                                      style: TextStyle(
                                        color: AppTheme.primaryColor,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                    if (installments > 0) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Total: ₹${totalAmount.toStringAsFixed(0)} (${installments} installments)',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              ElevatedButton(
                onPressed: selectedPlanForDialog == null
                    ? null
                    : () => Navigator.pop(context, selectedPlanForDialog),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Proceed with Payment',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );

    if (selectedPlan == null) return;

    final installmentCount = selectedPlan['installments'] as int? ?? 0;

    setState(() {
      _isProcessingPayment = true;
      _errorMessage = '';
    });

    try {
      // Initiate subscription
      final subscriptionData = await PaymentService.initiateSubscription(
        courseId: _currentCourse.id!,
        totalCount: installmentCount,
        emiPlanId: (selectedPlan['plan_id'] ?? selectedPlan['_id'] ?? '')
            .toString(),
      );

      if (mounted) {
        setState(() {
          _isProcessingPayment = false;
        });

        // Open Razorpay for subscription
        await RazorpayService.openSubscription(
          keyId: subscriptionData['keyId'] ?? '',
          subscriptionId:
              subscriptionData['subscriptionId'] ??
              subscriptionData['localSubscriptionId'] ??
              '',
          courseTitle: subscriptionData['courseTitle'] ?? _currentCourse.title,
          courseId: _currentCourse.id!,
          userEmail: _currentUserEmail,
          userContact: _currentUserPhone,
          onSuccess: (paymentResponse) async {
            debugPrint(
              'Razorpay EMI Subscription Success Response: $paymentResponse',
            );
            final paymentId =
                paymentResponse['razorpay_payment_id'] ??
                paymentResponse['payment_id'] ??
                paymentResponse['paymentId'] ??
                '';
            final signature =
                paymentResponse['razorpay_signature'] ??
                paymentResponse['signature'] ??
                '';
            final subId =
                paymentResponse['razorpay_subscription_id'] ??
                paymentResponse['subscription_id'] ??
                paymentResponse['subscriptionId'] ??
                subscriptionData['subscriptionId'] ??
                subscriptionData['localSubscriptionId'] ??
                '';

            await _verifySubscription(
              subscriptionId: subId,
              paymentId: paymentId,
              signature: signature,
            );
          },
          onError: (error) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          error,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            }
          },
        );
      }
    } on PaymentServiceException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to initiate EMI. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingPayment = false);
    }
  }

  Widget _buildModulesSection(bool isSmallScreen) {
    return Container(
      margin: EdgeInsets.only(top: isSmallScreen ? 6 : 8),
      padding: EdgeInsets.all(isSmallScreen ? 10 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.menu_book,
                  size: isSmallScreen ? 18 : 20,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Course Modules',
                style: TextStyle(
                  fontSize: isSmallScreen ? 17 : 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              if (_modules.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_modules.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (_isAdminOrOwner) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  TextButton.icon(
                    onPressed: _showAddModuleDialogForCourse,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text(
                      'Add Module',
                      style: TextStyle(fontSize: 13),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        PageTransition(
                          type: PageTransitionType.rightToLeft,
                          child: ModuleManagementScreen(course: _currentCourse),
                        ),
                      ).then((_) => _loadModules());
                    },
                    icon: const Icon(Icons.settings, size: 18),
                    label: const Text('Manage', style: TextStyle(fontSize: 13)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          
          // Search Bar
          if (_modules.isNotEmpty || _searchQuery.isNotEmpty) ...[
            TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search modules...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primaryColor),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (_isLoadingModules)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_errorMessage.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Icon(Icons.error_outline, color: Colors.red[700], size: 40),
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage,
                    style: TextStyle(
                      color: Colors.red[700],
                      fontSize: isSmallScreen ? 13 : 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _loadModules,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            )
          else if (_modules.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.book_outlined,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No modules available yet',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 15 : 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Modules will appear here once they are added',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 12 : 13,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_isAdminOrOwner) ...[
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          PageTransition(
                            type: PageTransitionType.rightToLeft,
                            child: ModuleManagementScreen(
                              course: _currentCourse,
                            ),
                          ),
                        ).then((_) => _loadModules());
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add First Module'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            )
          else ...() {
            final filteredModules = _modules.where((m) {
              return m.title.toLowerCase().contains(_searchQuery.toLowerCase());
            }).toList();

            if (filteredModules.isEmpty && _searchQuery.isNotEmpty) {
              return [
                Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  child: Text(
                    'No modules found matching "$_searchQuery"',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                )
              ];
            }

            return List.generate(filteredModules.length, (index) {
              return _buildModernModuleCard(
                filteredModules[index],
                index,
                isSmallScreen,
              );
            });
          }()
        ],
      ),
    );
  }

  // Build a stable identity key for a lesson to avoid showing duplicates
  String _getLessonIdentityKey(Lesson lesson) {
    final id = lesson.id ?? '';
    if (id.isNotEmpty) return 'id:$id';

    final url = lesson.contentUrl ?? '';
    if (url.isNotEmpty) return 'url:$url';

    // Fallback: use title + moduleId
    return 'title:${lesson.title}-module:${lesson.moduleId}';
  }

  Widget _buildModernModuleCard(Module module, int index, bool isSmallScreen) {
    final submodules = module.submodules ?? [];
    final hasSubmodules = submodules.isNotEmpty;

    // Track unique lessons across submodules and module to avoid duplicates
    final Set<String> lessonIdentitySet = {};

    int submoduleLessons = 0;
    for (final sm in submodules) {
      final lessons = sm.lessons ?? [];
      for (final lesson in lessons) {
        final key = _getLessonIdentityKey(lesson);
        if (lessonIdentitySet.add(key)) {
          submoduleLessons++;
        }
      }
    }

    // Module-level lessons (directly under module) that are NOT already counted from submodules
    final List<Lesson> filteredModuleLessons = (module.lessons ?? [])
        .where((lesson) => lessonIdentitySet.add(_getLessonIdentityKey(lesson)))
        .toList();

    final int moduleLessons = filteredModuleLessons.length;
    final int totalLessons = moduleLessons + submoduleLessons;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        // Subtle outer outline for the module card
        border: Border.all(color: AppTheme.primaryColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context),
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: module meta + counts
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: small badge with module number
                  Container(
                    width: isSmallScreen ? 30 : 34,
                    height: isSmallScreen ? 30 : 34,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        '${module.order}',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 13 : 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Middle: title + subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          module.title,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 15 : 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Module ${module.order}',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 11 : 12,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Right: quick chips (topics / lessons)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (hasSubmodules)
                        _buildModuleChip(
                          icon: Icons.topic,
                          label:
                              '${submodules.length} ${submodules.length == 1 ? 'topic' : 'topics'}',
                          isSmallScreen: isSmallScreen,
                        ),
                      if (totalLessons > 0) ...[
                        SizedBox(height: hasSubmodules ? 4 : 0),
                        _buildModuleChip(
                          icon: Icons.play_circle_outline,
                          label:
                              '$totalLessons ${totalLessons == 1 ? 'lesson' : 'lessons'}',
                          isSmallScreen: isSmallScreen,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Divider between header and content
              Divider(height: 1, color: Colors.grey[200]),
              const SizedBox(height: 4),
              // Actions row: view lessons (all roles, subscription-checked) + add sub-topic (admin/owner)
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => _checkSubscriptionAndNavigate(module),
                    icon: Icon(
                      Icons.play_circle_fill,
                      size: 18,
                      color: AppTheme.primaryColor,
                    ),
                    label: Text(
                      'View lessons',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 12 : 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 6 : 8,
                        vertical: 4,
                      ),
                      foregroundColor: AppTheme.primaryColor,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      minimumSize: Size.zero,
                    ),
                  ),
                  const Spacer(),
                  if (_isAdminOrOwner)
                    TextButton.icon(
                      onPressed: () => _showAddSubModuleDialog(module),
                      icon: Icon(
                        Icons.add_circle_outline,
                        size: 18,
                        color: Colors.green[700],
                      ),
                      label: Text(
                        'Add sub-topic',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 11 : 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.green[700],
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 6 : 8,
                          vertical: 4,
                        ),
                        foregroundColor: Colors.green[700],
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        minimumSize: Size.zero,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              // SubModules List
              if (hasSubmodules)
                ...SubModuleTreeBuilder.buildTree(submodules).map(
                  (submodule) => _buildSubModuleTile(
                    module,
                    submodule,
                    isSmallScreen,
                    depth: 0,
                  ),
                ),
              // Module-level lessons (lessons directly under module, not in submodules)
              if (moduleLessons > 0) ...[
                if (hasSubmodules) const SizedBox(height: 8),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.play_circle_outline,
                            size: 16,
                            color: Colors.blue[700],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Module Lessons',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 12 : 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[900],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ...filteredModuleLessons.map(
                        (lesson) => _buildLessonTile(lesson, isSmallScreen),
                      ),
                    ],
                  ),
                ),
              ],
              // Show message only if no submodules AND no module-level lessons
              if (!hasSubmodules && moduleLessons == 0)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'No sub-topics yet for this module.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAddSubModuleDialog(Module module) async {
    if (module.id == null) return;

    final titleController = TextEditingController();
    final orderController = TextEditingController(
      text: ((module.submodules?.length ?? 0) + 1).toString(),
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Add Sub-Topic',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Sub-Topic Title',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: orderController,
                decoration: const InputDecoration(
                  labelText: 'Order',
                  border: OutlineInputBorder(),
                  helperText: 'Sub-topic display order',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a sub-topic title'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              final order = int.tryParse(orderController.text);
              if (order == null || order < 1) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid order number'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true) {
      final order = int.parse(orderController.text);
      await _addSubModule(module, titleController.text.trim(), order);
    }
  }

  Future<void> _addSubModule(Module module, String title, int order) async {
    if (module.id == null) return;

    setState(() {
      _isLoadingModules = true;
      _errorMessage = '';
    });

    try {
      await ModuleService.createSubModule(
        moduleId: module.id!,
        title: title,
        order: order,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Sub-topic added successfully!'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );

      await _loadModules();
    } on ModuleServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingModules = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingModules = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to add sub-topic. Please try again.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ),
      );
    }
  }

  Widget _buildSubModuleTile(
    Module module,
    SubModule submodule,
    bool isSmallScreen, {
    int depth = 0,
  }) {
    final submoduleId = submodule.id ?? '';
    final isExpanded = _expandedSubModules[submoduleId] ?? false;
    final lessons = submodule.lessons ?? [];
    final hasLessons = lessons.isNotEmpty;
    final quiz = submodule.quiz;
    final hasQuiz = quiz != null;
    final hasChildSubModules =
        submodule.subModules != null && submodule.subModules!.isNotEmpty;
    // Check payment/subscription access
    final bool hasFullAccess =
        _isAdminOrOwner ||
        _currentCourse.isFree ||
        _currentCourse.isSubscribed == true;

    bool checkSubmoduleHasFreeLesson(SubModule sm) {
      if (sm.lessons?.any((l) => l.isFree) == true) return true;
      if (sm.subModules != null) {
        for (var child in sm.subModules!) {
          if (checkSubmoduleHasFreeLesson(child)) return true;
        }
      }
      return false;
    }

    final bool hasFreeLesson = checkSubmoduleHasFreeLesson(submodule);
    final bool canAccessSubModule = hasFullAccess || hasFreeLesson;

    return Container(
      margin: EdgeInsets.only(
        left: depth == 0 ? 8.0 : 0.0,
        right: depth == 0 ? 8.0 : 0.0,
        top: 2.0,
        bottom: 2.0,
      ),
      decoration: depth == 0
          ? BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!, width: 1),
            )
          : null,
      child: Column(
        children: [
          // SubModule Header
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: hasLessons || hasQuiz || hasChildSubModules
                  ? () {
                      // Check payment/subscription before allowing expansion
                      if (canAccessSubModule) {
                        // User has access, allow expand/collapse
                        setState(() {
                          _expandedSubModules[submoduleId] = !isExpanded;
                        });
                      } else if (_isStudent) {
                        // Student without payment - show warning
                        _showSubscriptionWarning();
                      }
                      // For other roles without access, do nothing
                    }
                  : null,
              child: Padding(
                padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.topic,
                        size: 18,
                        color: Colors.blue[700],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            submodule.title,
                            style: TextStyle(
                              fontSize: isSmallScreen ? 14 : 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              if (hasChildSubModules)
                                Text(
                                  '${submodule.subModules!.length} ${submodule.subModules!.length == 1 ? 'folder' : 'folders'}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              if (hasLessons)
                                Text(
                                  '${lessons.length} ${lessons.length == 1 ? 'lesson' : 'lessons'}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              if (hasQuiz)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.quiz,
                                      size: 14,
                                      color: Colors.orange[700],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${quiz.totalQuestions} ${quiz.totalQuestions == 1 ? 'question' : 'questions'}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.orange[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (hasLessons || hasQuiz || hasChildSubModules) ...[
                      // Show lock icon if student doesn't have access
                      Builder(
                        builder: (context) {
                          if (_isStudent && !canAccessSubModule) {
                            return Icon(
                              Icons.lock_outline,
                              color: Colors.grey[400],
                              size: 18,
                            );
                          }
                          return Icon(
                            isExpanded ? Icons.expand_less : Icons.expand_more,
                            color: Colors.blue[700],
                            size: 20,
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          // Lessons and Quiz List (when expanded)
          if (isExpanded && canAccessSubModule)
            Container(
              margin: const EdgeInsets.only(left: 24.0, top: 4.0, bottom: 8.0),
              padding: const EdgeInsets.only(left: 8.0),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: Colors.blue[300]!, width: 2.0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Nested SubModules
                  if (submodule.subModules != null &&
                      submodule.subModules!.isNotEmpty)
                    ...submodule.subModules!.map(
                      (child) => _buildSubModuleTile(
                        module,
                        child,
                        isSmallScreen,
                        depth: depth + 1,
                      ),
                    ),
                  // Quiz Section
                  if (hasQuiz) _buildQuizTile(quiz, isSmallScreen),
                  // Lessons List
                  if (hasLessons)
                    ...lessons.map(
                      (lesson) => _buildLessonTile(
                        lesson,
                        isSmallScreen,
                        depth: depth + 1,
                      ),
                    ),
                ],
              ),
            ),
          // Show access denied message if student tries to view without subscription
          if (isExpanded && !hasFullAccess && _isStudent)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.lock_outline, size: 32, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      'Payment required to view content',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLessonTile(Lesson lesson, bool isSmallScreen, {int depth = 0}) {
    // Access rules:
    // - Admin/Owner: always unlocked and navigable
    // - Students: unlocked if course is free OR course.isSubscribed == true OR lesson.isFree
    final bool hasFullAccess =
        _isAdminOrOwner ||
        _currentCourse.isFree ||
        _currentCourse.isSubscribed == true;
    final bool canAccessLesson = hasFullAccess || lesson.isFree;
    return Container(
      margin: EdgeInsets.only(
        left: depth == 0 ? 8.0 : 0.0,
        right: depth == 0 ? 8.0 : 0.0,
        top: 4.0,
        bottom: 4.0,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: ListTile(
        dense: true,
        contentPadding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 12 : 16,
          vertical: 4,
        ),
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: lesson.type == 'video'
                    ? Colors.red.withValues(alpha: 0.1)
                    : Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                lesson.type == 'video'
                    ? Icons.play_circle_outline
                    : Icons.picture_as_pdf,
                size: 18,
                color: lesson.type == 'video' ? Colors.red[700] : Colors.blue[700],
              ),
            ),
            if (lesson.isFree) ...[
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'FREE',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            ],
          ],
        ),
        title: Text(
          lesson.title,
          style: TextStyle(
            fontSize: isSmallScreen ? 13 : 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: lesson.duration.isNotEmpty
            ? Row(
                children: [
                  Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    lesson.duration,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              )
            : null,
        trailing: Icon(
          canAccessLesson ? Icons.lock_open_rounded : Icons.lock_outline,
          size: 18,
          color: canAccessLesson ? AppTheme.primaryColor : Colors.grey[400],
        ),
        onTap: () {
          if (canAccessLesson) {
            Navigator.push(
              context,
              PageTransition(
                type: PageTransitionType.rightToLeft,
                child: LessonDetailScreen(lesson: lesson),
              ),
            );
          } else if (_isStudent) {
            _showSubscriptionWarning();
          }
        },
      ),
    );
  }

  Widget _buildQuizTile(Quiz quiz, bool isSmallScreen) {
    // Access rules: same as lessons
    // Students can only view quiz questions if:
    // 1. They are admin/owner (always allowed)
    // 2. Course is free
    // 3. Student is subscribed/enrolled (isSubscribed == true)
    final bool hasFullAccess =
        _isAdminOrOwner ||
        _currentCourse.isFree ||
        _currentCourse.isSubscribed == true;
    final bool canAccessQuiz = hasFullAccess;

    final quizId = quiz.id ?? '';
    final isExpanded = _expandedQuizzes[quizId] ?? false;
    final questions = quiz.questions;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange[200]!, width: 1),
      ),
      child: Column(
        children: [
          // Quiz Header
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                // Check access before allowing expansion
                if (canAccessQuiz) {
                  // User has access, allow expand/collapse
                  setState(() {
                    _expandedQuizzes[quizId] = !isExpanded;
                  });
                } else if (_isStudent) {
                  // Student without access - show payment/subscription warning
                  _showSubscriptionWarning();
                }
                // For other roles without access, do nothing
              },
              child: Padding(
                padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.quiz,
                        size: 22,
                        color: Colors.orange[700],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            quiz.title,
                            style: TextStyle(
                              fontSize: isSmallScreen ? 14 : 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange[100],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.help_outline,
                                      size: 14,
                                      color: Colors.orange[800],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${quiz.totalQuestions} ${quiz.totalQuestions == 1 ? 'Question' : 'Questions'}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.orange[800],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange[100],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.star,
                                      size: 14,
                                      color: Colors.orange[800],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${quiz.totalMarks} Marks',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.orange[800],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      canAccessQuiz
                          ? (isExpanded ? Icons.expand_less : Icons.expand_more)
                          : Icons.lock_outline,
                      size: 18,
                      color: canAccessQuiz
                          ? Colors.orange[700]
                          : Colors.grey[400],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Questions List (when expanded)
          // Only show questions if:
          // 1. Quiz is expanded
          // 2. User has access (canAccessQuiz)
          // 3. Questions exist
          if (isExpanded && canAccessQuiz && questions.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(
                isSmallScreen ? 12 : 16,
                0,
                isSmallScreen ? 12 : 16,
                isSmallScreen ? 12 : 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  ...questions.asMap().entries.map((entry) {
                    final index = entry.key;
                    final question = entry.value;
                    return _buildQuestionCard(
                      question,
                      index + 1,
                      isSmallScreen,
                    );
                  }),
                ],
              ),
            ),
          // Show access denied message if student tries to view without subscription
          if (isExpanded && !canAccessQuiz && _isStudent)
            Padding(
              padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange[200]!, width: 1),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 32,
                      color: Colors.orange[700],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Subscribe to view quiz questions',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 13 : 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Please enroll in this course to access quiz questions and answers.',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 11 : 12,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(
    Question question,
    int questionNumber,
    bool isSmallScreen,
  ) {
    final questionText = question.questionText;
    final options = question.options;
    final correctOption = question.correctOption;
    final marks = question.marks;

    // Ensure correctOption is within valid range
    final validCorrectOption =
        correctOption >= 0 && correctOption < options.length
        ? correctOption
        : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange[200]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '$questionNumber',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[800],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      questionText,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$marks ${marks == 1 ? 'mark' : 'marks'}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Options
          if (options.isNotEmpty)
            ...options.asMap().entries.map((entry) {
              final optionIndex = entry.key;
              final optionText = entry.value;
              final isCorrect = optionIndex == validCorrectOption;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isCorrect ? Colors.green[50] : Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isCorrect ? Colors.green[300]! : Colors.grey[300]!,
                    width: isCorrect ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isCorrect ? Colors.green[200] : Colors.grey[300],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          String.fromCharCode(65 + optionIndex), // A, B, C, D
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isCorrect
                                ? Colors.green[800]
                                : Colors.grey[700],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        optionText,
                        style: TextStyle(
                          fontSize: isSmallScreen ? 13 : 14,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    if (isCorrect)
                      Icon(
                        Icons.check_circle,
                        size: 18,
                        color: Colors.green[700],
                      ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildLiveMeetingsSection(bool isSmallScreen) {
    final liveMeetings = _currentCourse.liveMeetings ?? [];
    if (liveMeetings.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.video_call,
                    size: isSmallScreen ? 18 : 20,
                    color: Colors.red[700],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Live Meetings',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 17 : 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red[700],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${liveMeetings.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Meetings List
          Padding(
            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
            child: Column(
              children: liveMeetings
                  .map(
                    (meeting) => _buildLiveMeetingCard(meeting, isSmallScreen),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveMeetingCard(
    Map<String, dynamic> meeting,
    bool isSmallScreen,
  ) {
    final className = meeting['className'] ?? 'Untitled Meeting';
    final dateStr = meeting['date'];
    final startTime = meeting['startTime'] ?? '';
    final endTime = meeting['endTime'] ?? '';
    final duration = meeting['duration'] ?? 0;
    final status = meeting['status'] ?? 'Upcoming';
    final meetingUrl = meeting['meetingUrl'];
    final students = meeting['students'] as List? ?? [];

    // Parse date
    DateTime? meetingDate;
    String formattedDate = 'Date not set';
    if (dateStr != null) {
      try {
        meetingDate = DateTime.parse(dateStr);
        final now = DateTime.now();
        final difference = meetingDate.difference(now);

        if (difference.inDays == 0) {
          formattedDate = 'Today';
        } else if (difference.inDays == 1) {
          formattedDate = 'Tomorrow';
        } else if (difference.inDays > 1 && difference.inDays < 7) {
          final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
          formattedDate = weekdays[meetingDate.weekday - 1];
        } else {
          formattedDate =
              '${meetingDate.day}/${meetingDate.month}/${meetingDate.year}';
        }
      } catch (e) {
        formattedDate = dateStr.toString();
      }
    }

    // Determine status color
    Color statusColor;
    IconData statusIcon;
    String statusText = status.toString();

    switch (status.toString().toLowerCase()) {
      case 'upcoming':
        statusColor = Colors.blue;
        statusIcon = Icons.schedule;
        statusText = 'Upcoming';
        break;
      case 'live':
      case 'in_progress':
        statusColor = Colors.red;
        statusIcon = Icons.circle;
        statusText = 'Live Now';
        break;
      case 'completed':
      case 'ended':
        statusColor = Colors.grey;
        statusIcon = Icons.check_circle;
        statusText = 'Completed';
        break;
      case 'cancelled':
        statusColor = Colors.orange;
        statusIcon = Icons.cancel;
        statusText = 'Cancelled';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.info;
        statusText = status.toString();
    }

    final bool isLive = statusText == 'Live Now';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isLive ? Colors.red[50] : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLive ? Colors.red[200]! : Colors.grey[200]!,
          width: isLive ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: meetingUrl != null && meetingUrl.toString().isNotEmpty
              ? () {
                  // TODO: Navigate to meeting or open URL
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Opening meeting: $className'),
                      backgroundColor: AppTheme.primaryColor,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
              : null,
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row: Title and Status
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            className,
                            style: TextStyle(
                              fontSize: isSmallScreen ? 15 : 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          // Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: statusColor.withValues(alpha: 0.4),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusIcon, size: 14, color: statusColor),
                                const SizedBox(width: 4),
                                Text(
                                  statusText,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: statusColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isLive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.circle, size: 8, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'LIVE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // Details Row
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    // Date
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          formattedDate,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    // Time
                    if (startTime.isNotEmpty && endTime.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$startTime - $endTime',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    // Duration
                    if (duration > 0)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.timer, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            '$duration min',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    // Students Count
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '${students.length} ${students.length == 1 ? 'student' : 'students'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Meeting URL indicator
                if (meetingUrl != null && meetingUrl.toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.video_call,
                        size: 14,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Meeting link available',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 12,
                        color: AppTheme.primaryColor,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatExpiryDate(DateTime date) {
    try {
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return date.toString();
    }
  }

  Widget _buildEnrolledStatusCard(bool isSmallScreen) {
    if (_currentCourse.subscriptionDetails != null) {
      return _buildSubscriptionDetailsCard(isSmallScreen);
    }

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 14 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[50]!, Colors.green[100]!],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green[300]!, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green[600],
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enrolled Successfully',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                Text(
                  'You have full access to this course.',
                  style: TextStyle(fontSize: 12, color: Colors.green[800]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
