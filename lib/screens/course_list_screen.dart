import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meeting_app/screens/student_notifications_screen.dart';
import 'package:page_transition/page_transition.dart';
import '../services/course_service.dart';
import '../services/payment_service.dart';
import '../models/course.dart';
import '../widgets/app_drawer.dart';
import '../widgets/app_network_image.dart';
import '../widgets/skeleton_loader.dart';
import '../services/storage_service.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import 'create_course_screen.dart';
import 'course_detail_screen.dart';

class CourseListScreen extends StatefulWidget {
  const CourseListScreen({super.key});

  @override
  State<CourseListScreen> createState() => _CourseListScreenState();
}

class _CourseListScreenState extends State<CourseListScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  List<Course> _courses = [];
  List<Map<String, dynamic>> _paymentHistory = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  final ScrollController _scrollController = ScrollController();
  String _errorMessage = '';
  String? _userRole;
  String? _selectedCategory; // null means "All"
  TabController? _tabController;
  int _selectedTabIndex =
      0; // 0 = Free Course, 1 = Paid Course, 2 = My Course (for students)

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initializeRoleAndTabs();
    _loadCourses();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMoreCourses();
    }
  }

  Future<void> _initializeRoleAndTabs() async {
    await _loadUserRole();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserRole() async {
    final role = await StorageService.getRole();
    if (mounted) {
      final isStudent =
          role?.toLowerCase() == 'student' || role?.toLowerCase() == 'user';

      // Initialize tab controller based on role (only once)
      if (_tabController == null) {
        final tabLength =
            isStudent ? 3 : 1; // 3 tabs for students: Free, Paid, My Course
        _tabController = TabController(
          length: tabLength,
          vsync: this,
          initialIndex: 0,
        );
        _tabController!.addListener(() {
          if (_tabController!.indexIsChanging) {
            setState(() {
              _selectedTabIndex = _tabController!.index;
              _selectedCategory = null; // Reset category filter when switching tabs
            });
          }
        });
      }

      setState(() {
        _userRole = role;
      });

      if (isStudent) {
        await _loadPaymentHistory();
      }
    }
  }

  Future<void> _loadPaymentHistory() async {
    final isStudent = _userRole?.toLowerCase() == 'student' ||
        _userRole?.toLowerCase() == 'user';
    if (!isStudent) return;


    try {
      final payments = await PaymentService.getPaymentHistory();
      if (mounted) {
        setState(() {
          _paymentHistory = payments;
        });
        debugPrint('Payment history loaded: ${payments.length} items');
        for (var payment in payments) {
          debugPrint('Payment: ${payment.toString()}');
        }
      }
    } catch (e) {
      if (mounted) {
        debugPrint('Error loading payment history: $e');
      }
    }
  }

  Future<void> _loadCourses({bool refresh = true}) async {
    if (refresh) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
        _currentPage = 1;
        _hasMore = true;
      });
    }

    try {
      final response = await CourseService.getPaginatedCourses(
        page: _currentPage,
        limit: 20,
      );

      if (!mounted) return;

      setState(() {
        if (refresh) {
          _courses = response['courses'] as List<Course>;
        } else {
          _courses.addAll(response['courses'] as List<Course>);
        }
        _hasMore = _currentPage < (response['totalPages'] as int);
        _isLoading = false;
      });
    } on CourseServiceException catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'An unexpected error occurred. Please try again.';
      });
    }
  }

  Future<void> _loadMoreCourses() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    _currentPage++;
    await _loadCourses(refresh: false);

    if (mounted) {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _navigateToCreateCourse() async {
    final result = await Navigator.push(
      context,
      PageTransition(
        type: PageTransitionType.rightToLeft,
        child: const CreateCourseScreen(),
      ),
    );

    if (result == true) {
      _loadCourses();
      if (mounted) Provider.of<AppProvider>(context, listen: false).loadAllData();
    }
  }

  Future<void> _navigateToEditCourse(Course course) async {
    final result = await Navigator.push(
      context,
      PageTransition(
        type: PageTransitionType.rightToLeft,
        child: CreateCourseScreen(course: course),
      ),
    );

    if (result == true) {
      _loadCourses();
      if (mounted) Provider.of<AppProvider>(context, listen: false).loadAllData();
    }
  }

  Future<void> _deleteCourse(Course course) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Course'),
        content: Text(
            'Are you sure you want to delete "${course.title}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await CourseService.deleteCourse(course.id!);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Course deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );

      _loadCourses();
      if (mounted) Provider.of<AppProvider>(context, listen: false).loadAllData();
    } on CourseServiceException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Get unique categories from filtered courses (based on selected tab)
  List<String> get _categories {
    // Get courses based on selected tab for students
    List<Course> coursesForCategories = _courses;
    final isStudent = _userRole?.toLowerCase() == 'student' ||
        _userRole?.toLowerCase() == 'user';

    if (isStudent) {
      if (_selectedTabIndex == 0) {
        // Free Course tab - only free courses
        coursesForCategories = _courses.where((c) => c.isFree).toList();
      } else if (_selectedTabIndex == 1) {
        // Paid Course tab - only paid courses
        coursesForCategories = _courses.where((c) => !c.isFree).toList();
        // My Course tab - only enrolled courses
        coursesForCategories = _myEnrolledCourses;
      }
    }

    final categories =
        coursesForCategories.map((course) => course.category).toSet().toList();
    categories.sort();
    return categories;
  }

  List<Course> get _myEnrolledCourses {
    List<Course> enrolled = [];
    final successfulPayments = _paymentHistory.where((payment) {
      final status = payment['status']?.toString().toLowerCase() ?? '';
      return status == 'success' || status == 'active' || status == 'captured';
    }).toList();

    if (successfulPayments.isEmpty) return enrolled;

    final paidCourseIds = <String>{};
    final paidCourseData = <Map<String, String>>[];

    for (var payment in successfulPayments) {
      final courseId = payment['courseId']?.toString() ?? '';
      if (courseId.isNotEmpty) paidCourseIds.add(courseId);

      final courseTitle = payment['courseTitle']?.toString().trim() ?? '';
      final courseThumbnail = payment['courseThumbnail']?.toString() ?? '';

      if (courseTitle.isNotEmpty) {
        paidCourseData.add({
          'title': courseTitle.toLowerCase().trim(),
          'thumbnail': courseThumbnail,
        });
      }
    }

    final matchedByCourseId = <String>{};
    enrolled = _courses.where((course) {
      if (course.id != null && paidCourseIds.contains(course.id)) {
        matchedByCourseId.add(course.id!);
        return true;
      }
      return false;
    }).toList();

    final matchedTitles = <String>{};
    for (var paymentData in paidCourseData) {
      final paymentTitle = paymentData['title']!;
      final paymentThumbnail = paymentData['thumbnail'] ?? '';

      final matchingCourses = _courses.where((course) {
        if (course.id != null && matchedByCourseId.contains(course.id!)) return false;

        final courseTitleLower = course.title.toLowerCase().trim();
        if (courseTitleLower == paymentTitle) {
          if (paymentThumbnail.isNotEmpty && course.thumbnail != null) {
            return course.thumbnail == paymentThumbnail;
          }
          return true;
        }
        return false;
      }).toList();

      if (matchingCourses.isNotEmpty && !matchedTitles.contains(paymentTitle)) {
        enrolled.add(matchingCourses.first);
        matchedTitles.add(paymentTitle);
      }
    }
    return enrolled;
  }

  List<Course> get _filteredCourses {
    var filtered = _courses;

    // For students, filter by selected tab
    final isStudent = _userRole?.toLowerCase() == 'student' ||
        _userRole?.toLowerCase() == 'user';

    if (isStudent) {
      if (_selectedTabIndex == 0) {
        // Free Course tab - only free courses
        filtered = _courses.where((c) => c.isFree).toList();
      } else if (_selectedTabIndex == 1) {
        // Paid Course tab - only paid courses
        filtered = _courses.where((c) => !c.isFree).toList();
      } else if (_selectedTabIndex == 2) {
        filtered = _myEnrolledCourses;
      }
    }

    // Filter by selected category
    if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
      filtered = filtered
          .where((course) => course.category == _selectedCategory)
          .toList();
    }

    // Filter by search query
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((course) {
        return course.title.toLowerCase().contains(query) ||
            course.description.toLowerCase().contains(query) ||
            course.category.toLowerCase().contains(query);
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _userRole?.toLowerCase() == 'admin' ||
        _userRole?.toLowerCase() == 'owner';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      drawer: const AppDrawer(),
      floatingActionButton: (isAdmin)
          ? FloatingActionButton.extended(
              onPressed: _navigateToCreateCourse,
              backgroundColor: const Color(0xFF5a189a),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Create Course',
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : null,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              height: 60,
              color: const Color(0xFF5a189a),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(Icons.menu, color: Colors.white),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 40),
                      onPressed: () {
                        Scaffold.of(context).openDrawer();
                      },
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Aadvi fashion institute',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.notifications, color: Colors.white),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 40),
                    onPressed: () {
                      Navigator.push(
                        context,
                        PageTransition(
                          type: PageTransitionType.rightToLeft,
                          child: const StudentNotificationsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Search Bar
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white,
                    Colors.grey.shade50,
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.15),
                    blurRadius: 10,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: "Search courses...",
                  hintStyle: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 14,
                  ),
                  prefixIcon: Container(
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      Icons.search,
                      color: Colors.deepPurple.shade400,
                      size: 22,
                    ),
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.transparent,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Colors.deepPurple,
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),

            // Tabs (only for students)
            Builder(
              builder: (context) {
                final isStudent = _userRole?.toLowerCase() == 'student' ||
                    _userRole?.toLowerCase() == 'user';
                if (isStudent &&
                    _tabController != null &&
                    _tabController!.length == 3) {
                  return Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TabBar(
                      controller: _tabController!,
                      onTap: (index) {
                        setState(() {
                          _selectedTabIndex = index;
                        });
                      },
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        color: const Color(0xFF5a189a),
                      ),
                      // indicatorPadding: const EdgeInsets.symmetric(
                      //     horizontal: 4, vertical: 4),
                      // labelPadding: const EdgeInsets.symmetric(
                      //     horizontal: 16, vertical: 4),
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.grey[700],
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                      tabs: [
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.free_breakfast, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Free Course (${_courses.where((c) => c.isFree).length})',
                              ),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.payment, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Paid Course (${_courses.where((c) => !c.isFree).length})',
                              ),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.shopping_bag, size: 18),
                              const SizedBox(width: 8),
                                Text(
                                  'My Course (${_myEnrolledCourses.length})',
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            // Subcategories Section
            if (_categories.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Categories',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildCategoryChip('All', null),
                          const SizedBox(width: 8),
                          ..._categories.map((category) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _buildCategoryChip(category, category),
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Courses List
            Expanded(
              child: _isLoading && _courses.isEmpty
                  ? ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                      itemCount: 5,
                      itemBuilder: (context, index) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SkeletonLoader(
                                width: 100,
                                height: 100,
                                borderRadius:
                                    BorderRadius.all(Radius.circular(8)),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SkeletonBox(height: 14, width: 60),
                                      const SizedBox(height: 8),
                                      const SkeletonBox(height: 16, width: 200),
                                      const SizedBox(height: 8),
                                      const SkeletonBox(height: 12, width: 100),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    )
                  : _errorMessage.isNotEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline,
                                  size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                _errorMessage,
                                style: TextStyle(color: Colors.grey[600]),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadCourses,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : _filteredCourses.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.book_outlined,
                                      size: 64, color: Colors.grey[400]),
                                  const SizedBox(height: 16),
                                  Text(
                                    _searchController.text.isEmpty
                                        ? 'No courses available'
                                        : 'No courses match your search',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (_searchController.text.isEmpty &&
                                      isAdmin) ...[
                                    const SizedBox(height: 24),
                                    ElevatedButton.icon(
                                      onPressed: _navigateToCreateCourse,
                                      icon: const Icon(Icons.add),
                                      label: const Text('Create First Course'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF5a189a),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Courses (${_filteredCourses.length})',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (isAdmin)
                                        IconButton(
                                          icon: const Icon(Icons.add_circle),
                                          color: const Color(0xFF5a189a),
                                          onPressed: _navigateToCreateCourse,
                                          tooltip: 'Create Course',
                                        ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: RefreshIndicator(
                                    onRefresh: () => _loadCourses(refresh: true),
                                    child: ListView.builder(
                                      controller: _scrollController,
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        0,
                                        16,
                                        70,
                                      ),
                                      itemCount: _filteredCourses.length + (_isLoadingMore ? 1 : 0),
                                      itemBuilder: (context, index) {
                                        if (index == _filteredCourses.length) {
                                          return const Padding(
                                            padding: EdgeInsets.symmetric(vertical: 16.0),
                                            child: Center(child: CircularProgressIndicator()),
                                          );
                                        }
                                        final course = _filteredCourses[index];
                                        return RepaintBoundary(
                                          child: _buildCourseCard(course),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label, String? category) {
    final isSelected = _selectedCategory == category;
    // Count based on filtered courses (respects tab selection)
    final count = category == null
        ? 0 // hide count on "All" to avoid redundancy
        : _filteredCourses.where((c) => c.category == category).length;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = category;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF5a189a) : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? null : Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.3)
                      : Colors.grey[400],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCourseCard(Course course) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            final result = await Navigator.push(
              context,
              PageTransition(
                type: PageTransitionType.rightToLeft,
                child: CourseDetailScreen(course: course),
              ),
            );

            // Refresh payment history if enrollment/payment was successful
            if (result == true) {
              final isStudent = _userRole?.toLowerCase() == 'student' ||
                  _userRole?.toLowerCase() == 'user';
              if (isStudent) {
                await _loadPaymentHistory();
                setState(() {}); // Refresh UI to show updated courses
              }
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail
                Container(
                  constraints: const BoxConstraints(
                      minWidth: 90,
                      minHeight: 90,
                      maxWidth: 110,
                      maxHeight: 110),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Stack(
                    children: [
                      AppNetworkImage(
                        imageUrl: course.thumbnail,
                        width: double.infinity,
                        height: double.infinity,
                        borderRadius: BorderRadius.circular(8),
                        errorIcon: Icons.book,
                      ),
                      if (course.isLiveCourse)
                        Positioned(
                          top: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'LIVE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tags
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: course.isFree
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              course.isFree ? 'FREE' : 'PAID',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: course.isFree
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              course.category.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                          if (course.discount != null && course.discount! > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.purple.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${(course.discount! > 100 ? 100 : course.discount!).toStringAsFixed(0)}% OFF',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Title
                      Text(
                        course.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // Price and Duration (hide price for free courses)
                      Row(
                        children: [
                          // Only show price for paid courses
                          if (!course.isFree) ...[
                            () {
                              double finalPrice = course.discount != null && course.discount! > 0
                                  ? course.price * (1 - course.discount! / 100)
                                  : course.price;
                              if (finalPrice < 0) finalPrice = 0;
                              return Flexible(
                                child: Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 4,
                                  children: [
                                    Text(
                                      '₹${finalPrice.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                    if (course.discount != null && course.discount! > 0)
                                      Text(
                                        '₹${course.price.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          decoration: TextDecoration.lineThrough,
                                          color: Colors.grey[500],
                                          fontWeight: FontWeight.normal,
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }(),
                            const SizedBox(width: 8),
                          ],
                          // Duration (always shown)
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              course.duration,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Payment Options
                      if (course.hasPaymentOptions || course.isRecurring)
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            if (course.isRecurring)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                                ),
                                child: const Text(
                                  'RENEWAL',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            if (course.supportsEMI)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'EMI',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            if (course.supportsFullPayment && !course.isRecurring)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'FULL',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.purple,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
                // Menu button for admin
                if (_userRole?.toLowerCase() == 'admin' ||
                    _userRole?.toLowerCase() == 'owner')
                  PopupMenuButton(
                    icon: const Icon(Icons.more_vert, size: 20),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'edit') {
                        _navigateToEditCourse(course);
                      } else if (value == 'delete') {
                        _deleteCourse(course);
                      }
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
