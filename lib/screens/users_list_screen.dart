import 'package:flutter/material.dart';

import 'package:meeting_app/screens/student_notifications_screen.dart';
import 'package:page_transition/page_transition.dart';
import 'package:intl/intl.dart';
import '../services/user_service.dart';
import '../services/payment_service.dart';
import '../services/storage_service.dart';
import '../models/user.dart';
import '../config/api_config.dart';
import '../widgets/app_drawer.dart';
import '../widgets/skeleton_loader.dart';
import 'create_admin_screen.dart';
import 'create_student_screen.dart';
import 'student_detail_screen.dart';
import 'edit_admin_screen.dart';
import 'edit_student_screen.dart';

class UsersListScreen extends StatefulWidget {
  const UsersListScreen({super.key});

  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen>
    with TickerProviderStateMixin {
  List<User> _users = [];
  bool _isLoading = false;
  String _errorMessage = '';
  String _currentUserRole = '';
  TabController? _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeTabController() {
    // Dispose existing controller if any
    _tabController?.removeListener(_onTabChanged);
    _tabController?.dispose();

    // Create controller based on user role
    final tabCount = _currentUserRole == 'owner' ? 2 : 1;
    _tabController = TabController(length: tabCount, vsync: this);
    _tabController!.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController == null) return;
    if (!_tabController!.indexIsChanging) {
      // Tab change completed
      setState(() {});

      // Load data based on selected tab
      if (_currentUserRole == 'owner') {
        // Owner has both tabs
        if (_tabController!.index == 0) {
          debugPrint('Admins tab selected, loading admins...');
          _loadAdminsOnly();
        } else if (_tabController!.index == 1) {
          debugPrint('Students tab selected, loading students...');
          _loadStudentsOnly();
        }
      } else {
        // Admin only has students tab (index 0)
        if (_tabController!.index == 0) {
          debugPrint('Students tab selected, loading students...');
          _loadStudentsOnly();
        }
      }
    }
  }

  Future<void> _initializeData() async {
    await _loadCurrentUserRole();
    if (mounted) {
      _loadUsers();
    }
  }

  Future<void> _loadCurrentUserRole() async {
    final role = await StorageService.getRole();
    if (mounted) {
      setState(() {
        _currentUserRole = role?.toLowerCase() ?? '';
        // Initialize tab controller after role is loaded
        _initializeTabController();
      });
    }
  }

  @override
  void dispose() {
    _tabController?.removeListener(_onTabChanged);
    _tabController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Load data based on user role
      if (_currentUserRole == 'owner') {
        // Owner can see both admins and students - load independently
        debugPrint('Loading admins and students for owner...');
        List<User> admins = [];
        List<User> students = [];

        // Try to load admins (don't fail if this fails)
        try {
          admins = await UserService.getAllAdmins();
          debugPrint('Loaded ${admins.length} admins');
        } catch (e) {
          debugPrint('Failed to load admins: $e');
          // Continue to load students even if admins fail
        }

        // Always try to load students
        try {
          students = await UserService.getAllStudents();
          debugPrint('Loaded ${students.length} students');
        } catch (e) {
          debugPrint('Failed to load students: $e');
          // If students also fail, throw the error
          if (admins.isEmpty) {
            rethrow;
          }
        }

        if (!mounted) return;

        setState(() {
          _users = [...admins, ...students];
          _isLoading = false;
          // Only show error if both failed
          if (admins.isEmpty && students.isEmpty) {
            _errorMessage = 'Failed to load users. Please try again.';
          }
        });
      } else if (_currentUserRole == 'admin') {
        // Admin can only see students
        debugPrint('Loading students for admin...');
        final students = await UserService.getAllStudents();
        debugPrint('Loaded ${students.length} students');

        if (!mounted) return;

        setState(() {
          _users = students;
          _isLoading = false;
        });
      } else {
        // Fallback: try to get students
        debugPrint('Loading students (fallback)...');
        final students = await UserService.getAllStudents();
        debugPrint('Loaded ${students.length} students');

        if (!mounted) return;

        setState(() {
          _users = students;
          _isLoading = false;
        });
      }
    } on UserServiceException catch (e) {
      debugPrint('UserServiceException: ${e.message}');
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      debugPrint('Error loading users: $e');
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'An unexpected error occurred. Please try again.';
      });
    }
  }

  // Load only admins (for Admins tab)
  Future<void> _loadAdminsOnly() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      debugPrint('Loading admins only...');
      final admins = await UserService.getAllAdmins();
      debugPrint('Loaded ${admins.length} admins');

      if (!mounted) return;

      // Update only admins in the list, keep students if they exist
      setState(() {
        final existingStudents = _users
            .where((u) =>
                u.role.toLowerCase() == 'student' ||
                u.role.toLowerCase() == 'user')
            .toList();
        _users = [...admins, ...existingStudents];
        _isLoading = false;
      });
    } on UserServiceException catch (e) {
      debugPrint('UserServiceException loading admins: ${e.message}');
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      debugPrint('Error loading admins: $e');
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load admins. Please try again.';
      });
    }
  }

  // Load only students (for Students tab)
  Future<void> _loadStudentsOnly() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      debugPrint('Loading students only...');
      final students = await UserService.getAllStudents();
      debugPrint('Loaded ${students.length} students');

      if (!mounted) return;

      // Update only students in the list, keep admins if they exist
      setState(() {
        final existingAdmins = _users
            .where((u) =>
                u.role.toLowerCase() == 'admin' ||
                u.role.toLowerCase() == 'owner')
            .toList();
        _users = [...existingAdmins, ...students];
        _isLoading = false;
      });
    } on UserServiceException catch (e) {
      debugPrint('UserServiceException loading students: ${e.message}');
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      debugPrint('Error loading students: $e');
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load students. Please try again.';
      });
    }
  }

  Future<void> _navigateToCreateAdmin() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateAdminScreen(),
      ),
    );

    if (result == true) {
      _loadUsers();
    }
  }

  Future<void> _navigateToCreateStudent() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateStudentScreen(),
      ),
    );

    if (result == true) {
      _loadUsers();
    }
  }

  Future<void> _navigateToEditAdmin(User admin) async {
    final result = await Navigator.push(
      context,
      PageTransition(
        type: PageTransitionType.rightToLeft,
        child: EditAdminScreen(admin: admin),
      ),
    );

    if (result == true) {
      _loadUsers();
    }
  }

  Future<void> _deleteAdmin(User admin) async {
    if (admin.id == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Admin'),
        content: Text(
            'Are you sure you want to delete "${admin.fullName}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await UserService.deleteAdmin(admin.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Admin deleted successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        );
        _loadUsers();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete admin: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        );
      }
    }
  }

  Future<void> _navigateToEditStudent(User student) async {
    final result = await Navigator.push(
      context,
      PageTransition(
        type: PageTransitionType.rightToLeft,
        child: EditStudentScreen(student: student),
      ),
    );

    if (result == true) {
      _loadUsers();
    }
  }

  Future<void> _deactivateStudent(User student) async {
    if (student.id == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate Student'),
        content:
            Text('Are you sure you want to deactivate "${student.fullName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await UserService.deactivateStudent(student.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Student deactivated successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        );
        _loadUsers();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to deactivate student: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        );
      }
    }
  }

  Future<void> _deleteStudent(User student) async {
    if (student.id == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Student'),
        content: Text(
            'Are you sure you want to delete "${student.fullName}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await UserService.deleteStudent(student.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Student deleted successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        );
        _loadUsers();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete student: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        );
      }
    }
  }

  List<User> get _adminUsers {
    if (_currentUserRole == 'admin') {
      return _users
          .where((user) =>
              user.role.toLowerCase() == 'user' ||
              user.role.toLowerCase() == 'student')
          .toList();
    } else {
      return _users
          .where((user) =>
              user.role.toLowerCase() == 'admin' ||
              user.role.toLowerCase() == 'owner')
          .toList();
    }
  }

  List<User> get _studentUsers {
    return _users
        .where((user) =>
            user.role.toLowerCase() == 'user' ||
            user.role.toLowerCase() == 'student')
        .toList();
  }

  List<User> _filterUsers(List<User> users, String query) {
    if (query.isEmpty) return users;
    return users
        .where((user) =>
            user.fullName.toLowerCase().contains(query.toLowerCase()) ||
            (user.email ?? '').toLowerCase().contains(query.toLowerCase()) ||
            (user.phoneNumber?.toLowerCase().contains(query.toLowerCase()) ??
                false))
        .toList();
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return const Color(0xFF5a189a);
      case 'admin':
        return const Color(0xFF5a189a);
      case 'user':
      case 'student':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return Icons.workspace_premium_rounded;
      case 'admin':
        return Icons.admin_panel_settings_rounded;
      case 'user':
      case 'student':
        return Icons.person_rounded;
      default:
        return Icons.person_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              constraints: const BoxConstraints(minHeight: 56, maxHeight: 64),
              color: const Color(0xFF5a189a),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(Icons.menu, color: Colors.white),
                      onPressed: () {
                        Scaffold.of(context).openDrawer();
                      },
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Aadvi Fashion Institute',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.notifications, color: Colors.white),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const StudentNotificationsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Search Bar
            Container(
              margin: const EdgeInsets.all(16),
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
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search users by name, email or phone',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),

            // Tab Bar (only show if owner, or show single tab for admin)
            if (_tabController != null) ...[
              Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  labelColor: const Color(0xFF5a189a),
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: const Color(0xFF5a189a),
                  indicatorWeight: 3,
                  tabs: _currentUserRole == 'owner'
                      ? const [
                          Tab(
                            icon: Icon(Icons.admin_panel_settings_rounded),
                            text: 'Admins',
                          ),
                          Tab(
                            icon: Icon(Icons.school_rounded),
                            text: 'Students',
                          ),
                        ]
                      : const [
                          Tab(
                            icon: Icon(Icons.school_rounded),
                            text: 'Students',
                          ),
                        ],
                ),
              ),

              // Tab Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: _currentUserRole == 'owner'
                      ? [
                          _buildTabContent(_adminUsers, 'Admin', 0),
                          _buildTabContent(_studentUsers, 'Student', 1),
                        ]
                      : [
                          _buildTabContent(_studentUsers, 'Student', 0),
                        ],
                ),
              ),
            ] else
              // Loading state while tab controller is being initialized
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: _tabController != null
          ? FloatingActionButton.extended(
              heroTag: null,
              onPressed:
                  _currentUserRole == 'owner' && _tabController!.index == 0
                      ? _navigateToCreateAdmin
                      : _navigateToCreateStudent,
              backgroundColor: const Color(0xFF5a189a),
              foregroundColor: Colors.white,
              icon: Icon(
                  _currentUserRole == 'owner' && _tabController!.index == 0
                      ? Icons.person_add_rounded
                      : Icons.school_rounded),
              label: Text(
                _currentUserRole == 'owner' && _tabController!.index == 0
                    ? 'Create Admin'
                    : 'Create Student',
                style: const TextStyle(color: Colors.white),
              ),
            )
          : null,
    );
  }

  Widget _buildTabContent(List<User> users, String userType, int tabIndex) {
    final filteredUsers = _filterUsers(users, _searchController.text);

    if (_isLoading && _users.isEmpty) {
      return _buildLoadingState();
    }

    if (_errorMessage.isNotEmpty) {
      return _buildErrorState();
    }

    if (filteredUsers.isEmpty) {
      return _buildEmptyState(userType);
    }

    return _buildUsersList(filteredUsers, userType);
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16,80),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
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
            children: [
              const SkeletonLoader(
                  width: 60,
                  height: 60,
                  borderRadius: BorderRadius.all(Radius.circular(12))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SkeletonBox(height: 16, width: 150),
                    const SizedBox(height: 8),
                    const SkeletonBox(height: 12, width: 200),
                    const SizedBox(height: 4),
                    const SkeletonBox(height: 12, width: 120),
                  ],
                ),
              ),
              const SkeletonLoader(
                  width: 80,
                  height: 30,
                  borderRadius: BorderRadius.all(Radius.circular(20))),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            const Text(
              'Error Loading Users',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadUsers,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5a189a),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String userType) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              userType.toLowerCase() == 'admin'
                  ? Icons.admin_panel_settings_rounded
                  : Icons.school_rounded,
              size: 80,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 24),
            Text(
              'No ${userType}s Found',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              userType.toLowerCase() == 'admin'
                  ? 'Create your first admin user to get started'
                  : 'No students have been added yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: userType.toLowerCase() == 'admin'
                  ? _navigateToCreateAdmin
                  : _navigateToCreateStudent,
              icon: Icon(userType.toLowerCase() == 'admin'
                  ? Icons.person_add_rounded
                  : Icons.school_rounded),
              label: Text('Create $userType'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5a189a),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersList(List<User> users, String userType) {
    return RefreshIndicator(
      onRefresh: _loadUsers,
      color: const Color(0xFF5a189a),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 70),
        itemCount: users.length,
        itemBuilder: (context, index) {
          return _buildUserCard(users[index]);
        },
      ),
    );
  }

  Widget _buildUserCard(User user) {
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
          onTap: () => _showUserDetails(user),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey[350],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: user.photo != null && user.photo!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            ApiConfig.getImageUrl(user.photo),
                            fit: BoxFit.cover,
                            width: 60,
                            height: 60,
                            errorBuilder: (context, error, stackTrace) => const Center(
                              child: Icon(
                                Icons.person,
                                size: 35,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        )
                      : const Center(
                          child: Icon(
                            Icons.person,
                            size: 40,
                            color: Colors.white,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                // User Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.email_outlined,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              user.email ?? '',
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
                      if (user.phoneNumber != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.phone_outlined,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              user.phoneNumber!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // Role Badge and Actions
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getRoleColor(user.role).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _getRoleColor(user.role).withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getRoleIcon(user.role),
                            size: 14,
                            color: _getRoleColor(user.role),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            user.role.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _getRoleColor(user.role),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Show edit button for admins (only for owner)
                    if ((user.role.toLowerCase() == 'admin' ||
                            user.role.toLowerCase() == 'owner') &&
                        _currentUserRole == 'owner') ...[
                      const SizedBox(height: 8),
                      PopupMenuButton<String>(
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.more_vert,
                            size: 16,
                            color: Colors.blue[700],
                          ),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onSelected: (value) {
                          switch (value) {
                            case 'edit':
                              _navigateToEditAdmin(user);
                              break;
                            case 'delete':
                              _deleteAdmin(user);
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.edit,
                                      color: Colors.blue, size: 18),
                                ),
                                const SizedBox(width: 12),
                                const Text('Edit Admin'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.delete,
                                      color: Colors.red, size: 18),
                                ),
                                const SizedBox(width: 12),
                                const Text('Delete'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                    // Show actions for students (only for admin/owner)
                    if ((user.role.toLowerCase() == 'student' ||
                            user.role.toLowerCase() == 'user') &&
                        (_currentUserRole == 'admin' ||
                            _currentUserRole == 'owner')) ...[
                      const SizedBox(height: 8),
                      PopupMenuButton<String>(
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.more_vert,
                            size: 16,
                            color: Colors.blue[700],
                          ),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onSelected: (value) {
                          switch (value) {
                            case 'edit':
                              _navigateToEditStudent(user);
                              break;
                            case 'update_password':
                              _showUpdatePasswordDialog(user);
                              break;
                            case 'payment_history':
                              _showStudentPaymentHistory(user);
                              break;
                            case 'deactivate':
                              _deactivateStudent(user);
                              break;
                            case 'delete':
                              _deleteStudent(user);
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.edit,
                                      color: Colors.blue, size: 18),
                                ),
                                const SizedBox(width: 12),
                                const Text('Edit Student'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'update_password',
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.lock_reset_rounded,
                                      color: Colors.orange, size: 18),
                                ),
                                const SizedBox(width: 12),
                                const Text('Update Password'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'payment_history',
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.payment,
                                      color: Colors.green, size: 18),
                                ),
                                const SizedBox(width: 12),
                                const Text('Payment History'),
                              ],
                            ),
                          ),
                          if (user.isActive != false)
                            PopupMenuItem(
                              value: 'deactivate',
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(Icons.block,
                                        color: Colors.orange, size: 18),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text('Deactivate'),
                                ],
                              ),
                            ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.delete,
                                      color: Colors.red, size: 18),
                                ),
                                const SizedBox(width: 12),
                                const Text('Delete'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showUserDetails(User user) {
    // For students, navigate to the full student detail screen
    if ((user.role.toLowerCase() == 'student' ||
            user.role.toLowerCase() == 'user') &&
        user.id != null) {
      Navigator.push(
        context,
        PageTransition(
          type: PageTransitionType.rightToLeft,
          child: StudentDetailScreen(studentId: user.id!),
        ),
      );
    } else {
      // For admins or other roles, show a simple dialog
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[350],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: user.photo != null && user.photo!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          ApiConfig.getImageUrl(user.photo),
                          fit: BoxFit.cover,
                          width: 80,
                          height: 80,
                          errorBuilder: (context, error, stackTrace) => const Center(
                            child: Icon(
                              Icons.person,
                              size: 48,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      )
                    : const Center(
                        child: Icon(
                          Icons.person,
                          size: 56,
                          color: Colors.white,
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              Text(
                user.fullName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _getRoleColor(user.role).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getRoleIcon(user.role),
                      size: 16,
                      color: _getRoleColor(user.role),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      user.role.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _getRoleColor(user.role),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildDetailRow(Icons.email_outlined, 'Email', user.email ?? ''),
              if (user.phoneNumber != null) ...[
                const SizedBox(height: 12),
                _buildDetailRow(
                    Icons.phone_outlined, 'Phone', user.phoneNumber!),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showUpdatePasswordDialog(User user) {
    final TextEditingController passwordController = TextEditingController();
    final TextEditingController confirmPasswordController =
        TextEditingController();
    bool isPasswordVisible = false;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.lock_reset_rounded,
                      color: Colors.blue,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Update Password',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Update password for ${user.fullName}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: passwordController,
                      obscureText: !isPasswordVisible,
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        hintText: 'Enter new password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            isPasswordVisible
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() {
                              isPasswordVisible = !isPasswordVisible;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: !isPasswordVisible,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        hintText: 'Re-enter password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final password = passwordController.text.trim();
                    final confirmPassword =
                        confirmPasswordController.text.trim();

                    if (password.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a password'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    if (password != confirmPassword) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Passwords do not match'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    if (password.length < 6) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('Password must be at least 6 characters'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    Navigator.of(dialogContext).pop();
                    await _updatePassword(user, password);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5a189a),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _updatePassword(User user, String newPassword) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text('Updating password...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );

      final success = await UserService.updateStudentPassword(
        studentId: user.id!,
        newPassword: newPassword,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Password updated successfully'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Text('Error: ${e.toString()}'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Future<void> _showStudentPaymentHistory(User student) async {
    bool isLoading = true;
    List<Map<String, dynamic>> paymentHistory = [];
    String? errorMessage;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Load payment history
          if (isLoading && paymentHistory.isEmpty && errorMessage == null) {
            PaymentService.getStudentPaymentHistory(student.id!)
                .then((payments) {
              if (context.mounted) {
                setDialogState(() {
                  paymentHistory = payments;
                  isLoading = false;
                });
              }
            }).catchError((e) {
              if (context.mounted) {
                setDialogState(() {
                  errorMessage =
                      e.toString().replaceAll('PaymentServiceException: ', '');
                  isLoading = false;
                });
              }
            });
          }

          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag Handle
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF5a189a), Color(0xFF9C27B0)],
                    ),
                    borderRadius: const BorderRadius.only(
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
                          Icons.payment_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Payment History',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              student.fullName,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: isLoading
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF5a189a)),
                            ),
                          ),
                        )
                      : errorMessage != null
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      size: 64,
                                      color: Colors.red[300],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      errorMessage!,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : paymentHistory.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.payment_outlined,
                                        size: 64,
                                        color: Colors.grey[300],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No payment history found',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: paymentHistory.length,
                                  itemBuilder: (context, index) {
                                    final payment = paymentHistory[index];
                                    final amount = payment['amount'] ?? 0;
                                    final amountInRupees = amount is int
                                        ? amount.toDouble()
                                        : (amount as num).toDouble();
                                    final status =
                                        payment['status']?.toString() ??
                                            'Unknown';
                                    final courseTitle =
                                        payment['courseTitle']?.toString() ??
                                            'Unknown Course';
                                    final dateStr =
                                        payment['date']?.toString() ?? '';
                                    final orderId =
                                        payment['orderId']?.toString() ?? 'N/A';
                                    final paymentId =
                                        payment['paymentId']?.toString() ??
                                            'N/A';

                                    DateTime? paymentDate;
                                    if (dateStr.isNotEmpty) {
                                      try {
                                        paymentDate = DateTime.parse(dateStr);
                                      } catch (e) {
                                        debugPrint('Error parsing date: $e');
                                      }
                                    }

                                    final isSuccess =
                                        status.toLowerCase() == 'success';

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: isSuccess
                                              ? Colors.green.withValues(alpha: 0.3)
                                              : Colors.grey.withValues(alpha: 0.3),
                                          width: 1,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withValues(alpha: 0.05),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Course Title and Status
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    courseTitle,
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.black87,
                                                    ),
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: isSuccess
                                                        ? Colors.green
                                                            .withValues(alpha: 0.1)
                                                        : Colors.orange
                                                            .withValues(alpha: 0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    border: Border.all(
                                                      color: isSuccess
                                                          ? Colors.green
                                                          : Colors.orange,
                                                      width: 1,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        isSuccess
                                                            ? Icons.check_circle
                                                            : Icons.pending,
                                                        size: 12,
                                                        color: isSuccess
                                                            ? Colors.green
                                                            : Colors.orange,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        status,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: isSuccess
                                                              ? Colors.green
                                                              : Colors.orange,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            // Amount
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.currency_rupee,
                                                  size: 20,
                                                  color: Colors.green[700],
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  NumberFormat('#,##,###')
                                                      .format(amountInRupees),
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.green[700],
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  payment['currency']
                                                          ?.toString() ??
                                                      'INR',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            // Date
                                            if (paymentDate != null)
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.calendar_today,
                                                    size: 16,
                                                    color: Colors.grey[600],
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    DateFormat(
                                                            'MMM dd, yyyy • hh:mm a')
                                                        .format(paymentDate),
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            const SizedBox(height: 8),
                                            // Order ID and Payment ID
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        'Order ID',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color:
                                                              Colors.grey[500],
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        orderId,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color:
                                                              Colors.grey[700],
                                                          fontFamily:
                                                              'monospace',
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        'Payment ID',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color:
                                                              Colors.grey[500],
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        paymentId,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color:
                                                              Colors.grey[700],
                                                          fontFamily:
                                                              'monospace',
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                ),

                // Footer
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                    border: Border(
                      top: BorderSide(color: Colors.grey[200]!),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Payments: ${paymentHistory.length}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
