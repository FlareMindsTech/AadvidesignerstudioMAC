import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:page_transition/page_transition.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../models/course.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../config/api_config.dart';
import '../theme/app_theme.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/profile_avatar.dart';
import 'course_detail_screen.dart';
import 'login_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  User? _user;
  String? _photoUrl;
  Map<String, dynamic>? _profileData;
  List<Map<String, dynamic>> _subscribedCourses = [];
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    // Use a small delay or access directly to get the initial role
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfile();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;
    
    final user = await StorageService.getUser();
    final token = await StorageService.getToken();

    if (user == null || token == null) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _user = user;
      _photoUrl = user.photo;
      
      // Update TabController length if role is Admin/Owner
      final isAdmin = user.role.toLowerCase() == 'admin' || user.role.toLowerCase() == 'owner';
      final newLength = isAdmin ? 1 : 2;
      if (_tabController.length != newLength) {
        final oldController = _tabController;
        _tabController = TabController(length: newLength, vsync: this);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          oldController.dispose();
        });
      }
    });

    try {
      final response = await http.get(
        Uri.parse(ApiConfig.userProfileEndpoint),
        headers: ApiConfig.getAuthHeaders(token),
      ).timeout(ApiConfig.timeout);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _profileData = data;
            _photoUrl = data['photo'] as String?;
            
            // DEBUG: Print the photo URL so we can see it in logcat
            print('[PROFILE DEBUG] Raw photo from API: ${data['photo']}');
            print('[PROFILE DEBUG] Sanitized photo URL: ${ApiConfig.getImageUrl(_photoUrl)}');
            
            // Sync the full updated user object to local storage
            final freshUser = User.fromJson(data);
            _user = freshUser;
            StorageService.saveUser(freshUser);

            final rawCourses = data['subscribedCourses'];
            if (rawCourses is List) {
              _subscribedCourses = rawCourses.cast<Map<String, dynamic>>();
            } else {
              _subscribedCourses = [];
            }
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load profile details. Please check your connection.';
        });
      }
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await AuthService.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ONLY show full screen loading if we don't even have BASIC user info from local storage
    if (_isLoading && _user == null) return _buildLoading();
    if (_user == null) return _buildError();

    final bool isAdmin = _user!.role.toLowerCase() == 'admin' || _user!.role.toLowerCase() == 'owner';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 250,
              pinned: true,
              backgroundColor: AppTheme.primaryColor,
              flexibleSpace: FlexibleSpaceBar(
                background: _buildHeader(_user!),
              ),
              bottom: !isAdmin ? TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white.withValues(alpha: 0.7),
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
                tabs: [
                  const Tab(text: 'Personal Info', icon: Icon(Icons.person_outline, size: 20)),
                  if (_tabController.length > 1)
                    const Tab(text: 'Subscriptions', icon: Icon(Icons.school_outlined, size: 20)),
                ],
              ) : null,
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: () {
                    setState(() => _isLoading = true);
                    _loadProfile();
                  },
                ),
                IconButton(icon: const Icon(Icons.edit, color: Colors.white), onPressed: _navigateToEditProfile),
                IconButton(icon: const Icon(Icons.logout, color: Colors.white), onPressed: _handleLogout),
              ],
            ),
          ];
        },
        body: isAdmin 
          ? SingleChildScrollView(child: _buildPersonalInfoTab(_user!))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPersonalInfoTab(_user!),
                if (_tabController.length > 1)
                  _buildSubscriptionsTab(),
              ],
            ),
      ),
    );
  }

  Widget _buildHeader(User user) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primaryColor, const Color(0xFF7B2CBF)],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: ProfileAvatar(
              photoUrl: _photoUrl,
              displayName: user.displayName,
              size: 90,
            ),
          ),
          const SizedBox(height: 12),
          Text(user.fullName, style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold)),
          if (user.role.toLowerCase() == 'admin' || user.role.toLowerCase() == 'owner')
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
              child: Text(
                user.role.toLowerCase() == 'owner' ? 'Owner Profile' : 'Admin Profile',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          const SizedBox(height: 48), // Space for tabs
        ],
      ),
    );
  }

  Widget _buildPersonalInfoTab(User user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildModernRow(Icons.email, 'Email', user.email ?? ''),
              const Divider(height: 32),
              _buildModernRow(Icons.phone, 'Phone', user.phoneNumber ?? 'Not provided'),
              const Divider(height: 32),
              _buildModernRow(Icons.badge, 'Role', user.role.toUpperCase()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryColor, size: 22),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubscriptionsTab() {
    if (_subscribedCourses.isEmpty) return const Center(child: Text('No subscriptions found'));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _subscribedCourses.length,
      itemBuilder: (context, index) {
        final courseData = _subscribedCourses[index];
        final courseIdData = courseData['courseId'];
        Course? course;
        if (courseIdData is Map<String, dynamic>) { try { course = Course.fromJson(courseIdData); } catch (_) {} }
        final String cId = course?.id ?? "";
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: ClipRRect(
                borderRadius: BorderRadius.circular(8), 
                child: course?.thumbnail != null 
                    ? Image.network(
                        ApiConfig.getImageUrl(course!.thumbnail), 
                        width: 45, 
                        height: 45, 
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[200], child: const Icon(Icons.broken_image, size: 20)),
                      ) 
                    : const Icon(Icons.school)
            ),
            title: Text(course?.title ?? 'Course', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: (courseData['expiresAt'] != null && DateTime.parse(courseData['expiresAt'].toString()).isAfter(DateTime.now()))
                          ? Colors.green.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        (courseData['expiresAt'] != null && DateTime.parse(courseData['expiresAt'].toString()).isAfter(DateTime.now()))
                          ? 'ACTIVE'
                          : 'EXPIRED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: (courseData['expiresAt'] != null && DateTime.parse(courseData['expiresAt'].toString()).isAfter(DateTime.now()))
                            ? Colors.green
                            : Colors.red,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (courseData['expiresAt'] != null)
                      Text(
                        DateTime.parse(courseData['expiresAt'].toString()).year > 4000
                            ? 'Lifetime Access'
                            : 'Ends: ${DateTime.parse(courseData['expiresAt'].toString()).day}/${DateTime.parse(courseData['expiresAt'].toString()).month}/${DateTime.parse(courseData['expiresAt'].toString()).year}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                  ],
                ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: course != null ? () => Navigator.push(context, PageTransition(type: PageTransitionType.rightToLeft, child: CourseDetailScreen(course: course!))) : null,
          ),
        );
      },
    );
  }

  Widget _buildLoading() => Scaffold(
    appBar: AppBar(backgroundColor: AppTheme.primaryColor, title: const Text('Profile'), foregroundColor: Colors.white),
    body: const Center(child: CircularProgressIndicator()),
  );

  Widget _buildError() => Scaffold(
    appBar: AppBar(backgroundColor: AppTheme.primaryColor, title: const Text('Profile'), foregroundColor: Colors.white),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, 
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red), 
            const SizedBox(height: 16), 
            Text(
              _errorMessage, 
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ), 
            const SizedBox(height: 24),
            SizedBox(
              width: 200,
              child: ElevatedButton(
                onPressed: _loadProfile, 
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Retry'),
              ),
            )
          ],
        ),
      ),
    ),
  );
  
  Future<void> _navigateToEditProfile() async {
    if (_user != null) {
      final result = await Navigator.push(context, PageTransition(type: PageTransitionType.rightToLeft, child: EditProfileScreen(user: _user!, photoUrl: _photoUrl)));
      if (result == true) _loadProfile();
    }
  }
}
