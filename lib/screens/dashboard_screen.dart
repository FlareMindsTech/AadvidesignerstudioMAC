import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meeting_app/screens/student_notifications_screen.dart';
import 'package:provider/provider.dart';
import 'package:page_transition/page_transition.dart';
import '../providers/app_provider.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../widgets/app_network_image.dart';
import '../widgets/app_drawer.dart';
import '../widgets/skeleton_loader.dart';
import '../models/course.dart';
import 'package:url_launcher/url_launcher.dart';
import 'course_detail_screen.dart';
import 'package:meeting_app/models/user.dart' as model;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {

  String? _userRole;
  final PageController _bannerPageController = PageController();
  Timer? _bannerTimer;
  int _currentBannerIndex = 0;
  String? _selectedCategory; // null means "All"

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Run all critical data fetching in parallel
        context.read<AppProvider>().loadAllData();
        _loadUserInfo();
        _startBannerAutoScroll();
      }
    });
  }

  void _startBannerAutoScroll() {
    _bannerTimer?.cancel();
    _bannerTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_bannerPageController.hasClients && mounted) {
        final provider = context.read<AppProvider>();
        final filteredCourses = _getFilteredCourses(provider.courses);
        final courses = filteredCourses.take(3).toList();
        if (courses.length > 1) {
          final nextIndex = (_currentBannerIndex + 1) % courses.length;
          _bannerPageController.animateToPage(
            nextIndex,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerPageController.dispose();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    // parallel fetch
    final results = await Future.wait([
      AuthService.getCurrentUser(),
      StorageService.getRole(),
    ]);

    final user = results[0] as model.User?;
    final role = results[1] as String?;

    if (user != null && mounted) {
      setState(() {
        _userRole = (user.role.isNotEmpty ? user.role : role ?? '')
            .toLowerCase()
            .trim();
      });
    }
  }

  bool _shouldShowPayButton() {
    // If role is not loaded yet, don't show button (safer default)
    if (_userRole == null || _userRole!.isEmpty) return false;

    // Hide button for admin and owner roles (case-insensitive check)
    final role = _userRole!.toLowerCase().trim();
    return role != 'admin' && role != 'owner';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      drawer: const AppDrawer(),
      body: Column(
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
          // Main Content
          Expanded(
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Promotional Banner
                    _buildPromotionalBanner(),

                    // Subcategories Section
                    _buildSubcategoriesSection(),

                    // Popular Meetings Section
                    _buildPopularMeetingsSection(),

                    // Recently Added Meetings Section
                    _buildRecentlyAddedMeetingsSection(),

                    // Share Your Experience Section
                    _buildShareExperienceSection(),

                    // Connect With Us Section
                    _buildConnectWithUsSection(),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromotionalBanner() {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        if (provider.courses.isEmpty) {
          return const SizedBox.shrink();
        }

        final filteredCourses = _getFilteredCourses(provider.courses);
        if (filteredCourses.isEmpty) {
          return const SizedBox.shrink();
        }

        final courses = filteredCourses.take(3).toList();

        return Column(
          children: [
            /// Banner Carousel
            LayoutBuilder(
              builder: (context, constraints) {
                // Increase height to allow larger text without scaling
                final bool showPayButton = _shouldShowPayButton();
                final double bannerHeight =
                    constraints.maxWidth * (showPayButton ? 0.75 : 0.65);

                return SizedBox(
                  height: bannerHeight,
                  child: PageView.builder(
                    controller: _bannerPageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentBannerIndex = index;
                      });
                      _startBannerAutoScroll();
                    },
                    itemCount: courses.length,
                    itemBuilder: (context, index) {
                      final course = courses[index];
                      double finalPrice = course.discount != null && course.discount! > 0
                          ? course.price * (1 - course.discount! / 100)
                          : course.price;
                      if (finalPrice < 0) finalPrice = 0;

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            PageTransition(
                              type: PageTransitionType.rightToLeft,
                              child: CourseDetailScreen(course: course),
                            ),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              /// TAGS
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  if (course.isFree)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text('FREE CONTENT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text('PAID', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange)),
                                    ),
                                  if (course.discount != null && course.discount! > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.purple.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text('${(course.discount! > 100 ? 100 : course.discount!).toStringAsFixed(0)}% OFF', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purple)),
                                    ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              /// IMAGE + CONTENT
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  /// IMAGE
                                  Container(
                                    width: 100,
                                    height: 90,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black12,
                                          blurRadius: 4,
                                          offset: Offset(0, 2),
                                        )
                                      ],
                                    ),
                                    child: AppNetworkImage(
                                      imageUrl: course.thumbnail,
                                      width: 100,
                                      height: 90,
                                      borderRadius: BorderRadius.circular(8),
                                      errorIcon: Icons.book,
                                    ),
                                  ),

                                  const SizedBox(width: 14),

                                  /// DETAILS
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          course.title,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 10),
                                        Wrap(
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          spacing: 8,
                                          children: [
                                            Text(
                                              course.isFree
                                                  ? 'FREE'
                                                  : '₹${finalPrice.toStringAsFixed(0)}',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: course.isFree
                                                    ? Colors.green
                                                    : Colors.black87,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (!course.isFree && course.discount != null && course.discount! > 0)
                                              Text(
                                                '₹${course.price.toStringAsFixed(0)}',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  decoration: TextDecoration.lineThrough,
                                                  color: Colors.grey[500],
                                                  fontWeight: FontWeight.normal,
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Icon(Icons.category_outlined,
                                                size: 14,
                                                color: Colors.grey[600]),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                course.category.isNotEmpty
                                                    ? course.category
                                                    : 'General',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey[700],
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              /// BUTTON
                              if (_shouldShowPayButton())
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        PageTransition(
                                          type: PageTransitionType.rightToLeft,
                                          child: CourseDetailScreen(
                                              course: course),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF5a189a),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: const Text(
                                      'Buy Now',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),

            /// DOT INDICATORS
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                courses.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentBannerIndex == index
                        ? Colors.grey[700]
                        : Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSubcategoriesSection() {
    return Consumer<AppProvider>(
      builder: (context, provider, child) {
        // Get unique categories from courses
        final categories =
            provider.courses.map((course) => course.category).toSet().toList();
        categories.sort();

        if (categories.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Course Categories',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildCategoryChip('All', null, provider.courses.length),
                    const SizedBox(width: 8),
                    ...categories.map((category) {
                      final count = provider.courses
                          .where((c) => c.category == category)
                          .length;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _buildCategoryChip(category, category, count),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryChip(String label, String? category, int count) {
    final isSelected = _selectedCategory == category;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = category;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
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
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.3)
                      : Colors.grey[400],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 14,
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

  // Get filtered courses based on selected category
  List<Course> _getFilteredCourses(List<Course> courses) {
    if (_selectedCategory == null || _selectedCategory!.isEmpty) {
      return courses;
    }
    return courses
        .where((course) => course.category == _selectedCategory)
        .toList();
  }

  // Widget _buildPopularMeetingsSection() {
  //   return Padding(
  //     padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Row(
  //           mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //           children: [
  //             const Text(
  //               'Popular Courses',
  //               style: TextStyle(
  //                 fontSize: 20,
  //                 fontWeight: FontWeight.bold,
  //               ),
  //             ),
  //             TextButton(
  //               onPressed: () {
  //                 // Navigate to course list
  //                 context.read<AppProvider>().setSelectedIndex(1);
  //               },
  //               child: const Text(
  //                 'See All →',
  //                 style: TextStyle(
  //                   color: Color(0xFF5a189a),
  //                   fontWeight: FontWeight.w600,
  //                 ),
  //               ),
  //             ),
  //           ],
  //         ),
  //         const SizedBox(height: 12),
  //         ConstrainedBox(
  //           constraints: const BoxConstraints(minHeight: 180, maxHeight: 320),
  //           child: Consumer<AppProvider>(
  //             builder: (context, provider, child) {
  //               if (provider.isLoadingCourses) {
  //                 return SizedBox(
  //                   height: 180,
  //                   child: ListView.builder(
  //                     scrollDirection: Axis.horizontal,
  //                     itemCount: 3,
  //                     itemBuilder: (context, index) {
  //                       return Container(
  //                         width: 160,
  //                         margin: const EdgeInsets.only(right: 12),
  //                         decoration: BoxDecoration(
  //                           color: Colors.white,
  //                           borderRadius: BorderRadius.circular(12),
  //                           boxShadow: [
  //                             BoxShadow(
  //                               color: Colors.black.withOpacity(0.05),
  //                               blurRadius: 4,
  //                               offset: const Offset(0, 2),
  //                             ),
  //                           ],
  //                         ),
  //                         child: const Column(
  //                           crossAxisAlignment: CrossAxisAlignment.start,
  //                           children: [
  //                             SkeletonLoader(
  //                               width: double.infinity,
  //                               height: 100,
  //                               borderRadius: BorderRadius.vertical(
  //                                   top: Radius.circular(12)),
  //                             ),
  //                             Padding(
  //                               padding: EdgeInsets.all(12),
  //                               child: Column(
  //                                 crossAxisAlignment: CrossAxisAlignment.start,
  //                                 children: [
  //                                   SkeletonBox(height: 14, width: 120),
  //                                   SizedBox(height: 8),
  //                                   SkeletonBox(height: 12, width: 80),
  //                                 ],
  //                               ),
  //                             ),
  //                           ],
  //                         ),
  //                       );
  //                     },
  //                   ),
  //                 );
  //               }
  //               final filteredCourses = _getFilteredCourses(provider.courses);
  //
  //               if (filteredCourses.isEmpty) {
  //                 return Center(
  //                   child: Text(
  //                     _selectedCategory == null
  //                         ? 'No courses available'
  //                         : 'No courses in this category',
  //                     style: TextStyle(color: Colors.grey[600]),
  //                   ),
  //                 );
  //               }
  //               return ListView.builder(
  //                 scrollDirection: Axis.horizontal,
  //                 itemCount: filteredCourses.take(5).length,
  //                 itemBuilder: (context, index) {
  //                   final course = filteredCourses[index];
  //                   return _buildPopularCourseCard(course);
  //                 },
  //               );
  //             },
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildPopularMeetingsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Popular Courses',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: () {
                  context.read<AppProvider>().setSelectedIndex(1);
                },
                child: const Text(
                  'See All →',
                  style: TextStyle(
                    color: Color(0xFF5a189a),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Consumer<AppProvider>(
            builder: (context, provider, child) {
              if (provider.isLoadingCourses) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(3, (index) {
                      return Container(
                        width: 220,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 8,
                              spreadRadius: 1,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonLoader(
                              width: double.infinity,
                              height: 120,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(12),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SkeletonBox(height: 14, width: 120),
                                  SizedBox(height: 8),
                                  SkeletonBox(height: 12, width: 80),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                );
              }

              final filteredCourses = _getFilteredCourses(provider.courses);

              if (filteredCourses.isEmpty) {
                return Center(
                  child: Text(
                    _selectedCategory == null
                        ? 'No courses available'
                        : 'No courses in this category',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                );
              }

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: filteredCourses.take(5).map((course) {
                    return _buildPopularCourseCard(course);
                  }).toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Widget _buildPopularCourseCard(Course course) {
  //   return SizedBox(
  //     width: 220,
  //     // height: 400, // ✅ MUST MATCH ListView HEIGHT
  //     child: Container(
  //       margin: const EdgeInsets.only(right: 12),
  //       decoration: BoxDecoration(
  //         color: Colors.white,
  //         borderRadius: BorderRadius.circular(12),
  //         boxShadow: [
  //           BoxShadow(
  //             color: Colors.black.withOpacity(0.05),
  //             blurRadius: 4,
  //             offset: const Offset(0, 2),
  //           ),
  //         ],
  //       ),
  //       child: Column(
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           /// IMAGE
  //           AspectRatio(
  //             aspectRatio: 1.4,
  //             child: ClipRRect(
  //               borderRadius: const BorderRadius.vertical(
  //                 top: Radius.circular(12),
  //               ),
  //               child: course.thumbnail != null
  //                   ? Image.network(course.thumbnail!, fit: BoxFit.cover)
  //                   : Container(
  //                       color: Colors.grey[300],
  //                       child: const Icon(Icons.book, size: 40),
  //                     ),
  //             ),
  //           ),
  //
  //           /// CONTENT (fills remaining space)
  //           Expanded(
  //             child: Padding(
  //               padding: const EdgeInsets.all(12),
  //               child: Column(
  //                 crossAxisAlignment: CrossAxisAlignment.start,
  //                 children: [
  //                   /// TAGS
  //                   Row(
  //                     children: [
  //                       if (course.isLiveCourse) _tag('LIVE', Colors.green),
  //                       const SizedBox(width: 6),
  //                       _tag(
  //                         course.isFree ? 'FREE' : 'PAID',
  //                         course.isFree ? Colors.green : Colors.orange,
  //                       ),
  //                     ],
  //                   ),
  //
  //                   const SizedBox(height: 8),
  //
  //                   /// TITLE
  //                   Text(
  //                     course.title,
  //                     maxLines: 1,
  //                     overflow: TextOverflow.ellipsis,
  //                     style: const TextStyle(
  //                       fontSize: 16,
  //                       fontWeight: FontWeight.bold,
  //                     ),
  //                   ),
  //
  //                   const SizedBox(height: 8),
  //
  //                   /// PRICE
  //                   Text(
  //                     course.isFree
  //                         ? 'FREE'
  //                         : '₹${course.price.toStringAsFixed(0)}',
  //                     style: TextStyle(
  //                       fontSize: 18,
  //                       fontWeight: FontWeight.bold,
  //                       color: course.isFree ? Colors.green : Colors.black87,
  //                     ),
  //                   ),
  //
  //                   /// BUTTON - Only show for students
  //                   if (_shouldShowPayButton()) ...[
  //                     const Spacer(), // ✅ PUSH BUTTON TO BOTTOM (only when button visible)
  //                     SizedBox(
  //                       width: double.infinity,
  //                       child: ElevatedButton(
  //                         onPressed: () {
  //                           Navigator.push(
  //                             context,
  //                             PageTransition(
  //                               type: PageTransitionType.rightToLeft,
  //                               child: CourseDetailScreen(course: course),
  //                             ),
  //                           );
  //                         },
  //                         style: ElevatedButton.styleFrom(
  //                           backgroundColor: const Color(0xFF5a189a),
  //                           padding: const EdgeInsets.symmetric(vertical: 14),
  //                           shape: RoundedRectangleBorder(
  //                             borderRadius: BorderRadius.circular(10),
  //                           ),
  //                         ),
  //                         child: const Text(
  //                           'Get this course',
  //                           style: TextStyle(
  //                             fontSize: 15,
  //                             fontWeight: FontWeight.w600,
  //                             color: Colors.white,
  //                           ),
  //                         ),
  //                       ),
  //                     ),
  //                   ],
  //                 ],
  //               ),
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  Widget _buildPopularCourseCard(Course course) {
    double finalPrice = course.discount != null && course.discount! > 0
        ? course.price * (1 - course.discount! / 100)
        : course.price;
    if (finalPrice < 0) finalPrice = 0;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          PageTransition(
            type: PageTransitionType.rightToLeft,
            child: CourseDetailScreen(course: course),
          ),
        );
      },
      child: SizedBox(
        width: 220,
        child: Container(
          margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),

          /// ⭐ OUTER BORDER
          // border: Border.all(
          //   color: Colors.deepPurple,
          //   width: 1.5,
          // ),

          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            /// IMAGE
            AspectRatio(
              aspectRatio: 16 / 9, // Standard thumbnail aspect ratio
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white, // Match white image background for contain fit
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: AppNetworkImage(
                  imageUrl: course.thumbnail,
                  fit: BoxFit.contain, // Show full image without cropping
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  errorIcon: Icons.book,
                ),
              ),
            ),

            /// CONTENT
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (course.isLiveCourse)
                        _tag('LIVE', Colors.green),
                      _tag(
                        course.isFree ? 'FREE' : 'PAID',
                        course.isFree ? Colors.green : Colors.orange,
                      ),
                      if (course.discount != null && course.discount! > 0)
                        _tag('${(course.discount! > 100 ? 100 : course.discount!).toStringAsFixed(0)}% OFF', Colors.purple),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    course.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      Text(
                        course.isFree ? 'FREE' : '₹${finalPrice.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: course.isFree ? Colors.green : Colors.black87,
                        ),
                      ),
                      if (!course.isFree && course.discount != null && course.discount! > 0)
                        Text(
                          '₹${course.price.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 14,
                            decoration: TextDecoration.lineThrough,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                    ],
                  ),
                  if (_shouldShowPayButton()) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            PageTransition(
                              type: PageTransitionType.rightToLeft,
                              child: CourseDetailScreen(course: course),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5a189a),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Get this course',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
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
}

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildRecentlyAddedMeetingsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: const Text(
                  'Recently Added Courses',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: () {
                  context.read<AppProvider>().setSelectedIndex(1);
                },
                child: const Text(
                  'See All →',
                  style: TextStyle(
                    color: Color(0xFF5a189a),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Consumer<AppProvider>(
            builder: (context, provider, child) {
              if (provider.isLoadingCourses) {
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 3,
                  itemBuilder: (context, index) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
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
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SkeletonBox(height: 16, width: 150),
                                const SizedBox(height: 8),
                                const SkeletonBox(height: 12, width: 200),
                                const SizedBox(height: 4),
                                const SkeletonBox(height: 12, width: 100),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              }
              final filteredCourses = _getFilteredCourses(provider.courses);

              if (filteredCourses.isEmpty) {
                return Center(
                  child: Text(
                    _selectedCategory == null
                        ? 'No courses available'
                        : 'No courses in this category',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredCourses.take(3).length,
                itemBuilder: (context, index) {
                  final course = filteredCourses[index];
                  return _buildRecentCourseCard(course);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecentCourseCard(Course course) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              PageTransition(
                type: PageTransitionType.rightToLeft,
                child: CourseDetailScreen(course: course),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  constraints: const BoxConstraints(
                      minWidth: 70, minHeight: 70, maxWidth: 90, maxHeight: 90),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: course.thumbnail != null
                        ? Image.network(
                            course.thumbnail!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.book,
                                size: 32,
                                color: Colors.grey,
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const SkeletonLoader(
                                width: double.infinity,
                                height: double.infinity,
                                borderRadius:
                                    BorderRadius.all(Radius.circular(8)),
                              );
                            },
                          )
                        : const Icon(
                            Icons.book,
                            size: 32,
                            color: Colors.grey,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (course.isLiveCourse)
                            _tag('LIVE', Colors.green),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: course.isFree
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              course.isFree ? 'FREE' : 'PAID',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: course.isFree
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                            ),
                          ),
                          if (course.discount != null && course.discount! > 0)
                            _tag('${(course.discount! > 100 ? 100 : course.discount!).toStringAsFixed(0)}% OFF', Colors.purple),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        course.title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      () {
                        double finalPrice = course.discount != null && course.discount! > 0
                            ? course.price * (1 - course.discount! / 100)
                            : course.price;
                        if (finalPrice < 0) finalPrice = 0;
                        return Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          children: [
                            Text(
                              course.isFree ? 'Free Course' : '₹${finalPrice.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 17,
                                color: course.isFree ? Colors.green : Colors.grey[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (!course.isFree && course.discount != null && course.discount! > 0)
                              Text(
                                '₹${course.price.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  decoration: TextDecoration.lineThrough,
                                  color: Colors.grey[500],
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                          ],
                        );
                      }(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShareExperienceSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Share Your Experience',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Give your tutor a smile by sharing your experience',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              // Share experience action
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5a189a),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Write now'),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectWithUsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Connect With Us',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSocialIcon(
                Icons.play_arrow_rounded, 
                'Youtube', 
                Colors.red,
                () => _launchUrl('https://youtube.com/@aadvidesignerstudio?si=mAuvVg7G98gLVkOM'),
              ),
              _buildSocialIcon(
                Icons.camera_alt_rounded, 
                'Instagram', 
                const Color(0xFFE40C5F), // Instagram Pink
                () => _launchUrl('https://www.instagram.com/aadvi_designer_studio?stkn=cmVlZ21sOGlpZDZt'),
                isInstagram: true,
              ),
              _buildSocialIcon(
                Icons.location_on_rounded, 
                'Location', 
                Colors.blue[700]!,
                () => _launchUrl('https://maps.app.goo.gl/smQec1r6pJJPYgU76?g_st=aw'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _launchUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Could not launch $url : $e');
    }
  }

  Widget _buildSocialIcon(IconData icon, String label, Color color, VoidCallback onTap, {bool isInstagram = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 65,
            height: 65,
            decoration: BoxDecoration(
              gradient: isInstagram 
                ? const LinearGradient(
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                    colors: [
                      Color(0xFFFFB144), // Orange
                      Color(0xFFE40C5F), // Pink
                      Color(0xFF833AB4), // Purple
                    ],
                  )
                : null,
              color: isInstagram ? null : color,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: (isInstagram ? const Color(0xFFE40C5F) : color).withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }
}
